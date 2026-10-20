"""Offline review of diagnose_skill_crafter_body_motion.gd output; no pass certificate."""
import argparse
import collections
import html
import json
import math
from pathlib import Path
from urllib.parse import quote


def vector(value, size):
    return isinstance(value, list) and len(value) == size and all(isinstance(x, (int, float)) and math.isfinite(x) for x in value)


def separation(a, b):
    return math.dist(a, b) if vector(a, 3) and vector(b, 3) else None


def angle(a, b, quaternion=False):
    size = 4 if quaternion else 3
    if not vector(a, size) or not vector(b, size):
        return None
    denominator = math.hypot(*a) * math.hypot(*b)
    if denominator < 1e-12:
        return None
    cosine = sum(x * y for x, y in zip(a, b)) / denominator
    return math.degrees(math.acos(max(-1, min(1, abs(cosine) if quaternion else cosine)))) * (2 if quaternion else 1)


def bone_steps(before, after):
    return {name: {space: angle(before[name].get(space + "_quaternion"), after[name].get(space + "_quaternion"), True)
                   for space in ("local", "world")} for name in before.keys() & after.keys()}


def peak(values):
    valid = [value for value in values if value is not None]
    return max(valid) if valid else None


def maximum_step(bones, space="local"):
    return peak(item[space] for item in bones.values())


def plane_valid(row):
    degrees = row.get("elbow_inner_angle_degrees")
    return isinstance(degrees, (int, float)) and row.get("elbow_plane_cross_length", 0) > 1e-8 and abs(math.sin(math.radians(degrees))) > 0.001


