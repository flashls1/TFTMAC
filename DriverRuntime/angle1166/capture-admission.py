"""First-batch diagnostic admission; never a gameplay performance acceptance gate."""
import csv
import hashlib
import json
from pathlib import Path
import sqlite3
import sys

def trace_failure(events):
    terminal = [e for e in events if e[0] in ('DIAGNOSTIC_TRACE_COMPLETED', 'DIAGNOSTIC_TRACE_FAILED')]
    return None if terminal and terminal[-1][0] == 'DIAGNOSTIC_TRACE_COMPLETED' else 'LATEST_ARTIFACT_ATTEMPT_NOT_SEALED'

def inspect(root):
    root = Path(root).resolve()
    result = {'capture': root.name, 'scope': 'DIAGNOSTIC_ADMISSION_ONLY',
              'performance_acceptance': 'UNPROVEN', 'reasons': []}
    fail = result['reasons'].append
    try:
        db = sqlite3.connect('file:' + str(root / 'TFTMAC_NATIVE_RUNTIME.sqlite') + '?mode=ro', uri=True)
        events = [(k, json.loads(v)) for k, v in db.execute('select kind,payload_json from events order by id')]
        if db.execute('select status from sessions').fetchone() != ('STOPPED',): fail('CAPTURE_NOT_CLEANLY_FINALIZED')
        loaded = [e[1] for e in events if e[0] == 'ANGLE_DRIVER_LOADED_VERIFIED']
        report = json.loads((root / 'angle-driver-evidence.json').read_text())
        if len(loaded) != 1 or loaded[0]['pid'] != report['pid'] or not loaded[0]['inode_and_namespace_hashes_verified']:
            fail('ACTUAL_TFT_DRIVER_IDENTITY_MISSING')
        if report['producer_coverage'] != 'COMPLETE': fail('DRIVER_PRODUCER_LOSS_OR_MALFORMED_DATA')
        rows = db.execute("select count(*) from pipeline_events where component='TFT_ANGLE' and json_extract(payload_json,'$.pid')=?", (report['pid'],)).fetchone()[0]
        if rows == 0 or rows != report['sql_rows_read_back']: fail('ACTUAL_TFT_DRIVER_ROWS_MISSING')
        for source in report['sources']:
            path = (root / source['file']).resolve()
            if root not in path.parents or hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
                fail('RAW_DRIVER_IDENTITY_CHANGED')
        result['driver_summary'] = report['summary']
        native = db.execute('select count(*),min(presentation_id),max(presentation_id),sum(presented_host_time_ns>0),count(distinct case when presented_host_time_ns>0 then source_sequence end) from native_drawable_presentations').fetchone()
        result['native_callbacks'], first, last, result['actual_onscreen'], result['unique_onscreen_sources'] = native
        if not native[0] or not native[3] or not native[4]: fail('ACTUAL_NATIVE_PRESENTATION_PRODUCER_MISSING')
        if native[0] and last - first + 1 != native[0]: fail('NATIVE_CALLBACK_SEQUENCE_GAP')
        submitted, lost = db.execute('select max(last_submitted_id),coalesce(sum(lost_records),0) from native_drawable_windows').fetchone()
        result['native_tail_outstanding'] = max(0, (submitted or 0) - (last or 0))
        if lost: fail('NATIVE_RECORDER_OVERFLOW')
        # Pending tail callbacks are explicitly retained as unknown, never counted onscreen.
        result['tft_present_intervals'] = db.execute('select count(*) from game_frame_intervals').fetchone()[0]
        result['tft_history_gap_windows'] = db.execute('select count(*) from game_frame_windows where history_truncated=1').fetchone()[0]
        if not result['tft_present_intervals']: fail('TFT_PRESENTATION_PRODUCER_MISSING')
        for table, reason in [('input_dispatch_samples','INPUT_PRODUCER_MISSING'),('host_resource_samples','HOST_HEALTH_PRODUCER_MISSING'),('resource_samples','GUEST_HEALTH_PRODUCER_MISSING')]:
            if not db.execute('select count(*) from ' + table).fetchone()[0]: fail(reason)
        if not any(k == 'DEV_HIGHPERF_ENGINE_TARGETS_ACCEPTED' for k, _ in events): fail('EFFECTIVE_QUALITY_UNVERIFIED')
        failure = trace_failure(events)
        if failure: fail(failure)
        completed = [d for k, d in events if k == 'DIAGNOSTIC_TRACE_COMPLETED']
        if not completed: fail('SEALED_TRACE_MISSING')
        for item in completed:
            path = (root / item['relative_path']).resolve()
            if root not in path.parents or hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
                fail('TRACE_RAW_IDENTITY_CHANGED'); continue
            with Path(str(path) + '.normalized.csv').open() as handle: parsed = list(csv.DictReader(handle))
            if len(parsed) != 1 or int(parsed[0]['tft_process_rows']) < 1 or int(parsed[0]['scheduler_slices']) < 1:
                fail('TRACE_READBACK_HAS_NO_TFT_WORK')
        result['automatic_trigger_exercised'] = any(k == 'DIAGNOSTIC_TRACE_COMPLETED' and d.get('trigger') == 'AUTO_GAME_FRAME_DEGRADATION' for k, d in events)
        if not result['automatic_trigger_exercised']: fail('AUTOMATIC_TRACE_TRIGGER_UNPROVEN')
        result['prior_artifact_failures'] = sum(k == 'DIAGNOSTIC_TRACE_FAILED' for k, _ in events)
        result['limits'] = ['COLLECTOR_OVERHEAD_UNPROVEN', 'FULL_PIPELINE_LINEAGE_UNPROVEN', 'NO_GAMEPLAY_FPS_CLAIM']
    except (OSError, ValueError, KeyError, sqlite3.Error) as error:
        fail('ADMISSION_EVIDENCE_UNREADABLE: ' + str(error))
    result['status'] = 'DIAGNOSTIC_ADMISSION_PASS' if not result['reasons'] else 'DIAGNOSTIC_ADMISSION_FAIL'
    return result

if __name__ == '__main__':
    result = inspect(sys.argv[1])
    print(json.dumps(result, indent=2))
    sys.exit(0 if result['status'] == 'DIAGNOSTIC_ADMISSION_PASS' else 1)
