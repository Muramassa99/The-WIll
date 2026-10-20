"""Offline writer attribution for diagnose_skill_crafter_arm_solver_trace.gd."""
import argparse
import collections
import hashlib
import json
import math
import re
from pathlib import Path


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def norm(value):
    length = math.sqrt(dot(value, value))
    return [x / length for x in value] if length > 1e-12 else None


def angle(a, b, quaternion=False):
    if a is None or b is None:
        return None
    a, b = norm(a), norm(b)
    if a is None or b is None:
        return None
    cosine = dot(a, b)
    return math.degrees(math.acos(max(-1, min(1, abs(cosine) if quaternion else cosine)))) * (2 if quaternion else 1)


def rotate(q, v):
    q = norm(q)
    u, s = q[:3], q[3]
    return [2 * dot(u, v) * u[i] + (s * s - dot(u, u)) * v[i] + 2 * s * cross(u, v)[i] for i in range(3)]


def pose(row):
    bones = row['bones']
    upper, fore, hand = [bones[x] for x in ('Upperarm', 'Forearm', 'Hand')]
    a = sub(fore['world_p'], upper['world_p'])
    b = sub(hand['world_p'], fore['world_p'])
    normal = norm(cross(a, b))
    axis = norm(sub(hand['world_p'], upper['world_p']))
    radial = norm([a[i] - axis[i] * dot(a, axis) for i in range(3)]) if axis else None
    inverse = [-upper['world_q'][0], -upper['world_q'][1], -upper['world_q'][2], upper['world_q'][3]]
    elbow = angle([-x for x in a], b)
    return {'elbow_unsigned_deg': elbow, 'bend_normal_world': normal,
            'bend_normal_upperarm_local': rotate(inverse, normal) if normal else None,
            'radial_world': radial, 'cross_length_m2': math.sqrt(dot(cross(a, b), cross(a, b))),
            'hand_world': hand['world_p'],
            'hand_target_gap_m': math.dist(hand['world_p'], row['hand_target_world']) if row.get('hand_target_world') else None}


def sample_pose(row, side):
    prefix = f'CC_Base_{side}_'
    return pose({'bones': {bone.removeprefix(prefix): {'world_p': state['world_position'], 'world_q': state['world_quaternion']}
        for bone, state in row['bones'].items() if bone.startswith(prefix)}})


def compare(before, after, kind):
    a, b = pose(before), pose(after)
    details = after['details']
    changes = {name: {'local_deg': angle(before['bones'][name]['local_q'], bone['local_q'], True),
                      'world_deg': angle(before['bones'][name]['world_q'], bone['world_q'], True)}
               for name, bone in after['bones'].items() if name in before['bones']}
    return {'kind': kind, 'serial_before': before['serial'], 'serial_after': after['serial'],
            'step': after['next_sample_step'], 'phase': after['next_sample_phase'],
            'scope': details.get('scope'), 'scope_stack': details.get('scope_stack', []),
            'iteration': details.get('iteration'), 'joint': details.get('joint_bone'),
            'process_frame_before': before['process_frame'], 'process_frame_after': after['process_frame'],
            'plane_step_deg': angle(a['bend_normal_world'], b['bend_normal_world']),
            'upperarm_local_plane_step_deg': angle(a['bend_normal_upperarm_local'], b['bend_normal_upperarm_local']),
            'radial_step_deg': angle(a['radial_world'], b['radial_world']),
            'hand_translation_m': math.dist(a['hand_world'], b['hand_world']),
            'before': a, 'after': b, 'bone_rotation_steps': changes,
            'writer_details': {key: value for key, value in details.items() if key not in ('scope_stack', 'scope', 'iteration')},
            'twist_state_before': before.get('twist_state'), 'twist_state_after': after.get('twist_state')}


def scope_key(row):
    details = row['details']
    stack = tuple((s.get('scope'), s.get('slot_id'), s.get('parent_iteration')) for s in details.get('scope_stack', []))
    return row['next_sample_step'], stack, details.get('scope')