def analyze(directory):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8-sig"))
    groups, warnings = [], []
    with (directory / "samples.jsonl").open(encoding="utf-8-sig") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
                if not isinstance(row, dict):
                    raise ValueError("sample is not an object")
            except (ValueError, json.JSONDecodeError) as error:
                warnings.append(f"Unreadable sample line {line_number}: {error}")
                continue
            if not groups or row.get("case") != groups[-1][-1].get("case") or row.get("step", 0) <= groups[-1][-1].get("step", -1):
                groups.append([])
            groups[-1].append(row)
    declared = manifest.get("cases", [])
    labels = [case.get("case", "unknown") for case in declared]
    if len(set(labels)) != len(labels):
        warnings.append("Duplicate case labels: samples are split by step reset; screenshot files may have been overwritten.")
    cases = []
    for index in range(max(len(groups), len(declared))):
        rows = groups[index] if index < len(groups) else []
        spec = declared[index] if index < len(declared) else {}
        name = rows[0].get("case", "unknown") if rows else spec.get("case", "unknown")
        expected = spec.get("expected_samples")
        if not isinstance(expected, int):
            steps = spec.get("steps_each_way")
            expected = steps * 2 + 1 if isinstance(steps, int) else None
        requested_elevation, accepted_axis = spec.get("requested_elevation_degrees"), spec.get("accepted_axis_world")
        actual_elevation = math.degrees(math.asin(max(-1, min(1, accepted_axis[1])))) if vector(accepted_axis, 3) else None
        coverage_warning = "Requested elevated setup remained essentially horizontal; this is not elevated-angle coverage." if isinstance(requested_elevation, (int, float)) and actual_elevation is not None and abs(requested_elevation) >= 20 and abs(actual_elevation) < 1 else None
        samples, maxima, readiness = [], {}, collections.Counter()
        previous = None
        for row in rows:
            ready = row.get("prepared_grip_readiness", {}).get("ready")
            readiness["ready" if ready is True else "unready" if ready is False else "unknown"] += 1
            changes = bone_steps(previous.get("bones", {}), row.get("bones", {})) if previous else {}
            authority = bone_steps(row.get("bones_before_authority", {}), row.get("bones_after_authority", {}))
            refresh = bone_steps(row.get("bones_after_authority", {}), row.get("bones", {}))
            for bone, values in changes.items():
                entry = maxima.setdefault(bone, {})
                for space, value in values.items():
                    if value is not None and value > entry.get(space, {}).get("degrees", -1):
                        entry[space] = {"degrees": value, "step": row.get("step"), "serial": row.get("sample_serial")}
            image = directory / str(row.get("image", ""))
            image_url = quote(image.relative_to(directory).as_posix()) if image.suffix.lower() == ".png" and image.resolve().is_relative_to(directory) and image.is_file() else None
            samples.append({"step": row.get("step"), "serial": row.get("sample_serial"), "phase": row.get("phase"), "distance_m": row.get("distance_m"), "ready": ready,
                            "prepared_grip_readiness": {key: row.get("prepared_grip_readiness", {}).get(key) for key in ("ready", "status", "reason", "seat_status")},
                            **{key: row.get(key) for key in ("authored_upperarm_roll_degrees", "pointer_resolved_roll_degrees", "correction_fraction", "requested_step_degrees", "requested_cumulative_arc_degrees", "desired_final_normal_world", "normal_error_degrees", "authored_pommel_drift_m", "authored_tip_drift_m", "elbow_radial_world", "requested_control_normal_world")},
                            "request_gap_m": separation(row.get("requested_pommel_local"), row.get("accepted_pommel_local")),
                            "accepted_travel_m": separation(row.get("accepted_pommel_local"), rows[0].get("accepted_pommel_local")),
                            "requested_travel_m": separation(row.get("requested_pommel_local"), rows[0].get("requested_pommel_local")),
                            "authority_legal": row.get("authority", {}).get("legal"), "local_step_degrees": maximum_step(changes), "world_step_degrees": maximum_step(changes, "world"),
                            "elbow_degrees": row.get("elbow_inner_angle_degrees"), "elbow_plane_step_degrees": angle(previous.get("elbow_plane_character_space"), row.get("elbow_plane_character_space")) if previous and plane_valid(previous) and plane_valid(row) else None,
                            "adjacent_steps": changes, "authority_steps": authority, "refresh_steps": refresh, "authority_local_degrees": maximum_step(authority), "refresh_local_degrees": maximum_step(refresh), "image": image_url})
            previous = row
        complete = bool(spec.get("complete")) and expected is not None and len(rows) == expected and [row.get("step") for row in rows] == list(range(expected)) and spec.get("case") == name
        cases.append({"case": name, "complete": complete, "expected_samples": expected, "sample_count": len(rows), "readiness": dict(readiness),
                      "sequence": spec.get("sequence"), "correction_start": spec.get("correction_start"), "correction_end": spec.get("correction_end"), "movement_variant": spec.get("movement_variant"),
                      **{key: spec[key] for key in ("hand_pass", "warmup_only", "actor_instance_id", "station_instance_id", "weapon_instance_id", "correction_failure") if key in spec},
                      "setup_timing": {key: spec.get("setup_applied_grip", {}).get(key) for key in ("first_reported_ready_ms", "setup_observed_ms", "open_to_settled_ms", "continuous_stable_ms") if key in spec.get("setup_applied_grip", {})},
                      "requested_setup_elevation_degrees": requested_elevation, "actual_world_elevation_degrees": actual_elevation, "setup_axis_error_degrees": spec.get("setup_axis_error_degrees"), "coverage_warning": coverage_warning,
                      "initial_ready": spec.get("initial_applied_grip", {}).get("ready"), "setup_ready": spec.get("setup_applied_grip", spec.get("grip", {})).get("ready"), "setup_reason": spec.get("reason"),
                      "max_request_gap_m": peak(x["request_gap_m"] for x in samples), "max_requested_travel_m": peak(x["requested_travel_m"] for x in samples), "max_accepted_travel_m": peak(x["accepted_travel_m"] for x in samples),
                      "max_upperarm_rest_twist_degrees": peak(abs(b["rest_relative_local_y_twist_degrees"]) for row in rows for name, b in row.get("bones", {}).items() if name.endswith("_Upperarm") and isinstance(b.get("rest_relative_local_y_twist_degrees"), (int, float))),
                      "max_elbow_plane_step_degrees": peak(x["elbow_plane_step_degrees"] for x in samples), "max_authority_local_degrees": peak(x["authority_local_degrees"] for x in samples),
                      "max_refresh_local_degrees": peak(x["refresh_local_degrees"] for x in samples), "adjacent_bone_maxima": maxima, "samples": samples})
    return {"complete": bool(manifest.get("complete")) and bool(cases) and all(c["complete"] for c in cases) and not warnings, "assessment": "Diagnostic evidence only; completeness is not pass/fail or grip certification.",
            "weapon": manifest.get("weapon"), "manifest_complete": manifest.get("complete", False), "failure": manifest.get("failure"), "warnings": warnings,
            "plane_guard": "cross length > 1e-8 m² and abs(sin(elbow angle)) > 0.001; null means absent/degenerate", "cases": cases}


