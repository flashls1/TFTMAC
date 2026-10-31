"""Bounded build-only lifecycle model; not an application acceptance test."""
from dataclasses import dataclass, replace
from collections import deque
import hashlib, json
from pathlib import Path

@dataclass(frozen=True)
class State:
    phase: str = 'NEW'
    source_current: bool = True
    foreign_target: bool = False
    signed: bool = False
    verified: bool = False
    published: bool = False
    interrupted: bool = False
    account_reads: int = 0
    original_writes: int = 0
    runtime_spawns: int = 0

def transitions(s):
    if s.published or s.phase == 'QUARANTINED':
        return []
    out = []
    if not s.foreign_target:
        out.append(('target_conflict', replace(s, foreign_target=True)))
    if s.source_current:
        out.append(('source_drift', replace(s, source_current=False, verified=False)))
    if s.phase != 'NEW' and not s.interrupted:
        out.append(('interrupt', replace(s, interrupted=True, verified=False)))
    if s.interrupted:
        out.append(('resume_revalidate', replace(s, interrupted=False, phase='STAGED', signed=False, verified=False)))
        return out
    if not s.source_current or s.foreign_target:
        out.append(('quarantine', replace(s, phase='QUARANTINED')))
        return out
    if s.phase == 'NEW':
        out.append(('stage_exclusive', replace(s, phase='STAGED')))
    elif s.phase == 'STAGED':
        out.append(('compile', replace(s, phase='COMPILED')))
    elif s.phase == 'COMPILED':
        out.append(('sign_nested_then_outer', replace(s, phase='SIGNED', signed=True)))
    elif s.phase == 'SIGNED':
        out.append(('verify_inputs_artifact_tests', replace(s, phase='VERIFIED', verified=True)))
    elif s.phase == 'VERIFIED':
        out.append(('publish_exclusive', replace(s, phase='PUBLISHED', published=True)))
    return out

def oracle(s):
    assert s.account_reads == 0, 'account access is outside the revised scope'
    assert s.original_writes == 0, 'incumbents are immutable'
    assert s.runtime_spawns == 0, 'runtime activation is deferred'
    if s.published:
        assert s.phase == 'PUBLISHED'
        assert s.signed and s.verified and s.source_current
        assert not s.foreign_target and not s.interrupted

seen = {State()}; todo = deque(seen); actions = set(); count = 0
while todo:
    before = todo.popleft()
    for action, after in transitions(before):
        oracle(after); actions.add(action); count += 1
        if after not in seen:
            seen.add(after); todo.append(after)
assert any(s.published for s in seen)
for action in ('interrupt','resume_revalidate','source_drift','target_conflict','quarantine','publish_exclusive'):
    assert action in actions
valid = State(phase='PUBLISHED', signed=True, verified=True, published=True)
defects = [replace(valid, signed=False), replace(valid, verified=False),
           replace(valid, source_current=False), replace(valid, foreign_target=True),
           replace(valid, interrupted=True), replace(valid, original_writes=1),
           replace(valid, account_reads=1), replace(valid, runtime_spawns=1)]
caught = 0
for defect in defects:
    try: oracle(defect)
    except AssertionError: caught += 1
assert caught == len(defects)
result = {'result':'PASS_MODEL_ONLY', 'model_source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'states':len(seen), 'transitions':count, 'reachable_actions':sorted(actions),
          'negative_controls_detected':caught, 'live_runtime_or_authentication_proof':False}
Path(__file__).with_name('CP3_BUILD_ZENMC.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
