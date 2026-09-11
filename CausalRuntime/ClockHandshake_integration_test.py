"""Exercise the native wire transport; no gameplay or driver state is changed."""
import json
import pathlib
import socket
import subprocess
import sys
import threading
import time


binary = str(pathlib.Path(sys.argv[1]).resolve())
session = ["0123456789abcdef", "fedcba9876543210"]


def unused_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


port = unused_port()
server = subprocess.Popen([binary, "server", str(port), *session], stdout=subprocess.PIPE, text=True)
try:
    ready = json.loads(server.stdout.readline())
    assert ready["state"] == "CLOCK_SERVER_READY"
    run = subprocess.run([binary, "client", str(port), *session, "20", "1"],
                         text=True, capture_output=True, timeout=5, check=True)
    samples = [json.loads(line) for line in run.stdout.splitlines()]
    assert len(samples) == 20 and [x["sequence"] for x in samples] == list(range(1, 21))
    for sample in samples:
        assert sample["state"] in ("CLOCK_PRECISE", "CLOCK_UNCERTAIN")
        assert sample["session_id"] == "".join(session)
        assert sample["offset_lower_ns"] <= sample["offset_upper_ns"]
        assert sample["uncertainty_ns"] == (sample["offset_upper_ns"] - sample["offset_lower_ns"] + 1) // 2
        assert (sample["state"] == "CLOCK_PRECISE") == (sample["uncertainty_ns"] <= 500000)
    wrong = subprocess.run([binary, "client", str(port), session[1], session[0], "1", "1"],
                           text=True, capture_output=True, timeout=5)
    assert wrong.returncode == 4
    assert json.loads(wrong.stdout)["state"] == "CLOCK_HANDSHAKE_IO_FAILED"
finally:
    server.terminate()
    server.wait(timeout=5)

# A producer that accepts the request but never replies cannot hang readiness.
with socket.socket() as stalled:
    stalled.bind(("127.0.0.1", 0))
    stalled.listen(1)
    port = stalled.getsockname()[1]
    release = threading.Event()

    def no_reply():
        peer, _ = stalled.accept()
        with peer:
            peer.recv(80)
            release.wait(5)

    thread = threading.Thread(target=no_reply)
    thread.start()
    started = time.monotonic()
    try:
        run = subprocess.run([binary, "client", str(port), *session, "1", "1"],
                             text=True, capture_output=True, timeout=5)
        assert run.returncode == 4
        assert json.loads(run.stdout)["state"] == "CLOCK_HANDSHAKE_IO_FAILED"
        assert time.monotonic() - started < 4
    finally:
        release.set()
        thread.join(timeout=5)

print(json.dumps({"state": "CLOCK_HOST_TRANSPORT_TESTS_PASS", "samples": len(samples),
                  "max_sample_uncertainty_ns": max(x["uncertainty_ns"] for x in samples),
                  "wrong_session_rejected": True, "stalled_producer_rejected": True,
                  "guest_clock_alignment_proven": False}))