def write_review(directory, report):
    payload = json.dumps(report, ensure_ascii=True).replace("<", "\\u003c")
    title = html.escape(str(report.get("weapon") or directory.name))
    page = """<!doctype html><meta charset="utf-8"><title>Body motion review</title>
<style>body{font:15px system-ui;background:#171b22;color:#e6edf3;margin:24px}button,select{font:inherit;margin:4px;padding:6px}pre{white-space:pre-wrap}img{max-width:100%;max-height:65vh}#warning{color:#ffca80}details{margin:12px 0}a{color:#81c6ff}</style>
<h1>""" + title + """ — body motion review</h1><p id="warning"></p>
<label>Case <select id="cases"></select></label><button id="previous">Previous step</button><select id="steps"></select><button id="next">Next step</button>
<pre id="metrics"></pre><p id="missing"></p><a id="link"><img id="image" alt="Actual rendered diagnostic frame"></a>
<details><summary>Case summary and per-bone adjacent maxima</summary><pre id="summary"></pre></details>
<p><a href="analysis.json">Full analysis JSON</a> · <a href="manifest.json">Run manifest</a> · No acceptance thresholds are applied.</p>
<script>const data=""" + payload + """;
const el=id=>document.getElementById(id), cs=el('cases'), ss=el('steps');
el('warning').textContent=(data.complete?'Capture complete. ':'INCOMPLETE CAPTURE. ')+data.assessment+' '+data.warnings.join(' ')+(data.failure?' Failure: '+data.failure:'');
const hasElevation=c=>typeof c.requested_setup_elevation_degrees==='number';
data.cases.forEach((c,i)=>cs.add(new Option(c.case+(hasElevation(c)?' — REQUESTED elevation '+c.requested_setup_elevation_degrees+'°; actual '+(c.actual_world_elevation_degrees===null?'unknown':c.actual_world_elevation_degrees.toFixed(2)+'°'):'')+'; '+(c.complete?'complete':'INCOMPLETE')+'; readiness '+JSON.stringify(c.readiness),i)));
function show(){const c=data.cases[+cs.value];if(!c)return;const s=c.samples[+ss.value];const summary={...c};delete summary.samples;if(!hasElevation(c)){delete summary.requested_setup_elevation_degrees;delete summary.actual_world_elevation_degrees;delete summary.setup_axis_error_degrees;}el('summary').textContent=JSON.stringify(summary,null,2);
el('image').hidden=true;el('missing').textContent='No recorded frame for this step.';if(!s){el('metrics').textContent='No samples. See setup failure in summary.';return;}
const m={...(hasElevation(c)?{requested_setup_elevation_degrees:c.requested_setup_elevation_degrees,actual_world_elevation_degrees:c.actual_world_elevation_degrees,setup_axis_error_degrees:c.setup_axis_error_degrees}:{}),...s};delete m.adjacent_steps;delete m.authority_steps;delete m.refresh_steps;el('metrics').textContent=(c.warmup_only?'WARMUP ONLY. ':'')+(c.correction_failure?'CORRECTION NOT COMPLETED: '+c.correction_failure+'. ':'')+(s.ready===true?'Applied grip recorded.':s.ready===false?'UNREADY GRIP.':'GRIP READINESS UNKNOWN.')+' '+(c.coverage_warning||(hasElevation(c)?'Case elevation is REQUESTED; actual setup is reported below.':''))+'\\n'+JSON.stringify(m,null,2);
if(s.image){el('image').src=s.image;el('link').href=s.image;el('image').hidden=false;el('missing').textContent='';}}
function choose(){ss.replaceChildren();const c=data.cases[+cs.value];if(c)c.samples.forEach((s,i)=>ss.add(new Option('Step '+s.step+' '+s.phase+(s.image?' [image]':''),i)));show();}
cs.onchange=choose;ss.onchange=show;function move(d){ss.selectedIndex=Math.max(0,Math.min(ss.options.length-1,ss.selectedIndex+d));show();}
el('previous').onclick=()=>move(-1);el('next').onclick=()=>move(1);choose();</script>"""
    (directory / "review.html").write_text(page, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_directory", type=Path)
    directory = parser.parse_args().run_directory.resolve()
    report = analyze(directory)
    (directory / "analysis.json").write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    write_review(directory, report)
    print(f"{len(report['cases'])} cases; capture complete={report['complete']}; {directory / 'review.html'}")


if __name__ == "__main__":
    main()