def analyze_trace(path, declared):
    digest = hashlib.sha256()
    pending = collections.defaultdict(list)
    transitions = {}
    warnings = []
    rows = 0
    twist_requests = []
    twist_crossings = []
    previous_twist = None
    capture_before_transition = None
    with path.open('rb') as stream:
        for line_number, raw in enumerate(stream, 1):
            digest.update(raw)
            if not raw.strip():
                continue
            try:
                row = json.loads(raw)
            except (json.JSONDecodeError, UnicodeDecodeError):
                warnings.append(f'Unreadable/incomplete JSONL line {line_number}; source may still be running.')
                continue
            rows += 1
            step = row['next_sample_step']
            transition = transitions.setdefault(step, {'step': step, 'phase': row['next_sample_phase'], 'rows': 0, 'write_pairs': 0, 'phase_pairs': 0,
                'first_large_plane_write': None, 'largest_plane_write': None, 'large_plane_writes': [],
                'large_helper_writes': [], 'twist_events': [], 'pure_swing_phases': [], 'pipeline_phases': [], 'largest_phase_plane_change': None,
                'pre_solver_frame_change': None})
            transition['rows'] += 1
            event, details = row['event'], row['details']
            if event in ('twist_distribution_result', 'wrist_twist_clamp'):
                transition['twist_events'].append({'serial': row['serial'], 'event': event, 'details': details})
            if event == 'twist_distribution_result' and details.get('requested_degrees') is not None:
                twist_requests.append(details['requested_degrees'])
                if previous_twist is not None and abs(details['requested_degrees'] - previous_twist['details']['requested_degrees']) > 180:
                    prev_details = previous_twist['details']
                    twist_crossings.append({'serial_before': previous_twist['serial'], 'serial_after': row['serial'],
                        'step_before': previous_twist['next_sample_step'], 'step_after': step,
                        'raw_before_deg': prev_details['requested_degrees'], 'raw_after_deg': details['requested_degrees'],
                        'resolved_before_deg': prev_details.get('resolved_degrees'), 'resolved_after_deg': details.get('resolved_degrees'),
                        'branch_status': details.get('branch_status'),
                        'forearm_total_before_deg': prev_details.get('forearm_applied_degrees'), 'forearm_total_after_deg': details.get('forearm_applied_degrees'),
                        'upperarm_total_before_deg': prev_details.get('upperarm_applied_degrees'), 'upperarm_total_after_deg': details.get('upperarm_applied_degrees'),
                        'maximum_helper_quaternion_step_deg': max((angle(previous_twist['bones'][bone]['local_q'], state['local_q'], True) or 0
                            for bone, state in row['bones'].items() if 'Twist' in bone), default=0)})
                previous_twist = row
            if event == 'capture_baseline':
                transition['baseline'] = pose(row)
                capture_before_transition = row
            if event == 'phase_begin' and capture_before_transition and capture_before_transition['next_sample_step'] == step:
                transition['pre_solver_frame_change'] = compare(capture_before_transition, row, 'pre_solver_frame')
                capture_before_transition = None
            category = 'phase' if event in ('phase_begin', 'phase_end') else 'bone_rotate' if event in ('before_bone_rotate', 'after_bone_rotate') else 'helper_rotate' if event in ('before_helper_rotate', 'after_helper_rotate') else None
            if category is None:
                continue
            key = (category, scope_key(row)) if category == 'phase' else (category, scope_key(row), details.get('iteration'), details.get('joint_bone'))
            if event.startswith('before_') or event == 'phase_begin':
                pending[key].append(row)
                continue
            if not pending[key]:
                warnings.append(f'Unpaired {event} at serial {row["serial"]}.')
                continue
            before = pending[key].pop()
            change = compare(before, row, category)
            plane_change = change['plane_step_deg'] or 0
            if category == 'phase':
                transition['phase_pairs'] += 1
                if details.get('scope') in ('ccd', 'spline', 'manual_roll', 'pure_swing', 'max_angle', 'direct_reach', 'wrist_clamp', 'twist_distribution'):
                    transition['pipeline_phases'].append(change)
                largest = transition['largest_phase_plane_change']
                if largest is None or plane_change > (largest['plane_step_deg'] or 0):
                    transition['largest_phase_plane_change'] = change
                if details.get('scope') == 'pure_swing':
                    # Preserve each pure-swing frame, even if positions are exactly held.
                    transition['pure_swing_phases'].append(change)
            else:
                transition['write_pairs'] += 1
                largest = transition['largest_plane_write']
                if largest is None or plane_change > (largest['plane_step_deg'] or 0):
                    transition['largest_plane_write'] = change
                if plane_change >= 90 and min(change['before']['cross_length_m2'], change['after']['cross_length_m2']) > 1e-8:
                    if transition['first_large_plane_write'] is None:
                        transition['first_large_plane_write'] = change
                    transition['large_plane_writes'].append(change)
                helpers = [value['local_deg'] or 0 for bone, value in change['bone_rotation_steps'].items() if 'Twist' in bone]
                if category == 'helper_rotate' and max(helpers, default=0) >= 30:
                    transition['large_helper_writes'].append(change)
    unmatched = sum(len(stack) for stack in pending.values())
    if unmatched:
        warnings.append(f'{unmatched} unmatched begin/before rows; truncation or row caps may cut pairs.')
    metadata = declared.get('arm_solver_trace', {})
    if metadata.get('dropped_rows', 0):
        warnings.append(f'Trace cap dropped {metadata["dropped_rows"]} events; cannot certify every writer was captured.')
    if metadata.get('rows') is not None and metadata['rows'] != rows:
        warnings.append(f'Manifest rows {metadata["rows"]} do not match parsed rows {rows}.')
    return {'file': str(path), 'sha256': digest.hexdigest(), 'rows': rows, 'manifest_trace': metadata,
            'twist_request_range_deg': [min(twist_requests), max(twist_requests)] if twist_requests else None,
            'twist_distribution_events': len(twist_requests), 'twist_raw_signed_boundary_crossings': twist_crossings,
            'warnings': warnings, 'transitions': list(transitions.values())}


