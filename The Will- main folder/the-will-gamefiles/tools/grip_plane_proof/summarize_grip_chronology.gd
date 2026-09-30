extends SceneTree

## Offline summary; never loads a character or runs grip acquisition.
## --script res://tools/grip_plane_proof/summarize_grip_chronology.gd -- --trace C:/WORKSPACE/...jsonl

const SCHEMA := "the_will_grip_chronology"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = OS.get_environment("THE_WILL_GRIP_SUMMARY_PATH")
	for index: int in args.size():
		if args[index] == "--trace" and index + 1 < args.size():
			path = args[index + 1]
	path = path.replace("\\", "/").simplify_path()
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/") or path.get_extension().to_lower() != "jsonl":
		push_error("Pass --trace or THE_WILL_GRIP_SUMMARY_PATH with an absolute C:/WORKSPACE .jsonl path.")
		quit(1)
		return
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		push_error("Cannot read chronology: " + error_string(FileAccess.get_open_error()))
		quit(1)
		return
	var records: Array = []
	var issues: Array = []
	var line_number := 0
	while not source.eof_reached():
		var line: String = source.get_line()
		line_number += 1
		if line.strip_edges().is_empty():
			continue
		var parser := JSON.new()
		if parser.parse(line) != OK or not parser.data is Dictionary:
			issues.append({"line": line_number, "issue": "Malformed/incomplete JSON line"})
			continue
		var record: Dictionary = parser.data
		if int(record.get("schema_version", 0)) != 1 or not record.has_all(["sequence", "t_us", "kind", "span_id", "name", "data"]):
			issues.append({"line": line_number, "issue": "Unsupported or incomplete record"})
			continue
		records.append(record)
	source.close()
	if records.is_empty():
		push_error("No valid chronology records: " + path)
		quit(1)
		return
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.sequence) < int(b.sequence) if int(a.t_us) == int(b.t_us) else int(a.t_us) < int(b.t_us))
	var summary: Dictionary = _summarize(path, records, issues)
	var stem: String = path.get_basename()
	var output := FileAccess.open(stem + ".summary.json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write chronology summary JSON.")
		quit(1)
		return
	output.store_string(JSON.stringify(summary, "\t"))
	output.close()
	output = FileAccess.open(stem + ".html", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write chronology HTML.")
		quit(1)
		return
	output.store_string(_html(summary))
	output.close()
	print(JSON.stringify({"summary": stem + ".summary.json", "html": stem + ".html", "records": records.size(), "unclosed_spans": summary.unclosed_spans.size(), "issues": issues.size(), "trace_closed": summary.trace_closed}))
	quit(0)


func _summarize(path: String, records: Array, issues: Array) -> Dictionary:
	var stages: Dictionary = {}
	var open_spans: Dictionary = {}
	var unclosed: Array = []
	var start: Dictionary = {}
	var closed := false
	var max_open := 0
	var observed_end: int = int(records.back().t_us)
	for record: Dictionary in records:
		var name: String = str(record.name)
		var kind: String = str(record.kind)
		var span_id: int = int(record.span_id)
		if not stages.has(name):
			stages[name] = {"name": name, "begins": 0, "ends": 0, "events": 0, "paired": 0, "unclosed": 0, "total_us": 0, "min_us": -1, "max_us": 0, "average_ms": 0.0, "total_ms": 0.0, "main_thread_records": 0, "worker_records": 0, "outcomes": {}, "work_totals": {}, "_durations": []}
		var stage: Dictionary = stages[name]
		if bool(record.get("is_main_thread", true)):
			stage.main_thread_records += 1
		else:
			stage.worker_records += 1
		if kind == "begin":
			stage.begins += 1
			if open_spans.has(span_id):
				issues.append({"sequence": record.sequence, "issue": "Duplicate open span", "span_id": span_id})
			open_spans[span_id] = record
		elif kind == "end":
			stage.ends += 1
			if open_spans.has(span_id):
				var opening: Dictionary = open_spans[span_id]
				if opening.name != name:
					issues.append({"sequence": record.sequence, "issue": "Span name mismatch", "span_id": span_id})
				var duration: int = int(record.get("duration_us", int(record.t_us) - int(opening.t_us)))
				stage.paired += 1
				stage.total_us += duration
				stage.min_us = duration if int(stage.min_us) < 0 else mini(int(stage.min_us), duration)
				stage.max_us = maxi(int(stage.max_us), duration)
				stage._durations.append(duration)
				open_spans.erase(span_id)
			else:
				issues.append({"sequence": record.sequence, "issue": "End has no recorded start", "span_id": span_id})
		else:
			stage.events += 1
		max_open = maxi(max_open, open_spans.size())
		record["open_spans_after"] = open_spans.size()
		var data: Dictionary = record.data if record.data is Dictionary else {}
		if name == "trace.started":
			start = data
		elif name == "trace.closed":
			closed = true
		for outcome_key: String in ["outcome", "status", "ok", "reason", "valid", "termination", "improved", "classification", "cache_hit"]:
			if data.has(outcome_key):
				var outcome: String = outcome_key + "=" + str(data[outcome_key])
				stage.outcomes[outcome] = int(stage.outcomes.get(outcome, 0)) + 1
		var work_counts: Variant = data.get("work_counts", {})
		if work_counts is Dictionary:
			for work_key: Variant in work_counts:
				var count: Variant = work_counts[work_key]
				if typeof(count) == TYPE_INT or typeof(count) == TYPE_FLOAT:
					stage.work_totals[str(work_key)] = stage.work_totals.get(str(work_key), 0) + count
	for span_id: int in open_spans:
		var record: Dictionary = open_spans[span_id]
		stages[str(record.name)].unclosed += 1
		unclosed.append({"span_id": span_id, "name": record.name, "began_ms": float(record.t_us) / 1000.0, "observed_open_ms": float(observed_end - int(record.t_us)) / 1000.0, "is_main_thread": record.get("is_main_thread", true), "data": record.data, "outcome": "unfinished; elapsed is a lower bound at last recorded event"})
	unclosed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.began_ms) < float(b.began_ms))
	var stage_list: Array = []
	for stage: Dictionary in stages.values():
		stage.total_ms = float(stage.total_us) / 1000.0
		stage.average_ms = float(stage.total_ms) / float(stage.paired) if int(stage.paired) > 0 else 0.0
		stage.min_ms = float(stage.min_us) / 1000.0 if int(stage.min_us) >= 0 else null
		stage.max_ms = float(stage.max_us) / 1000.0 if int(stage.paired) > 0 else null
		stage._durations.sort()
		stage.p95_ms = float(stage._durations[maxi(0, ceili(stage._durations.size() * 0.95) - 1)]) / 1000.0 if not stage._durations.is_empty() else null
		stage.erase("_durations")
		stage_list.append(stage)
	stage_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.total_ms) > float(b.total_ms))
	if start.get("schema", "") != SCHEMA:
		issues.append({"issue": "Missing or unrecognized trace.started schema"})
	return {"schema": "the_will_grip_chronology_summary", "version": 1, "source": path,
		"trace_start": start, "trace_closed": closed, "record_count": records.size(),
		"observed_span_ms": float(observed_end - int(records.front().t_us)) / 1000.0,
		"max_open_spans": max_open, "unclosed_spans": unclosed, "issues": issues,
		"interpretation": "Trace closure is not grip success. Unclosed spans are unfinished, not failures or successes. Stage durations include children and may overlap across workers. Do not sum them as elapsed time. Open span counts include nesting, not just parallel workers.",
		"stages": stage_list, "chronology": records}


