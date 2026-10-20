"""Review completed --use-live-limits captures without altering their evidence.

Raw fixture failures stay failures. A separate display-rounding observation never
changes the original run verdict. Images are referenced directly, not modified.
"""
import argparse
from collections import Counter
import html
import json
import math
from pathlib import Path
from urllib.parse import quote

from analyze_skill_crafter_weapon_roll import normalized, q_angle, q_axis, q_mul, q_rotate, sub


DISPLAY_TOLERANCE = 0.50001


def distance(a, b):
    return math.sqrt(sum((x-y)**2 for x, y in zip(a, b)))


def greatest(values):
    return max((v for v in values if isinstance(v, (int, float))), default=None)


def analyze_case(declared, rows):
    name = declared['case']
    limits = declared.get('live_limits_initial', {})
    if not rows or not limits.get('available'):
        return {'case': name, 'warmup_only': declared.get('warmup_only', False),
                'complete': False, 'reason': 'Missing samples or initial live interval',
                'raw_manifest': declared}
    baseline = next((r for r in rows if r['phase'] == 'live_original_before_roll'), rows[0])
    origin = baseline['hand_world']['origin']
    axis = normalized(sub(baseline['tip_world'], origin))
    initial_scalar = baseline['authored_roll_degrees']
    measurements = []
    for row in rows:
        live = row.get('live_roll_checks', {})
        checks = live.get('checks', {})
        fields = live.get('fields', {})
        expected = live.get('expected_bounded_request_degrees')
        display_delta = abs(fields['value'] - row['authored_roll_degrees']) if 'value' in fields else None
        false_checks = [key for key, passed in checks.items() if passed is False]
        # Independent baseline-axis reconstruction. This does not use either
        # current authored value or the driver's expected output transform.
        expected_q = q_axis(axis, expected-initial_scalar) if expected is not None else None
        hand_error = q_angle(row['hand_world']['quaternion'], q_mul(expected_q, baseline['hand_world']['quaternion'])) if expected_q else None
        weapon_error = q_angle(row['weapon_world']['quaternion'], q_mul(expected_q, baseline['weapon_world']['quaternion'])) if expected_q else None
        weapon_position_error = None
        if expected_q:
            offset = q_rotate(expected_q, sub(baseline['weapon_world']['origin'], origin))
            weapon_position_error = distance(row['weapon_world']['origin'], [x+y for x, y in zip(origin, offset)])
        non_hand_errors = [q_angle(state['local_quaternion'], baseline['bones'][bone]['local_quaternion'])
                           for bone, state in row.get('bones', {}).items()
                           if bone in baseline.get('bones', {}) and not bone.endswith('_Hand')]
        measurements.append({
            'step': row['step'], 'phase': row['phase'],
            'requested_degrees': row['requested_roll_degrees'],
            'expected_degrees': expected, 'authored_degrees': row['authored_roll_degrees'],
            'authored_error_degrees': abs(row['authored_roll_degrees'] - expected) if expected is not None else None,
            'raw_passed': live.get('passed'), 'raw_false_checks': false_checks,
            'display_value_degrees': fields.get('value'), 'display_error_degrees': display_delta,
            'recorded_display_tolerance_degrees': fields.get('display_tolerance_degrees'),
            'rounded_display_within_half_degree': display_delta is not None and display_delta <= DISPLAY_TOLERANCE,
            'independent_hand_error_degrees': hand_error,
            'independent_weapon_error_degrees': weapon_error,
            'independent_weapon_position_error_m': weapon_position_error,
            'after_images_pose_errors': live.get('after_images_pose_errors', {}),
            'wrist_position_error_m': row.get('wrist_position_error_m'),
            'tip_position_error_m': row.get('tip_position_error_m'),
            'rigid_grip_position_error_m': row.get('rigid_grip_position_error_m'),
            'raw_rigid_grip_angle_error_degrees': row.get('rigid_grip_angle_error_degrees'),
            'raw_non_hand_rotation_degrees': row.get('non_hand_max_local_rotation_degrees'),
            'independent_non_hand_rotation_degrees': greatest(non_hand_errors),
            'non_hand_translation_m': row.get('non_hand_max_local_translation_m'),
            'ready': row.get('prepared_grip_readiness', {}).get('ready'),
            'current_limits': live.get('current_limits', {}),
            'retained_roll_matches': row.get('retained_roll_matches'),
            'image': row.get('image'), 'wrist_image': row.get('wrist_image'),
        })
    false_counts = Counter(key for r in measurements for key in r['raw_false_checks'])
    manifest_failures = declared.get('live_failures', [])
    original_refresh = declared.get('original_fields_refresh', {})
    raw_pass = (declared.get('live_checks_passed') is True
                and all(r['raw_passed'] is True for r in measurements)
                and not manifest_failures and not declared.get('pointer_failures')
                and len(rows) == declared.get('samples') and declared.get('complete') is True)
    result = {
        'case': name, 'warmup_only': declared.get('warmup_only', False),
        'hand_pass': declared.get('hand_pass'), 'elevation_degrees': declared.get('elevation_degrees'),
        'complete': declared.get('complete'), 'samples': len(rows), 'declared_samples': declared.get('samples'),
        'limits': limits, 'span_degrees': limits['maximum_degrees'] - limits['minimum_degrees'],
        'ready_count': sum(r['ready'] is True for r in measurements),
        'raw_manifest_checks_passed': declared.get('live_checks_passed'), 'raw_run_passed': raw_pass,
        'raw_false_checks': dict(false_counts), 'raw_manifest_failures': manifest_failures,
        'raw_non_display_false_checks': {k: v for k, v in false_counts.items() if k != 'fields_do_not_clamp_scalar'},
        'pointer_failures': declared.get('pointer_failures', []),
        'original_fields_refresh': original_refresh,
        'display_rounding_observation': {
            'tolerance_degrees': DISPLAY_TOLERANCE,
            'rows_with_recorded_tolerance': sum(r['recorded_display_tolerance_degrees'] is not None for r in measurements),
            'within_half_degree_count': sum(r['rounded_display_within_half_degree'] for r in measurements),
            'raw_display_failures_within_half_degree': sum('fields_do_not_clamp_scalar' in r['raw_false_checks'] and r['rounded_display_within_half_degree'] for r in measurements),
            'maximum_difference_degrees': greatest(r['display_error_degrees'] for r in measurements),
            'note': 'Separate offline observation only; original false checks and raw verdict are unchanged.',
        },
        'maximum_errors': {}, 'measurements': measurements,
    }
    for field in ['authored_error_degrees', 'independent_hand_error_degrees', 'independent_weapon_error_degrees',
                  'independent_weapon_position_error_m', 'wrist_position_error_m', 'tip_position_error_m',
                  'rigid_grip_position_error_m', 'raw_rigid_grip_angle_error_degrees', 'raw_non_hand_rotation_degrees',
                  'independent_non_hand_rotation_degrees', 'non_hand_translation_m']:
        result['maximum_errors'][field] = greatest(r[field] for r in measurements)
    for field in ['hand_position_error_m', 'weapon_position_error_m', 'hand_angle_error_degrees', 'weapon_angle_error_degrees']:
        result['maximum_errors']['after_images_' + field] = greatest(r['after_images_pose_errors'].get(field) for r in measurements)
    result['maximum_interval_drift_degrees'] = greatest(abs(r['current_limits'][k] - limits[k])
        for r in measurements for k in ['minimum_degrees', 'maximum_degrees', 'center_degrees'] if k in r['current_limits'])
    return result