def write_report(directory, report):
    (directory / 'arm_stage_analysis.json').write_text(json.dumps(report, indent=2, allow_nan=False), encoding='utf-8')
    lines = ['# Arm solver writer analysis', '', report['assessment'], '',
             'Before/after writes are paired by event kind, joint, full scope stack and CCD iteration. Phase pairs preserve nested scope context. Quaternion deltas use q/-q equivalence.', '',
             '## Focused transitions', '',
             '| Trace | Step | First >=90-degree bend writer | Plane delta | Unsigned angle before -> after | Helper jumps >=30 degrees |',
             '| --- | ---: | --- | ---: | --- | ---: |']
    for trace in report['traces']:
        for transition in trace['transitions']:
            if transition['step'] not in (5, 11):
                continue
            first = transition['first_large_plane_write']
            location = f"{first['scope']}/{first['joint']}, iteration {first['iteration']}, serial {first['serial_before']}->{first['serial_after']}" if first else 'None observed'
            plane = f"{first['plane_step_deg']:.6f}" if first else '-'
            angles = f"{first['before']['elbow_unsigned_deg']:.6f} -> {first['after']['elbow_unsigned_deg']:.6f}" if first else '-'
            lines.append(f"| {Path(trace['file']).name} | {transition['step']} | {location} | {plane} | {angles} | {len(transition['large_helper_writes'])} |")
    for trace in report['traces']:
        lines.extend(['', f"### {Path(trace['file']).name}", '', f"Parsed rows: {trace['rows']}. SHA256: `{trace['sha256']}`."])
        lines.append(f"Twist distribution events: {trace['twist_distribution_events']}; raw requested range (degrees): {trace['twist_request_range_deg']}; consecutive raw signed-boundary crossings (>180-degree difference): {len(trace['twist_raw_signed_boundary_crossings'])}.")
        if not trace['twist_raw_signed_boundary_crossings']:
            lines.append('This trace does not exercise a raw signed-boundary crossing; absence of helper jumps here is not itself proof of wrap-boundary continuity.')
        else:
            lines.append(f"Crossing evidence: `{json.dumps(trace['twist_raw_signed_boundary_crossings'])}`.")
        frame_changes = [t['pre_solver_frame_change'] for t in trace['transitions']
            if t['pre_solver_frame_change'] and (t['pre_solver_frame_change']['plane_step_deg'] or 0) >= 20]
        if frame_changes:
            lines.extend(['', 'Large frame changes between the preceding capture and the first traced solver scope (these identify a pre-solver change, not its exact uninstrumented caller):', '',
                '| Step | Serials | World plane delta | Upperarm-local plane delta | Clavicle local rotation | Upperarm local rotation | Forearm local rotation |',
                '| ---: | --- | ---: | ---: | ---: | ---: | ---: |'])
            for change in frame_changes:
                local = change['bone_rotation_steps']
                lines.append(f"| {change['step']} | {change['serial_before']}->{change['serial_after']} | {change['plane_step_deg']:.6f} | {change['upperarm_local_plane_step_deg']:.6f} | {local['Clavicle']['local_deg']:.6f} | {local['Upperarm']['local_deg']:.6f} | {local['Forearm']['local_deg']:.6f} |")
        for warning in trace['warnings']:
            lines.append(f'- WARNING: {warning}')
        for step in (5, 11):
            transition = next((t for t in trace['transitions'] if t['step'] == step), None)
            if not transition:
                continue
            lines.extend(['', f'Step {step}, {transition["phase"]}: {transition["write_pairs"]} write pairs, {transition["phase_pairs"]} phase pairs.'])
            first = transition['first_large_plane_write']
            if first:
                lines.append(f"First reversal scope stack: `{json.dumps(first['scope_stack'])}`. Writer details: `{json.dumps(first['writer_details'])}`.")
            for phase in transition['pipeline_phases']:
                if phase['scope'] == 'max_angle':
                    lines.append(f"Max-angle stage: unsigned bend {phase['before']['elbow_unsigned_deg']:.6f} -> {phase['after']['elbow_unsigned_deg']:.6f} degrees; plane change {(phase['plane_step_deg'] or 0):.6f} degrees; serial {phase['serial_before']}->{phase['serial_after']}.")
            for helper in transition['large_helper_writes'][:8]:
                name = str(helper['joint']).removeprefix('CC_Base_L_').removeprefix('CC_Base_R_')
                amount = helper['bone_rotation_steps'].get(name, {}).get('local_deg')
                lines.append(f"Helper {helper['joint']}: {amount:.6f} degrees, serial {helper['serial_before']}->{helper['serial_after']}, details `{json.dumps(helper['writer_details'])}`.")
            for twist in transition['twist_events']:
                details = twist['details']
                if twist['event'] == 'twist_distribution_result':
                    lines.append(f"Twist request {details.get('requested_degrees')} degrees; distributed Forearm total {details.get('forearm_applied_degrees')} degrees, Upperarm total {details.get('upperarm_applied_degrees')} degrees, serial {twist['serial']}.")
            phases = transition['pure_swing_phases']
            if phases:
                maximum = max(phases, key=lambda p: p['upperarm_local_plane_step_deg'] or 0)
                lines.append(f"Pure-swing phases: {len(phases)}; largest Upperarm-local bend-frame change {(maximum['upperarm_local_plane_step_deg'] or 0):.6f} degrees, physical world-plane change {(maximum['plane_step_deg'] or 0):.6f} degrees, hand translation {maximum['hand_translation_m']:.9f} m, serial {maximum['serial_before']}->{maximum['serial_after']}.")
    lines.extend(['', 'These measurements identify writers and discontinuities, not an anatomical validity certificate. A geometric normal near exact straightness is unstable; inspect cross magnitude and unsigned angle. Detailed before/after data and all transitions are in arm_stage_analysis.json.', ''])
    (directory / 'ARM_STAGE_ANALYSIS.md').write_text('\n'.join(lines), encoding='utf-8')


