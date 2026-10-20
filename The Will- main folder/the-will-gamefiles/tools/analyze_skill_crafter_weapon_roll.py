"""Offline analysis of diagnose_skill_crafter_weapon_roll.gd output.

Full-orbit samples are read-only geometric predictions from the captured frame,
not executed poses or an anatomical feasibility certificate.
"""
import argparse
import json
import math
from pathlib import Path


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def cross(a, b):
    return [a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]]


def q_rotate(q, vector):
    q = normalized(q)
    twice_cross = [2*x for x in cross(q[:3], vector)]
    second_cross = cross(q[:3], twice_cross)
    return [vector[i] + q[3]*twice_cross[i] + second_cross[i] for i in range(3)]


def normalized(value):
    length = math.sqrt(dot(value, value))
    if length < 1e-12:
        raise ValueError('Degenerate recorded vector/quaternion')
    return [x / length for x in value]


def q_inverse(q):
    q = normalized(q)
    return [-q[0], -q[1], -q[2], q[3]]


def q_mul(a, b):
    x, y, z, w = a
    u, v, t, s = b
    return normalized([w*u + x*s + y*t - z*v,
                       w*v - x*t + y*s + z*u,
                       w*t + x*v - y*u + z*s,
                       w*s - x*u - y*v - z*t])


def q_axis(axis, degrees):
    half = math.radians(degrees) * 0.5
    return [x * math.sin(half) for x in normalized(axis)] + [math.cos(half)]


def q_angle(a, b):
    # q/-q equivalence, independent of Godot's angle_to small-angle precision.
    return math.degrees(2 * math.acos(max(-1.0, min(1.0, abs(dot(normalized(a), normalized(b)))))))


def vector_angle(a, b):
    return math.degrees(math.acos(max(-1.0, min(1.0, dot(normalized(a), normalized(b))))))


def wrist_metrics(hand_q, neutral_q, forearm_axis):
    delta = q_mul(hand_q, q_inverse(neutral_q))
    if delta[3] < 0:
        delta = [-x for x in delta]
    axis = normalized(forearm_axis)
    projection = dot(delta[:3], axis)
    twist = [x * projection for x in axis] + [delta[3]]
    singular_twist = dot(twist, twist) < 1e-16
    twist = [0.0, 0.0, 0.0, 1.0] if singular_twist else normalized(twist)
    signed_twist = math.degrees(2 * math.atan2(dot(twist[:3], axis), twist[3]))
    swing = q_mul(delta, q_inverse(twist))
    return {'reference_distance_deg': q_angle(hand_q, neutral_q),
            'forearm_twist_deg': signed_twist,
            'swing_deg': q_angle(swing, [0, 0, 0, 1]),
            'twist_decomposition_singular': singular_twist}


def predicted_hand(baseline_q, axis, delta):
    return q_mul(q_axis(axis, delta), baseline_q)


def full_orbit(baseline_q, neutral_q, axis, forearm_axis, baseline_scalar, hand_direction):
    # Maximize |dot(q_neutral, q_axis(theta)*q_baseline)|. The scalar
    # coefficients are the real and axis-projected imaginary components of
    # q_neutral*q_baseline^-1. No sampled physical pose is altered.
    wanted = q_mul(neutral_q, q_inverse(baseline_q))
    a, b = wanted[3], dot(wanted[:3], normalized(axis))
    ambiguous = math.hypot(a, b) < 1e-12
    closest_delta = None if ambiguous else (math.degrees(2 * math.atan2(b, a)) + 180) % 360 - 180
    def entry(delta):
        return {'delta_from_baseline_deg': delta, 'authored_scalar_deg': baseline_scalar + delta,
                'geometric_wrist_bend_deg': vector_angle(forearm_axis, q_rotate(q_axis(axis, delta), hand_direction)),
                **wrist_metrics(predicted_hand(baseline_q, axis, delta), neutral_q, forearm_axis)}
    samples = [entry(float(degrees)) for degrees in range(-180, 181)]
    closest = entry(closest_delta) if closest_delta is not None else None
    # Maximize dot(forearm, rotate(axis, theta)*hand_direction), independently
    # of bone-local rest orientation or twist. This measures hand straightness
    # only, not anatomical feasibility or an acceptable palm-facing direction.
    f, h, k = normalized(forearm_axis), normalized(hand_direction), normalized(axis)
    c = dot(f, k)*dot(k, h)
    geometric_a, geometric_b = dot(f, h) - c, dot(f, cross(k, h))
    geometric_ambiguous = math.hypot(geometric_a, geometric_b) < 1e-12
    straightest_delta = None if geometric_ambiguous else math.degrees(math.atan2(geometric_b, geometric_a))
    baseline = entry(0)
    return {'scope': 'Read-only predicted full 360-degree Wrist-to-Tip orbit. Reference closeness is not anatomical acceptance.',
            'reference_rule': 'Fixed neutral quaternion recorded at baseline',
            'ambiguous_closest_angle': ambiguous, 'closest_reference': closest,
            'geometric_straightness_rule': 'Angle between elbow-to-wrist and wrist-to-Index1/Pinky1 midpoint; independent of bone basis',
            'ambiguous_geometric_straightest_angle': geometric_ambiguous,
            'geometric_straightest': entry(straightest_delta) if straightest_delta is not None else None,
            'sampled_closest_reference': min(samples, key=lambda x: x['reference_distance_deg']),
            'positive_5deg_improves_reference_distance': entry(5)['reference_distance_deg'] < baseline['reference_distance_deg'],
            'negative_5deg_improves_reference_distance': entry(-5)['reference_distance_deg'] < baseline['reference_distance_deg'],
            'samples_one_degree': samples}