func _html(summary: Dictionary) -> String:
	var encoded: String = JSON.stringify(summary).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
	return """<!doctype html><html lang="en"><meta charset="utf-8"><title>Grip chronology</title>
<style>body{font:14px system-ui,sans-serif;margin:24px;color:#152333;background:#f4f6f8}h1,h2{margin-bottom:8px}p{max-width:1100px}table{border-collapse:collapse;background:white;width:100%;margin-top:12px}td,th{border:1px solid #ced5dd;padding:6px;text-align:left;vertical-align:top}th{background:#e5ebf1;cursor:pointer;position:sticky;top:0}td.number{white-space:nowrap;text-align:right}.warn{background:#fff2cf;padding:12px}.mono{font-family:monospace;overflow-wrap:anywhere}input,select,button{font:inherit;padding:6px;margin-right:8px}details{margin-top:14px}.scroll{overflow:auto;max-height:70vh}.note{color:#526171}#counts{padding:10px 0}</style>
<h1>Grip process chronology</h1><div id="intro"></div>
<h2>Stage durations and repeated cycles</h2><p class="note">Click a column to sort. Durations are inclusive: nested operations and worker activity overlap. The total column is accumulated work for that named stage, not overall elapsed time. Counted outcomes are the recorded observations, not inferred success.</p>
<div class="scroll"><table id="stages"></table></div>
<h2>Unfinished spans</h2><p class="note">A missing end record means the operation was still open at the last recorded evidence. It does not identify whether the cause was a hang, cancellation, crash, early capture stop, or missing instrumentation.</p><div id="unfinished"></div>
<h2>Chronological events</h2><input id="filter" placeholder="Filter name or data" size="38"><select id="kind"><option value="">All event types</option><option>begin</option><option>end</option><option>event</option></select><select id="thread"><option value="">Main + worker</option><option value="main">Main thread</option><option value="worker">Worker</option></select><button id="prev">Previous</button><button id="next">Next</button><span id="counts"></span>
<p class="note">Elapsed milliseconds use the monotonic clock. Open spans include nesting and cannot be read as a count of worker threads. The recording contains no skin or weapon geometry.</p><div class="scroll"><table id="events"></table></div><details><summary>Parsing and pairing issues</summary><pre id="issues"></pre></details>
<script id="source" type="application/json">""" + encoded + """</script><script>
const data=JSON.parse(document.getElementById('source').textContent), esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])), ms=v=>v==null?'—':Number(v).toFixed(3);
document.getElementById('intro').innerHTML='<p class="mono">'+esc(data.source)+'</p><p>Started UTC: '+esc(data.trace_start.started_utc||'unknown')+' · Observed: <b>'+ms(data.observed_span_ms)+' ms</b> · Records: '+data.record_count+' · Maximum simultaneously open spans (including nested): '+data.max_open_spans+'</p><p class="warn">'+(data.trace_closed?'Recorder closed. This does not assert a successful grip.':'No trace.closed event: partial capture or interrupted process.')+' '+esc(data.interpretation)+'</p>';
function table(id,columns,rows){const el=document.getElementById(id);el.innerHTML='<thead><tr>'+columns.map(c=>'<th>'+esc(c[0])+'</th>').join('')+'</tr></thead><tbody>'+rows.map(r=>'<tr>'+columns.map(c=>'<td'+(c[2]?' class="number"':'')+'>'+esc(c[1](r))+'</td>').join('')+'</tr>').join('')+'</tbody>';el.querySelectorAll('th').forEach((th,i)=>th.onclick=()=>{const dir=th.dataset.order==='asc'?-1:1; rows.sort((a,b)=>{const x=columns[i][1](a),y=columns[i][1](b);return dir*(columns[i][2]?(parseFloat(x)||0)-(parseFloat(y)||0):String(x).localeCompare(String(y)))});table(id,columns,rows);el.querySelectorAll('th')[i].dataset.order=dir===1?'asc':'desc'})}
table('stages',[['Stage',r=>r.name],['Begins',r=>r.begins,1],['Ends',r=>r.ends,1],['Paired',r=>r.paired,1],['Events',r=>r.events,1],['Open',r=>r.unclosed,1],['Average ms',r=>ms(r.average_ms),1],['Max ms',r=>ms(r.max_ms),1],['P95 ms',r=>ms(r.p95_ms),1],['Total inclusive ms',r=>ms(r.total_ms),1],['Main / worker records',r=>r.main_thread_records+' / '+r.worker_records],['Outcomes',r=>JSON.stringify(r.outcomes)],['Work totals',r=>JSON.stringify(r.work_totals)]],data.stages.slice());
document.getElementById('unfinished').innerHTML=data.unclosed_spans.length?'<table id="open"></table>':'<p>No unclosed spans in recorded evidence.</p>';
if(data.unclosed_spans.length)table('open',[['Span',r=>r.span_id,1],['Stage',r=>r.name],['Start ms',r=>ms(r.began_ms),1],['Observed open ms (lower bound)',r=>ms(r.observed_open_ms),1],['Thread',r=>r.is_main_thread?'main':'worker'],['Start data',r=>JSON.stringify(r.data)]],data.unclosed_spans.slice());
document.getElementById('issues').textContent=JSON.stringify(data.issues,null,2);
let page=0;const size=300;function render(){const search=document.getElementById('filter').value.toLowerCase(),kind=document.getElementById('kind').value,thread=document.getElementById('thread').value;const rows=data.chronology.filter(r=>(!kind||r.kind===kind)&&(!thread||(r.is_main_thread?'main':'worker')===thread)&&(!search||(r.name+' '+JSON.stringify(r.data)).toLowerCase().includes(search)));page=Math.max(0,Math.min(page,Math.ceil(rows.length/size)-1));document.getElementById('counts').textContent=rows.length+' matching; page '+(page+1)+' / '+Math.max(1,Math.ceil(rows.length/size));table('events',[['Sequence',r=>r.sequence,1],['Elapsed ms',r=>ms(r.t_us/1000),1],['Kind',r=>r.kind],['Span',r=>r.span_id,1],['Stage',r=>r.name],['Thread',r=>r.is_main_thread?'main':'worker'],['Duration ms',r=>r.duration_us==null?'—':ms(r.duration_us/1000),1],['Open after',r=>r.open_spans_after,1],['Data',r=>JSON.stringify(r.data)]],rows.slice(page*size,(page+1)*size));}
['filter','kind','thread'].forEach(id=>document.getElementById(id).addEventListener('input',()=>{page=0;render()}));document.getElementById('prev').onclick=()=>{page--;render()};document.getElementById('next').onclick=()=>{page++;render()};render();
</script></html>"""