def vector(value):
    if isinstance(value, list) and len(value) == 3:
        return value
    if isinstance(value, str) and value.startswith('('):
        values = [float(x) for x in re.findall(r'[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?', value)]
        return values if len(values) == 3 else None
    return None


def distance(a, b):
    a, b = vector(a), vector(b)
    return math.dist(a, b) if a is not None and b is not None else None


def maximum(values):
    return max((x for x in values if x is not None), default=None)


def signed_planar_angle(a, b, axis):
    a, b, axis = vector(a), vector(b), vector(axis)
    if a is None or b is None or axis is None:
        return None
    axis = norm(axis)
    a = norm([a[i] - axis[i] * dot(a, axis) for i in range(3)])
    b = norm([b[i] - axis[i] * dot(b, axis) for i in range(3)])
    if a is None or b is None:
        return None
    return math.degrees(math.atan2(dot(axis, cross(a, b)), dot(a, b)))


def after_capture_rows(directory, declared):
    name = declared.get('arm_solver_trace', {}).get('file')
    if not name or not (directory / name).is_file():
        return {}
    result = {}
    with (directory / name).open(encoding='utf-8-sig') as stream:
        for line in stream:
            row = json.loads(line)
            if row.get('event') == 'capture_baseline':
                # The fixture logs this after the previous sample's frame-post-
                # draw screenshot wait, before accepting the next pointer input.
                result[row['next_sample_step'] - 1] = row
    return result