def maximum(values):
    return max((v for v in values if isinstance(v, (int, float))), default=None)


def analyze_case(name, group, declared):
    baseline = next((r for r in group if r.get('phase') == 'neutral'), None)
    if baseline is None:
        return {'case': name, 'complete': False, 'reason': 'Missing captured baseline'}
    base_q = baseline['hand_world']['quaternion']
    neutral_q = baseline['hand_neutral_world_quaternion']
    base_scalar = baseline['authored_roll_degrees']
    axis = normalized(sub(baseline['tip_world'], baseline['hand_world']['origin']))
    forearm_axis = normalized(baseline['forearm_longitudinal_world'])
    hand_direction = normalized(baseline['wrist_to_finger_roots_world'])
    neutral_hand_direction = q_rotate(q_mul(neutral_q, q_inverse(base_q)), hand_direction)
    baseline_grip_q = q_mul(q_inverse(base_q), baseline['weapon_world']['quaternion'])
    baseline_bones = baseline.get('bones', {})
    measurements = []
    for row in group:
        actual = wrist_metrics(row['hand_world']['quaternion'], row['hand_neutral_world_quaternion'], row['forearm_longitudinal_world'])
        actual['geometric_wrist_bend_deg'] = vector_angle(row['forearm_longitudinal_world'], row['wrist_to_finger_roots_world'])
        raw = row.get('unclamped_resolver_request', {})
        raw_metrics = wrist_metrics(raw['hand_world']['quaternion'], row['hand_neutral_world_quaternion'], row['forearm_longitudinal_world']) if raw.get('available') else None
        expected_q = predicted_hand(base_q, axis, row['authored_roll_degrees'] - base_scalar)
        actual_grip_q = q_mul(q_inverse(row['hand_world']['quaternion']), row['weapon_world']['quaternion'])
        observed_non_hand = {bone: q_angle(baseline_bones[bone]['local_quaternion'], state['local_quaternion'])
            for bone, state in row.get('bones', {}).items() if bone in baseline_bones and not bone.endswith('_Hand')}
        measurements.append({'step': row['step'], 'phase': row['phase'],
            'requested_deg': row['requested_roll_degrees'], 'authored_deg': row['authored_roll_degrees'],
            'request_authored_gap_deg': row['requested_roll_degrees'] - row['authored_roll_degrees'],
            'rendered_signed_roll_deg': row['rendered_roll_from_baseline_degrees'],
            'setter_reported_change': row.get('setter_reported_change'), 'status': row.get('status'),
            'ready': row.get('prepared_grip_readiness', {}).get('ready'),
            'retained_roll_matches': row.get('retained_roll_matches'),
            'actual': actual, 'unclamped_requested_geometry': raw_metrics,
            'actual_vs_authored_orbit_error_deg': q_angle(row['hand_world']['quaternion'], expected_q),
            'geometric_direction_prediction_error_deg': vector_angle(row['wrist_to_finger_roots_world'], q_rotate(q_axis(axis, row['authored_roll_degrees'] - base_scalar), hand_direction)),
            'neutral_reference_drift_deg': q_angle(neutral_q, row['hand_neutral_world_quaternion']),
            'forearm_axis_drift_deg': vector_angle(forearm_axis, row['forearm_longitudinal_world']),
            'wrist_position_error_m': row['wrist_position_error_m'], 'tip_position_error_m': row['tip_position_error_m'],
            'pommel_delta_m': row['pommel_delta_m'], 'rigid_grip_position_error_m': row['rigid_grip_position_error_m'],
            'rigid_grip_angle_error_degrees': row['rigid_grip_angle_error_degrees'],
            'offline_rigid_grip_angle_error_deg': q_angle(baseline_grip_q, actual_grip_q),
            'offline_observed_non_hand_rotation_deg': observed_non_hand,
            'non_hand_max_local_rotation_degrees': row['non_hand_max_local_rotation_degrees'],
            'non_hand_max_local_translation_m': row['non_hand_max_local_translation_m'],
            'image': row.get('image'), 'wrist_image': row.get('wrist_image')})
    orbit = full_orbit(base_q, neutral_q, axis, forearm_axis, base_scalar, hand_direction)
    closest = orbit['closest_reference']
    ui_min, ui_max = declared.get('ui_roll_min'), declared.get('ui_roll_max')
    if closest and ui_min is not None and ui_max is not None:
        equivalents = [closest['authored_scalar_deg'] + k * 360 for k in range(-3, 4)]
        orbit['closest_reference_equivalent_scalars_within_ui_range'] = [v for v in equivalents if ui_min <= v <= ui_max]
    accepted = [r for r in measurements if abs(r['request_authored_gap_deg']) <= 0.0001 and r['phase'] in ('numeric_sweep', 'numeric_boundary_probe', 'pointer_move')]
    gated = [r for r in measurements if abs(r['request_authored_gap_deg']) > 0.0001]
    return {'case': name, 'side': name.split('_')[0], 'complete': declared.get('complete'),
        'sample_count': len(group), 'declared_sample_count': declared.get('samples'),
        'prepared_ready_count': sum(r['ready'] is True for r in measurements),
        'pointer_failures': declared.get('pointer_failures', []),
        'baseline_authored_deg': base_scalar, 'ui_roll_min': ui_min, 'ui_roll_max': ui_max,
        'neutral_reference_rule': baseline['hand_neutral_reference_rule'], 'hand_parent_bone': baseline['hand_parent_bone'],
        'baseline_metrics': wrist_metrics(base_q, neutral_q, forearm_axis),
        'baseline_geometric_wrist_bend_deg': vector_angle(forearm_axis, hand_direction),
        'neutral_reference_geometric_wrist_bend_deg': vector_angle(forearm_axis, neutral_hand_direction),
        'neutral_reference_mcp_direction_rule': 'Captured wrist-to-MCP direction rigidly rotated by neutral quaternion times inverse captured Hand quaternion; retains captured finger-root offsets',
        'geometric_directions_world': {'forearm': forearm_axis, 'baseline_hand': hand_direction, 'neutral_reference_hand': neutral_hand_direction, 'roll_axis': axis},
        'wrist_to_tip_vs_forearm_axis_deg': vector_angle(axis, forearm_axis),
        'exact_request_observed_range_deg': [min((r['requested_deg'] for r in accepted), default=None), max((r['requested_deg'] for r in accepted), default=None)],
        'gated_requests': [{'step': r['step'], 'requested_deg': r['requested_deg'], 'authored_deg': r['authored_deg'], 'status': r['status']} for r in gated],
        'maximum_actual_vs_authored_orbit_error_deg': maximum(r['actual_vs_authored_orbit_error_deg'] for r in measurements),
        'maximum_geometric_direction_prediction_error_deg': maximum(r['geometric_direction_prediction_error_deg'] for r in measurements),
        'maximum_neutral_reference_drift_deg': maximum(r['neutral_reference_drift_deg'] for r in measurements),
        'maximum_forearm_axis_drift_deg': maximum(r['forearm_axis_drift_deg'] for r in measurements),
        'maximum_wrist_position_error_m': maximum(r['wrist_position_error_m'] for r in measurements),
        'maximum_tip_position_error_m': maximum(r['tip_position_error_m'] for r in measurements),
        'maximum_rigid_grip_position_error_m': maximum(r['rigid_grip_position_error_m'] for r in measurements),
        'maximum_rigid_grip_angle_error_deg': maximum(r['rigid_grip_angle_error_degrees'] for r in measurements),
        'maximum_offline_rigid_grip_angle_error_deg': maximum(r['offline_rigid_grip_angle_error_deg'] for r in measurements),
        'maximum_offline_observed_non_hand_rotation_deg': maximum(degrees for r in measurements for degrees in r['offline_observed_non_hand_rotation_deg'].values()),
        'maximum_non_hand_local_rotation_deg': maximum(r['non_hand_max_local_rotation_degrees'] for r in measurements),
        'maximum_non_hand_local_translation_m': maximum(r['non_hand_max_local_translation_m'] for r in measurements),
        'full_orbit_geometry': orbit, 'measurements': measurements}


