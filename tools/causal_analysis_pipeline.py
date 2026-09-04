#!/usr/bin/env python3
import glob, os, sys, struct, hashlib, json
from collections import defaultdict
import statistics

def analyze_events(events_dir):
    files = sorted(glob.glob(os.path.join(events_dir, "*.bin")))
    hdr_fmt = "<8sHHIQQQQQ32s32s32s"
    ev_fmt = "<HHHHIQQQQIIIQ32s"

    raw_events = []
    all_overwrites = 0
    all_losses = 0
    all_hashes_valid = True
    total_events = 0
    site_counts = defaultdict(int)

    for path in files:
        size = os.path.getsize(path)
        if size == 0: continue
        with open(path, "rb") as f:
            data = f.read()

        offset = 0
        while offset < len(data):
            if len(data) - offset < 152: break
            magic, schema, hdr_bytes, count, seq, started, ended, overwrites, losses, prev_sha, payload_sha, seg_sha = struct.unpack_from(hdr_fmt, data, offset)
            if magic != b"TFTPIPE1": break

            payload_bytes = count * 96
            payload = data[offset + hdr_bytes : offset + hdr_bytes + payload_bytes]
            calc_payload_sha = hashlib.sha256(payload).digest()
            chain_input = prev_sha + payload_sha + struct.pack("<QQQ", seq, started, ended)
            calc_seg_sha = hashlib.sha256(chain_input).digest()

            if calc_payload_sha != payload_sha or calc_seg_sha != seg_sha:
                all_hashes_valid = False

            all_overwrites += overwrites
            all_losses += losses

            for i in range(count):
                ev_off = offset + hdr_bytes + i * 96
                _, kind, boundary, flags, pid, tid, ts, work_id, pres_id, lin_gen, site_id, q_depth, dur, _ = struct.unpack_from(ev_fmt, data, ev_off)
                total_events += 1
                site_counts[site_id] += 1
                if work_id > 0:
                    raw_events.append({
                        "kind": kind,
                        "site_id": site_id,
                        "ts": ts,
                        "work_id": work_id,
                        "dur": dur,
                        "tid": tid
                    })
            offset += hdr_bytes + payload_bytes

    print(f"============================================================")
    print(f"CAUSAL PIPELINE EVENT ANALYSIS: {events_dir}")
    print(f"============================================================")
    print(f"Total events: {total_events}")
    print(f"All SHA-256 signatures valid: {all_hashes_valid}")
    print(f"Total overwrites: {all_overwrites}, Total losses: {all_losses}")
    print(f"\nSite breakdown:")
    site_names = {
        1001: "GfxstreamDecode (instant)",
        1002: "HostVulkanSubmit (begin/end)",
        2002: "MoltenVKEnqueueEntry (instant)",
        2003: "MoltenVKEnqueueQueue (begin/end)",
        2004: "MetalCommit (instant)",
        2005: "MetalGpuComplete (end/callback)"
    }
    for site, cnt in sorted(site_counts.items()):
        print(f"  Site {site} ({site_names.get(site, 'unknown')}): {cnt} events")

    # Use all events with work_id > 0
    campaign_events = raw_events
    print(f"\nAnalyzing Campaign Events: {len(campaign_events)} events")

    by_wid = defaultdict(lambda: defaultdict(list))
    for e in campaign_events:
        by_wid[e["work_id"]][e["site_id"]].append(e)

    all_wids = sorted(by_wid.keys())
    print(f"Distinct campaign transport_work_ids: {len(all_wids)} (range {min(all_wids) if all_wids else 0} .. {max(all_wids) if all_wids else 0})")

    ranges = [
        {"workload": "0. Warmup (30s)", "start_wid": 1, "end_wid": 1800},
        {"workload": "1. stable_descriptor_draw (60s)", "start_wid": 1801, "end_wid": 5402},
        {"workload": "2. texture_upload_sampling (60s)", "start_wid": 5403, "end_wid": 9005},
        {"workload": "3. pipeline_shader_churn (60s)", "start_wid": 9006, "end_wid": 12608},
        {"workload": "4. fill_rate_overdraw (60s)", "start_wid": 12609, "end_wid": 16210},
        {"workload": "5. queue_fence_present_pressure (60s)", "start_wid": 16211, "end_wid": 25000},
    ]

    def pstats(lbl, vals):
        if not vals:
            print(f"    {lbl:<38} | no data")
            return
        s = sorted(vals)
        print(f"    {lbl:<38} | mean: {statistics.mean(s):6.3f} ms | p50: {statistics.median(s):6.3f} ms | p95: {s[int(len(s)*0.95)]:6.3f} ms | p99: {s[int(len(s)*0.99)]:6.3f} ms | max: {s[-1]:6.3f} ms (N={len(vals)})")

    # Global aggregate
    def compute_metrics(matching_wids):
        dur_1002 = []
        dur_2003 = []
        dur_2005 = []
        lat_1001_to_2002 = []
        lat_2002_to_2003 = []
        lat_2003_to_2004 = []
        lat_2004_to_2005 = []
        total_pipeline = []
        fully_corr = 0

        for wid in matching_wids:
            sites = by_wid[wid]
            if {1001, 1002, 2002, 2003, 2004, 2005}.issubset(sites.keys()):
                fully_corr += 1

            for e in sites.get(1002, []):
                if e["kind"] == 2: dur_1002.append(e["dur"] / 1e6)
            for e in sites.get(2003, []):
                if e["kind"] == 2: dur_2003.append(e["dur"] / 1e6)
            for e in sites.get(2005, []):
                if e["dur"] > 0: dur_2005.append(e["dur"] / 1e6)

            evs_1001 = sites.get(1001, [])
            evs_2002 = sites.get(2002, [])
            if evs_1001 and evs_2002:
                dt = (evs_2002[0]["ts"] - evs_1001[0]["ts"]) / 1e6
                if 0 <= dt < 1000: lat_1001_to_2002.append(dt)

            evs_2003_begin = [e for e in sites.get(2003, []) if e["kind"] == 1]
            if evs_2002 and evs_2003_begin:
                dt = (evs_2003_begin[0]["ts"] - evs_2002[0]["ts"]) / 1e6
                if 0 <= dt < 1000: lat_2002_to_2003.append(dt)

            evs_2004 = sites.get(2004, [])
            evs_2003_end = [e for e in sites.get(2003, []) if e["kind"] == 2]
            if evs_2003_end and evs_2004:
                dt = (evs_2004[0]["ts"] - evs_2003_end[0]["ts"]) / 1e6
                if abs(dt) < 1000: lat_2003_to_2004.append(dt)

            evs_2005 = sites.get(2005, [])
            if evs_2004 and evs_2005:
                dt = (evs_2005[0]["ts"] - evs_2004[0]["ts"]) / 1e6
                if 0 <= dt < 1000: lat_2004_to_2005.append(dt)

            if evs_1001 and evs_2005:
                dt = (evs_2005[-1]["ts"] - evs_1001[0]["ts"]) / 1e6
                if 0 <= dt < 1000: total_pipeline.append(dt)

        pct = (fully_corr / len(matching_wids) * 100.0) if matching_wids else 0.0
        print(f"  Full 6-site correlation: {fully_corr} / {len(matching_wids)} ({pct:.1f}%)")
        pstats("1. Host Submit Time (1002 dur)", dur_1002)
        pstats("2. MoltenVK Translate & Enqueue (2003 dur)", dur_2003)
        pstats("3. Metal GPU Execution (2005 dur)", dur_2005)
        pstats("4. Gfxstream Decode -> MVK Entry (1001->2002)", lat_1001_to_2002)
        pstats("5. MVK Entry -> Submit Begin (2002->2003)", lat_2002_to_2003)
        pstats("6. Metal Commit -> GPU Complete (2004->2005)", lat_2004_to_2005)
        pstats("7. Total Pipeline Latency (1001->2005)", total_pipeline)

    print(f"\n============================================================")
    print(f"OVERALL CAMPAIGN METRICS (All Workloads)")
    print(f"============================================================")
    compute_metrics(all_wids)

    for r in ranges:
        w_name = r["workload"]
        s_wid = r["start_wid"]
        e_wid = r["end_wid"]
        matching = [w for w in all_wids if s_wid <= w <= e_wid]
        if not matching: continue
        print(f"\n------------------------------------------------------------")
        print(f"WORKLOAD: {w_name} (active work_ids={len(matching)})")
        print(f"------------------------------------------------------------")
        compute_metrics(matching)

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Captures/causal-hook-timeline-20260903-r6/events"
    analyze_events(path)