def analyze(directory):
    manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8-sig'))
    if manifest.get('complete') is not True:
        raise ValueError('Manifest is not complete; do not analyze a run while it is writing.')
    rows = [json.loads(line) for line in (directory / 'samples.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    cases = [analyze_case(c, [r for r in rows if r['case'] == c['case']]) for c in manifest['cases']]
    acceptance = [c for c in cases if not c['warmup_only']]
    return {'directory': str(directory), 'manifest_complete': True, 'sample_count': len(rows),
            'declared_sample_count': manifest.get('sample_count'), 'options': manifest.get('options'),
            'scope': 'Observed range enforcement and pose preservation. This does not certify anatomical comfort at every angle. R1 warmup is separate from L/R2 acceptance. Raw failures remain failures.',
            'raw_acceptance_cases_all_passed': bool(acceptance) and all(c.get('raw_run_passed') is True for c in acceptance),
            'cases': cases}


def markdown(report):
    lines = ['# Weapon Roll live-limit review', '', report['scope'], '',
             f"Source: `{report['directory']}`. Complete manifest; {report['sample_count']}/{report['declared_sample_count']} rows.",
             f"**Raw L/R2 acceptance verdict: {'PASS' if report['raw_acceptance_cases_all_passed'] else 'NOT ALL PASS'}.**", '',
             'Whole-degree display differences are evaluated separately at ≤0.50001°. This never rewrites the raw fixture result.', '']
    for warmup in [False, True]:
        lines += ['## ' + ('R1 warmup — excluded from acceptance' if warmup else 'L/R2 acceptance cases'), '']
        for c in report['cases']:
            if c['warmup_only'] != warmup:
                continue
            lines += [f"### {c['case']}", '']
            if 'measurements' not in c:
                lines += [f"Incomplete: {c['reason']}", '']; continue
            limits, errors, rounding = c['limits'], c['maximum_errors'], c['display_rounding_observation']
            lines += [f"**Raw result: {'PASS' if c['raw_run_passed'] else 'FAIL / incomplete checks'}**; ready {c['ready_count']}/{c['samples']}; samples {c['samples']}/{c['declared_samples']}.",
                f"Limits {limits['minimum_degrees']:.6f}° to {limits['maximum_degrees']:.6f}°; center {limits['center_degrees']:.6f}°; span {c['span_degrees']:.6f}°. Maximum interval drift {c['maximum_interval_drift_degrees']:.9f}°.",
                f"Original field refresh preserved pose and authored data: {c['original_fields_refresh'].get('preserved')}. Changed bones: {c['original_fields_refresh'].get('changed_bone_indices')}. Pointer failures: `{json.dumps(c['pointer_failures'])}`.",
                f"Raw named false checks: `{json.dumps(c['raw_false_checks'])}`. Non-display false checks: `{json.dumps(c['raw_non_display_false_checks'])}`.",
                f"Separate rounding observation: {rounding['within_half_degree_count']}/{c['samples']} rows differ by ≤0.50001°; maximum {rounding['maximum_difference_degrees']:.6f}°. {rounding['raw_display_failures_within_half_degree']} raw display failures fall within that rounding allowance. Recorded tolerance metadata exists in {rounding['rows_with_recorded_tolerance']}/{c['samples']} rows; absent metadata does not imply the newer fixture ran.",
                f"Maximum expected/authored error {errors['authored_error_degrees']:.9f}°. Independently reconstructed Hand/weapon angle errors {errors['independent_hand_error_degrees']:.9f}° / {errors['independent_weapon_error_degrees']:.9f}°.",
                f"Maximum wrist/Tip/rigid-grip displacement {errors['wrist_position_error_m']*1000:.9f} / {errors['tip_position_error_m']*1000:.9f} / {errors['rigid_grip_position_error_m']*1000:.9f} mm. Independent non-Hand local rotation error {errors['independent_non_hand_rotation_degrees']:.9f}°; raw engine angle metric {errors['raw_non_hand_rotation_degrees']:.9f}°; local translation {errors['non_hand_translation_m']*1000:.9f} mm.",
                f"After-image Hand/weapon error maxima: {errors['after_images_hand_angle_error_degrees']:.9f}° / {errors['after_images_weapon_angle_error_degrees']:.9f}°; position {errors['after_images_hand_position_error_m']*1000:.9f} / {errors['after_images_weapon_position_error_m']*1000:.9f} mm.", '',
                '| Step | Phase | Requested ° | Expected ° | Authored ° | Display difference ° | Raw false checks |',
                '| ---: | --- | ---: | ---: | ---: | ---: | --- |']
            for r in c['measurements']:
                lines.append(f"| {r['step']} | {r['phase']} | {r['requested_degrees']:.6f} | {r['expected_degrees']:.6f} | {r['authored_degrees']:.6f} | {r['display_error_degrees']:.6f} | {', '.join(r['raw_false_checks']) or '—'} |")
            lines += ['', 'Raw manifest failures (retained):', '', '```json', json.dumps(c['raw_manifest_failures'], indent=2), '```', '']
    return '\n'.join(lines)


def write_html(directory, report):
    parts = ['<!doctype html><html lang="en"><meta charset="utf-8"><title>Weapon Roll limits review</title>',
             '<style>body{background:#181c22;color:#e7e9ed;font:16px system-ui;margin:2rem auto;max-width:1400px;padding:0 1rem}h1,h2,h3{color:#fafafa}a{color:#83cafa}section{border:1px solid #53616d;border-radius:8px;padding:1rem;margin:1rem 0}.warning{color:#ffca78}.ok{color:#8fe1ad}table{border-collapse:collapse;width:100%;margin:1rem 0}td,th{border-bottom:1px solid #46505c;padding:.5rem;text-align:left}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}.gallery img{width:100%}figure{margin:0}figcaption{font-size:14px}button{background:#344458;color:white;border:1px solid #758599;padding:.5rem;cursor:pointer}.viewer{display:grid;grid-template-columns:1fr 1fr;gap:10px}.viewer img{width:100%;max-height:650px;object-fit:contain;background:#101317}input[type=range]{width:100%}pre{white-space:pre-wrap;font-size:13px}@media(max-width:800px){.viewer{grid-template-columns:1fr}}</style>',
             '<h1>Weapon Roll limits — rendered evidence</h1>',
             f"<p>{html.escape(report['scope'])}</p><p>Raw L/R2 acceptance: <strong class='{('ok' if report['raw_acceptance_cases_all_passed'] else 'warning')}'>{'PASS' if report['raw_acceptance_cases_all_passed'] else 'NOT ALL PASS'}</strong>. Display rounding observations never replace that verdict.</p>",
             '<p><a href="WEAPON_ROLL_LIMITS_REVIEW.md">Detailed report and raw false checks</a> · <a href="weapon_roll_limits_review.json">Analysis data</a></p>']
    gallery_data = []
    for index, c in enumerate(sorted(report['cases'], key=lambda c: c['warmup_only'])):
        parts.append(f"<section><h2>{html.escape(c['case'])}</h2><p>{'WARMUP ONLY — excluded from acceptance' if c['warmup_only'] else 'L/R2 acceptance case'}</p>")
        if 'measurements' not in c:
            parts.append(f"<p>{html.escape(c['reason'])}</p></section>")
            gallery_data.append([])
            continue
        lim, rnd, err = c['limits'], c['display_rounding_observation'], c['maximum_errors']
        parts += [f"<p><strong class='{('ok' if c['raw_run_passed'] else 'warning')}'>RAW {'PASS' if c['raw_run_passed'] else 'FAIL'}</strong> · ready {c['ready_count']}/{c['samples']} · range {lim['minimum_degrees']:.3f}° to {lim['maximum_degrees']:.3f}° · center {lim['center_degrees']:.3f}° · span {c['span_degrees']:.3f}°</p>",
                  f"<p>Original field refresh preserved: {c['original_fields_refresh'].get('preserved')}. Pointer failures: {html.escape(json.dumps(c['pointer_failures']))}. Raw false checks: {html.escape(json.dumps(c['raw_false_checks']))}.</p>",
                  f"<p>Separate rounded-display observation: {rnd['within_half_degree_count']}/{c['samples']} within ±0.50001°; max difference {rnd['maximum_difference_degrees']:.6f}°. Authored error max {err['authored_error_degrees']:.9f}°. Independent rendered Hand/weapon errors {err['independent_hand_error_degrees']:.7f}° / {err['independent_weapon_error_degrees']:.7f}°.</p>"]
        pictures = [r for r in c['measurements'] if r.get('image') or r.get('wrist_image')]
        selected = []
        for label, predicate in [
            ('Original', lambda r: r['phase'] == 'live_original_before_roll'),
            ('Center', lambda r: r['phase'] == 'live_center'),
            ('First maximum', lambda r: abs(r['authored_degrees'] - lim['maximum_degrees']) < 0.01),
            ('First minimum', lambda r: abs(r['authored_degrees'] - lim['minimum_degrees']) < 0.01),
            ('Final refresh', lambda r: r['phase'] == 'live_final_refresh')]:
            found = next((r for r in pictures if predicate(r)), None)
            if found: selected.append((label, pictures.index(found), found))
        parts.append('<div class="gallery">')
        for label, pic_index, row in selected:
            source = quote(Path(row.get('wrist_image') or row['image']).name)
            parts.append(f'<figure><button onclick="selectFrame({index},{pic_index})">{html.escape(label)}</button><a href="{source}"><img loading="lazy" src="{source}" alt="{html.escape(label)}"></a><figcaption>Actual authored {row["authored_degrees"]:.3f}° · step {row["step"]}</figcaption></figure>')
        parts += ['</div>', f'<h3 id="label{index}"></h3><input id="slider{index}" type="range" min="0" max="{max(0,len(pictures)-1)}" value="0" oninput="selectFrame({index},Number(this.value))"><div class="viewer"><img id="full{index}" alt="Full scene"><img id="wrist{index}" alt="Wrist close-up"></div></section>']
        gallery_data.append([{'step': r['step'], 'phase': r['phase'], 'authored': r['authored_degrees'], 'requested': r['requested_degrees'], 'full': quote(Path(r['image']).name) if r.get('image') else '', 'wrist': quote(Path(r['wrist_image']).name) if r.get('wrist_image') else ''} for r in pictures])
    payload = json.dumps(gallery_data).replace('<', '\\u003c')
    parts += [f'<script>const cases={payload};function selectFrame(c,i){{const r=cases[c][i];if(!r)return;document.getElementById("slider"+c).value=i;document.getElementById("label"+c).textContent=`Step ${{r.step}} · ${{r.phase}} · actual authored ${{r.authored.toFixed(3)}}° · requested ${{r.requested.toFixed(3)}}°`;document.getElementById("full"+c).src=r.full;document.getElementById("wrist"+c).src=r.wrist;}}cases.forEach((_,i)=>selectFrame(i,0));</script></html>']
    (directory / 'review.html').write_text('\n'.join(parts), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    result = analyze(args.directory)
    (args.directory / 'WEAPON_ROLL_LIMITS_REVIEW.md').write_text(markdown(result), encoding='utf-8')
    (args.directory / 'weapon_roll_limits_review.json').write_text(json.dumps(result, indent=2, allow_nan=False), encoding='utf-8')
    write_html(args.directory, result)
    print(json.dumps({'cases': len(result['cases']), 'samples': result['sample_count'],
                      'raw_acceptance_cases_all_passed': result['raw_acceptance_cases_all_passed'],
                      'review': str(args.directory / 'review.html')}))