def analyze(directory):
    manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8-sig'))
    rows = [json.loads(line) for line in (directory / 'samples.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    declared = {case['case']: case for case in manifest.get('cases', [])}
    names = list(dict.fromkeys(row['case'] for row in rows))
    cases = [analyze_case(name, [row for row in rows if row['case'] == name], declared.get(name, {})) for name in names if not declared.get(name, {}).get('warmup_only')]
    return {'directory': str(directory), 'manifest_complete': manifest.get('complete'),
        'scope': 'Executed UI observations are separate from predicted full-orbit geometry. Neutral-reference closeness does not define allowable wrist anatomy. Rendered signed roll wraps at 180 degrees; quaternion comparison uses the full authored scalar.',
        'cases': cases}


def write_report(directory, report):
    (directory / 'weapon_roll_analysis.json').write_text(json.dumps(report, indent=2, allow_nan=False), encoding='utf-8')
    lines = ['# Weapon Roll observation and neutral-reference analysis', '', report['scope'], '']
    for case in report['cases']:
        lines.extend([f"## {case['case']}", ''])
        if 'measurements' not in case:
            lines.append(str(case))
            continue
        orbit = case['full_orbit_geometry']
        lines.extend([f"Capture complete: {case['complete']}; samples {case['sample_count']}/{case['declared_sample_count']}; prepared ready {case['prepared_ready_count']}/{case['sample_count']}. Pointer failures: `{json.dumps(case['pointer_failures'])}`.",
            f"UI range {case['ui_roll_min']} to {case['ui_roll_max']} degrees; baseline authored scalar {case['baseline_authored_deg']}. Exact requested values observed in range: {case['exact_request_observed_range_deg']}.",
            f"Neutral: {case['neutral_reference_rule']}; immediate Hand parent: {case['hand_parent_bone']}. Baseline measurements: `{json.dumps(case['baseline_metrics'])}`.",
            f"Wrist-to-Tip axis versus forearm longitudinal axis: {case['wrist_to_tip_vs_forearm_axis_deg']:.6f} degrees. Maximum recorded neutral drift: {case['maximum_neutral_reference_drift_deg']:.6f} degrees.",
            f"Read-only closest-reference orientation over the entire 360-degree orbit: `{json.dumps(orbit['closest_reference'])}`. Equivalent authored scalars inside current UI range: {orbit.get('closest_reference_equivalent_scalars_within_ui_range')}. This is a geometric minimum, not a new limit or an executed pose.",
            f"Independent geometric wrist bend (elbow-to-wrist versus wrist-to-Index1/Pinky1 midpoint): baseline {case['baseline_geometric_wrist_bend_deg']:.6f} degrees. Rotating the captured finger-root direction into the neutral Hand reference gives {case['neutral_reference_geometric_wrist_bend_deg']:.6f} degrees. Minimum geometric bend anywhere on this orbit: `{json.dumps(orbit['geometric_straightest'])}`. Geometric straightness does not certify palm facing or anatomical feasibility.",
            f"A +5-degree move improves reference distance: {orbit['positive_5deg_improves_reference_distance']}; a -5-degree move improves it: {orbit['negative_5deg_improves_reference_distance']}.",
            f"Max actual-versus-authored orbit quaternion error: {case['maximum_actual_vs_authored_orbit_error_deg']:.6f} degrees. Wrist position error: {case['maximum_wrist_position_error_m']:.9f} m; Tip error: {case['maximum_tip_position_error_m']:.9f} m; rigid grip position error: {case['maximum_rigid_grip_position_error_m']:.9f} m; rigid grip angle error: {case['maximum_rigid_grip_angle_error_deg']:.6f} degrees.",
            f"Non-Hand local rotation maximum: {case['maximum_non_hand_local_rotation_deg']:.6f} degrees; translation maximum: {case['maximum_non_hand_local_translation_m']:.9f} m.",
            f"Gated/mismatched requests: `{json.dumps(case['gated_requests'])}`.", '',
            '| Step | Phase | Requested | Authored | Rendered signed | Neutral distance | Forearm twist | Swing | Geometric wrist bend | Raw requested geometry distance |',
            '| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'])
        for row in case['measurements']:
            raw = row['unclamped_requested_geometry']
            values = [row['step'], row['phase'], row['requested_deg'], row['authored_deg'], row['rendered_signed_roll_deg'], row['actual']['reference_distance_deg'], row['actual']['forearm_twist_deg'], row['actual']['swing_deg'], row['actual']['geometric_wrist_bend_deg'], raw['reference_distance_deg'] if raw else None]
            lines.append('| ' + ' | '.join(f'{v:.6f}' if isinstance(v, float) else str(v) for v in values) + ' |')
        lines.append('')
    (directory / 'WEAPON_ROLL_ANALYSIS.md').write_text('\n'.join(lines), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    result = analyze(args.directory)
    write_report(args.directory, result)
    print(f"{len(result['cases'])} non-warmup cases; manifest_complete={result['manifest_complete']}; {args.directory / 'WEAPON_ROLL_ANALYSIS.md'}")