def summarize_samples(directory):
    manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8-sig'))
    rows = [json.loads(line) for line in (directory / 'samples.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    declared_cases = {case.get('case'): case for case in manifest.get('cases', [])}
    names = list(dict.fromkeys([row['case'] for row in rows] + list(declared_cases)))
    cases = []
    for name in names:
        declared = declared_cases.get(name, {})
        if declared.get('warmup_only') or ('warmup_only' not in declared and '_pass_1_' in name):
            continue
        side = name.split('_')[0]
        group = [row for row in rows if row['case'] == name]
        expected = declared.get('expected_samples')
        phases = {phase: [row for row in group if row.get('phase') == phase] for phase in ('initial', 'maximum_extension', 'retracted_held', 'elbow_correction', 'elbow_corrected_released')}
        metadata = {'case': name, 'side': side, 'hand_pass': declared.get('hand_pass'),
                    'movement_variant': declared.get('movement_variant', {}),
                    'target_rule': declared.get('correction_start', {}).get('target_rule'),
                    'expected_samples': expected, 'samples': len(group)}
        if not all(phases.values()) or (expected is not None and len(group) != expected):
            cases.append({**metadata, 'complete': False, 'reason': 'Missing phase or unexpected sample count'})
            continue
        initial, extended, held, final = [phases[p][0] for p in ('initial', 'maximum_extension', 'retracted_held', 'elbow_corrected_released')]
        extension_pose, held_pose = sample_pose(extended, side), sample_pose(held, side)
        pull_rows = [row for row in group if row['phase'] == 'pull']
        pull_acceptance = [{'step': row['step'],
            'request_accepted_gap_m': distance(row.get('requested_pommel_local'), row.get('accepted_pommel_local')),
            'drag_legal': row.get('drag_validation', {}).get('legal'),
            'body_clearance_rejected': row.get('drag_validation', {}).get('body_clearance_rejected', False),
            'collision_region': row.get('drag_validation', {}).get('collision_region')} for row in pull_rows]
        # This is a numeric reporting tolerance, not a new runtime acceptance rule.
        accepted_pull_count = sum(row['request_accepted_gap_m'] is not None and row['request_accepted_gap_m'] <= 0.00001
            and row['drag_legal'] is True for row in pull_acceptance)
        manual = phases['elbow_correction']
        manual_and_release = manual + [final]
        automatic = [row for row in group if row['step'] <= held['step']]
        pairs = list(zip(group, group[1:]))
        helper_jumps = []
        helper_maximum = 0.0
        for before, after in pairs:
            for bone, state in after['bones'].items():
                if 'Twist' in bone:
                    degrees = angle(before['bones'][bone]['local_quaternion'], state['local_quaternion'], True)
                    helper_maximum = max(helper_maximum, degrees or 0)
                    if degrees is not None and degrees >= 30:
                        helper_jumps.append({'step': after['step'], 'bone': bone, 'degrees': degrees})
        sample_details = []
        for i, row in enumerate(group):
            sample_details.append({'step': row['step'], 'phase': row['phase'], 'ready': row['prepared_grip_readiness']['ready'],
                'elbow_unsigned_deg': row['elbow_inner_angle_degrees'], 'shoulder_to_hand_m': row['shoulder_to_hand_m'], 'arm_length_m': row['arm_length_m'],
                'plane_step_deg': angle(group[i - 1]['elbow_plane_character_space'], row['elbow_plane_character_space']) if i else None,
                'radial_step_deg': angle(group[i - 1]['elbow_radial_world'], row['elbow_radial_world']) if i else None,
                'request_accepted_gap_m': distance(row.get('requested_pommel_local'), row.get('accepted_pommel_local')),
                'rendered_pommel_from_held_m': distance(row.get('resolved_pommel_position_local'), held.get('resolved_pommel_position_local')),
                'accepted_pommel_local': row.get('accepted_pommel_local'), 'requested_pommel_local': row.get('requested_pommel_local'),
                'accepted_tip_local': row.get('accepted_tip_local'), 'dominant_grip_alignment_error_m': row.get('dominant_grip_alignment_error_meters'),
                'authored_pommel_drift_m': row.get('authored_pommel_drift_m'), 'authored_tip_drift_m': row.get('authored_tip_drift_m')})
        details_by_step = {sample['step']: sample for sample in sample_details}
        automatic_metrics = [details_by_step[row['step']] for row in automatic]
        manual_metrics = [details_by_step[row['step']] for row in manual_and_release]
        start = declared.get('correction_start', {})
        gizmo = start.get('gizmo', {})
        control_axis = vector(gizmo.get('axis_global'))
        previous_radial = vector(gizmo.get('initial_normal_global')) or held['elbow_radial_world']
        achieved_total = 0.0
        rendered_captures = after_capture_rows(directory, declared)
        previous_after_render_radial = previous_radial
        previous_after_render_bones = rendered_captures.get(held['step'], {}).get('bones', {})
        after_render_total = 0.0
        after_render_helper_max = 0.0
        manual_steps = []
        for index, row in enumerate(manual):
            achieved_increment = signed_planar_angle(previous_radial, row['elbow_radial_world'], control_axis)
            if achieved_increment is not None:
                achieved_total += achieved_increment
            next_capture = manual_and_release[index + 1]
            desired = vector(row.get('requested_control_normal_world'))
            after_render = rendered_captures.get(row['step'])
            after_render_pose = pose(after_render) if after_render else None
            after_render_increment = signed_planar_angle(previous_after_render_radial, after_render_pose['radial_world'], control_axis) if after_render_pose else None
            if after_render_increment is not None:
                after_render_total += after_render_increment
                previous_after_render_radial = after_render_pose['radial_world']
            if after_render:
                for bone, state in after_render['bones'].items():
                    if 'Twist' in bone and bone in previous_after_render_bones:
                        after_render_helper_max = max(after_render_helper_max, angle(previous_after_render_bones[bone]['local_q'], state['local_q'], True) or 0)
                previous_after_render_bones = after_render['bones']
            manual_steps.append({'sample_step': row['step'], 'requested_step_deg': row.get('requested_step_degrees'),
                'requested_cumulative_deg': row.get('requested_cumulative_arc_degrees'), 'pointer_resolved_roll_deg': row.get('pointer_resolved_roll_degrees'),
                'observed_increment_deg': achieved_increment, 'observed_cumulative_deg': achieved_total,
                'same_capture_target_error_deg': angle(desired, row['elbow_radial_world']),
                'next_capture_target_error_deg': angle(desired, next_capture['elbow_radial_world']),
                'next_capture_observed_increment_deg': signed_planar_angle(row['elbow_radial_world'], next_capture['elbow_radial_world'], control_axis),
                'after_render_capture_serial': after_render.get('serial') if after_render else None,
                'after_render_process_frame': after_render.get('process_frame') if after_render else None,
                'after_render_observed_increment_deg': after_render_increment,
                'after_render_observed_cumulative_deg': after_render_total if after_render else None,
                'after_render_target_error_deg': angle(desired, after_render_pose['radial_world']) if after_render_pose else None,
                'after_render_elbow_unsigned_deg': after_render_pose['elbow_unsigned_deg'] if after_render_pose else None,
                'after_render_hand_target_gap_m': after_render_pose['hand_target_gap_m'] if after_render_pose else None,
                'after_render_manual_roll_deg': after_render.get('manual_roll_degrees') if after_render else None})
            previous_radial = row['elbow_radial_world']
        release_increment = signed_planar_angle(previous_radial, final['elbow_radial_world'], control_axis)
        if release_increment is not None:
            achieved_total += release_increment
        # Separate the real release solve from latency in the last raw sample.
        before_release = rendered_captures.get(manual[-1]['step'])
        before_release_pose = pose(before_release) if before_release else None
        final_hand = final['bones'].get(f'CC_Base_{side}_Hand', {})
        release_after_render = None
        if before_release_pose and final_hand:
            release_after_render = {
                'before_trace_serial': before_release['serial'],
                'before_process_frame': before_release['process_frame'],
                'elbow_before_deg': before_release_pose['elbow_unsigned_deg'],
                'elbow_final_deg': final['elbow_inner_angle_degrees'],
                'radial_change_deg': angle(before_release_pose['radial_world'], final['elbow_radial_world']),
                'signed_control_arc_change_deg': signed_planar_angle(before_release_pose['radial_world'], final['elbow_radial_world'], control_axis),
                'hand_translation_m': distance(before_release_pose['hand_world'], final_hand['world_position']),
                'hand_world_rotation_deg': angle(before_release['bones']['Hand']['world_q'], final_hand['world_quaternion'], True),
                'hand_gap_to_pre_release_target_before_m': before_release_pose['hand_target_gap_m'],
                'hand_gap_to_pre_release_target_final_m': distance(before_release.get('hand_target_world'), final_hand['world_position']),
                'helper_max_step_deg': maximum(angle(before_release['bones'][bone.removeprefix(f'CC_Base_{side}_')]['local_q'], state['local_quaternion'], True)
                    for bone, state in final['bones'].items() if 'Twist' in bone and bone.removeprefix(f'CC_Base_{side}_') in before_release['bones'])}
        candidate_events = declared.get('continuity_candidate', {}).get('events', [])
        cases.append({**metadata, 'complete': declared.get('complete'),
            'ready_samples': sum(row['prepared_grip_readiness']['ready'] is True for row in group),
            'initial_to_extension_radial_deg': angle(initial['elbow_radial_world'], extended['elbow_radial_world']),
            'extension_to_held_radial_deg': angle(extended['elbow_radial_world'], held['elbow_radial_world']),
            'initial_to_held_radial_deg': angle(initial['elbow_radial_world'], held['elbow_radial_world']),
            'extension_to_held_plane_deg': angle(extended['elbow_plane_character_space'], held['elbow_plane_character_space']),
            'extension_to_held_upperarm_local_plane_deg': angle(extension_pose['bend_normal_upperarm_local'], held_pose['bend_normal_upperarm_local']),
            'maximum_pull_upperarm_local_plane_from_extension_deg': maximum(angle(extension_pose['bend_normal_upperarm_local'], sample_pose(row, side)['bend_normal_upperarm_local']) for row in pull_rows),
            'pull_target_acceptance': pull_acceptance, 'accepted_pull_target_count': accepted_pull_count,
            'requested_pull_target_count': len(pull_rows), 'all_pull_targets_accepted': accepted_pull_count == len(pull_rows),
            'automatic_max_plane_step_deg': maximum(s['plane_step_deg'] for s in automatic_metrics),
            'automatic_max_radial_step_deg': maximum(s['radial_step_deg'] for s in automatic_metrics),
            'maximum_elbow_deg': maximum(row['elbow_inner_angle_degrees'] for row in group),
            'max_request_accepted_gap_m': maximum(s['request_accepted_gap_m'] for s in sample_details),
            'max_dominant_grip_alignment_error_m': maximum(s['dominant_grip_alignment_error_m'] for s in sample_details),
            'maximum_reach_m': maximum(row['shoulder_to_hand_m'] for row in group),
            'initial_held_final_reach_m': [row['shoulder_to_hand_m'] for row in (initial, held, final)],
            'final_rendered_pommel_drift_m': details_by_step[final['step']]['rendered_pommel_from_held_m'],
            'max_manual_rendered_pommel_drift_m': maximum(s['rendered_pommel_from_held_m'] for s in manual_metrics),
            'max_effective_accepted_pommel_from_held_m': maximum(distance(row['accepted_pommel_local'], held['accepted_pommel_local']) for row in manual_and_release),
            'max_effective_accepted_tip_from_held_m': maximum(distance(row['accepted_tip_local'], held['accepted_tip_local']) for row in manual_and_release),
            'max_manual_authored_pommel_drift_m': maximum(row.get('authored_pommel_drift_m') for row in manual),
            'max_manual_authored_tip_drift_m': maximum(row.get('authored_tip_drift_m') for row in manual),
            'release_effective_pommel_from_drag_start_m': distance(final['accepted_pommel_local'], manual[0]['accepted_pommel_local']),
            'pointer_arc_requested_deg': declared.get('correction_start', {}).get('pointer_arc_degrees'),
            'final_desired_radial_error_deg': angle(vector(declared.get('correction_start', {}).get('desired_radial_world')), final['elbow_radial_world']),
            'manual_observed_total_including_release_deg': achieved_total, 'manual_release_increment_deg': release_increment,
            'manual_step_measurements': manual_steps, 'maximum_helper_local_step_deg': helper_maximum,
            'manual_after_render_max_helper_step_deg': after_render_helper_max,
            'release_from_after_render_pose': release_after_render,
            'helper_jumps_ge30deg': helper_jumps, 'candidate_interventions': len(candidate_events),
            'candidate_interventions_by_sample': dict(collections.Counter(e.get('sample') for e in candidate_events)),
            'candidate_interventions_by_scope': dict(collections.Counter(e.get('scope') for e in candidate_events)),
            'sample_metrics': sample_details})
    # Backward compatible side summary only when that side has exactly one case.
    # Multiple elevations must remain explicit cases rather than overwriting one.
    result = {side: matches[0] for side in ('L', 'R') if len(matches := [case for case in cases if case['side'] == side]) == 1}
    return {'directory': str(directory), 'manifest_complete': manifest.get('complete'), 'cases': cases, 'sides': result}


def write_motion_summary(directory, report):
    lines = ['# Arm movement and manual control summary', '',
             'Uses actual manifest case IDs and phase boundaries. Different control modes are not treated as identical targets. Raw sample capture precedes the screenshot frame-post-draw wait; its bone state can precede input realization. The trace capture_baseline after that wait and before the next input supplies explicit after-render measurements. Original same-capture/next-capture measurements remain in JSON; no data is shifted or replaced.', '']
    for case in report['cases']:
        lines.extend([f'## {case["case"]}', '', f"Capture complete: {case['complete']}; samples: {case['samples']}/{case['expected_samples']}.",
                      f"Movement variant: `{json.dumps(case['movement_variant'])}`.", f"Control target rule: {case['target_rule']}."])
        if not case['complete']:
            continue
        lines.extend(['', f"Binding ready: {case['ready_samples']}/{case['samples']}; extension-to-held plane change {case['extension_to_held_plane_deg']:.6f} degrees; largest automatic adjacent plane change {case['automatic_max_plane_step_deg']:.6f} degrees.",
            f"Extension-to-held Upperarm-local bend-plane change {case['extension_to_held_upperarm_local_plane_deg']:.6f} degrees; maximum local bend-plane excursion during pull {case['maximum_pull_upperarm_local_plane_from_extension_deg']:.6f} degrees. World-plane rotation alone does not identify a local hinge reversal.",
            f"Requested pull targets accepted: {case['accepted_pull_target_count']}/{case['requested_pull_target_count']} (drag legal and requested/accepted position within 0.00001 m). Per-step validation: `{json.dumps(case['pull_target_acceptance'])}`. Binding readiness alone does not establish that the requested retraction was accepted.",
            f"Maximum helper local quaternion change {case['maximum_helper_local_step_deg']:.6f} degrees. Jumps >=30 degrees: `{json.dumps(case['helper_jumps_ge30deg'])}`.",
            f"Requested total control arc {case['pointer_arc_requested_deg']} degrees; measured total including release {case['manual_observed_total_including_release_deg']:.6f} degrees; final target radial error {case['final_desired_radial_error_deg']:.6f} degrees.",
            f"Maximum rendered pommel movement from held pose {case['max_manual_rendered_pommel_drift_m']:.9f} m; final {case['final_rendered_pommel_drift_m']:.9f} m. Explicit authored endpoint drift during pointer movement: pommel {case['max_manual_authored_pommel_drift_m']}, tip {case['max_manual_authored_tip_drift_m']} m.", '',
            '| Sample | Requested increment | Requested cumulative | Observed increment after render | Observed cumulative after render | Target error after render | Trace serial | Process frame |',
            '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'])
        for step in case['manual_step_measurements']:
            values = [step[key] for key in ('sample_step', 'requested_step_deg', 'requested_cumulative_deg', 'after_render_observed_increment_deg', 'after_render_observed_cumulative_deg', 'after_render_target_error_deg', 'after_render_capture_serial', 'after_render_process_frame')]
            lines.append('| ' + ' | '.join(f'{value:.6f}' if isinstance(value, float) else str(value) for value in values) + ' |')
        if case.get('release_from_after_render_pose'):
            release = case['release_from_after_render_pose']
            lines.extend(['', f"Release measured from actual final after-render drag pose (trace serial {release['before_trace_serial']}, process frame {release['before_process_frame']}): elbow {release['elbow_before_deg']:.6f} -> {release['elbow_final_deg']:.6f} degrees; radial change {release['radial_change_deg']:.6f} degrees; hand translation {release['hand_translation_m']:.9f} m. Hand distance from the pre-release target {release['hand_gap_to_pre_release_target_before_m']:.9f} -> {release['hand_gap_to_pre_release_target_final_m']:.9f} m. This comparison excludes stale raw last-input sampling."])
        lines.append('')
    (directory / 'arm_motion_summary.json').write_text(json.dumps(report, indent=2, allow_nan=False), encoding='utf-8')
    (directory / 'ARM_MOTION_SUMMARY.md').write_text('\n'.join(lines), encoding='utf-8')


def compare_runs(reference, directory):
    baseline, candidate = summarize_samples(reference), summarize_samples(directory)
    report = {'assessment': 'Protocol comparison only, not an anatomical certificate. Inspect each movement_variant and target_rule: different manual input sequences are not a matched-input comparison. Targets derive from each run accepted pose and may differ. Candidate intervention counts identify diagnostic hooks when present.',
              'baseline': baseline, 'candidate': candidate}
    lines = ['# Reference versus compared arm run', '', report['assessment'], '',
             '| Metric | Reference L | Compared L | Reference R2 | Compared R2 |', '| --- | ---: | ---: | ---: | ---: |']
    metrics = [('Ready samples', 'ready_samples'), ('Initial to extension radial, deg', 'initial_to_extension_radial_deg'),
        ('Extension to held radial, deg', 'extension_to_held_radial_deg'), ('Initial to held radial, deg', 'initial_to_held_radial_deg'),
        ('Extension to held bend plane, deg', 'extension_to_held_plane_deg'), ('Max automatic adjacent plane change, deg', 'automatic_max_plane_step_deg'),
        ('Max automatic adjacent radial change, deg', 'automatic_max_radial_step_deg'), ('Maximum unsigned elbow angle, deg', 'maximum_elbow_deg'),
        ('Max request to accepted pommel gap, m', 'max_request_accepted_gap_m'), ('Maximum shoulder-hand reach, m', 'maximum_reach_m'),
        ('Maximum grip alignment error, m', 'max_dominant_grip_alignment_error_m'), ('Explicit authored pommel drift during pointer drag, m', 'max_manual_authored_pommel_drift_m'),
        ('Explicit authored tip drift during pointer drag, m', 'max_manual_authored_tip_drift_m'),
        ('Max effective accepted pommel change from held pose, m', 'max_effective_accepted_pommel_from_held_m'),
        ('Effective pommel change on release from drag start, m', 'release_effective_pommel_from_drag_start_m'),
        ('Final rendered pommel drift, m', 'final_rendered_pommel_drift_m'),
        ('Max rendered pommel drift during manual edit, m', 'max_manual_rendered_pommel_drift_m'), ('Requested correction arc, deg', 'pointer_arc_requested_deg'),
        ('Final desired radial error, deg', 'final_desired_radial_error_deg'), ('Branch interventions', 'candidate_interventions')]
    for label, key in metrics:
        values = [run['sides'].get(side, {}).get(key) for side in ('L', 'R') for run in (baseline, candidate)]
        lines.append('| ' + label + ' | ' + ' | '.join(f'{value:.6f}' if isinstance(value, float) else str(value) for value in values) + ' |')
    for side in ('L', 'R'):
        lines.extend(['', f'## {side} helper and intervention details', ''])
        for label, run in [('Baseline', baseline), ('Candidate', candidate)]:
            data = run['sides'].get(side, {})
            lines.append(f"{label} helper jumps >=30 degrees: `{json.dumps(data.get('helper_jumps_ge30deg'))}`.")
        lines.append(f"Candidate interventions by sample: `{json.dumps(candidate['sides'].get(side, {}).get('candidate_interventions_by_sample'))}`.")
    lines.extend(['', 'Full per-step accepted/requested targets, reach, radial/plane changes and grip error are retained in arm_candidate_comparison.json. These are source measurements, not success thresholds. Rendered pommel local-coordinate strings have six-decimal source precision.', ''])
    (directory / 'arm_candidate_comparison.json').write_text(json.dumps(report, indent=2, allow_nan=False), encoding='utf-8')
    (directory / 'ARM_CANDIDATE_COMPARISON.md').write_text('\n'.join(lines), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_directory', type=Path)
    parser.add_argument('--compare-reference', type=Path)
    args = parser.parse_args()
    directory = args.run_directory.resolve()
    manifest_path = directory / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig')) if manifest_path.exists() else {}
    cases = {case.get('arm_solver_trace', {}).get('file'): case for case in manifest.get('cases', [])}
    paths = sorted(directory.glob('arm_solver_*.jsonl'))
    traces = [analyze_trace(path, cases.get(path.name, {})) for path in paths
              if not cases.get(path.name, {}).get('warmup_only', bool(re.search(r'_pass_1(?:_|\.)', path.name)))]
    report = {'assessment': 'Offline stage attribution only; no engine run or anatomical acceptance performed by this analyzer.',
              'manifest_complete': manifest.get('complete', False), 'traces': traces}
    write_report(directory, report)
    write_motion_summary(directory, summarize_samples(directory))
    if args.compare_reference:
        compare_runs(args.compare_reference.resolve(), directory)
    print(f"{len(traces)} non-warmup traces analyzed; manifest_complete={report['manifest_complete']}; {directory / 'ARM_STAGE_ANALYSIS.md'}")


if __name__ == '__main__':
    main()
