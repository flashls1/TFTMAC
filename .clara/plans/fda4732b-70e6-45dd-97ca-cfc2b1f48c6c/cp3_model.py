"""Bounded CP3 migration model. No real disks or runtime are accessed."""
from dataclasses import dataclass, replace
from collections import deque
from pathlib import Path
import hashlib, json

@dataclass(frozen=True)
class State:
    phase: str = 'idle'
    owner: str = 'none'
    backup: bool = False
    copied: bool = False
    verified: bool = False
    source_current: bool = True
    independent: bool = True
    original_changed: bool = False
    published: bool = False
    signed: bool = False
    authenticated: bool = False

def successors(s):
    out=[]
    if s.owner=='none' and s.phase=='idle':
        out += [('acquire',replace(s,owner='migration',phase='copying')),
                ('foreign_launch',replace(s,owner='foreign'))]
    if s.owner=='foreign': out += [('foreign_exit',replace(s,owner='none'))]
    if s.owner=='migration':
        if s.phase=='copying':
            out += [('backup_verified',replace(s,backup=True)),
                    ('copy_complete',replace(s,copied=True)),
                    ('source_drift',replace(s,source_current=False)),
                    ('alias_detected',replace(s,independent=False))]
            if s.backup and s.copied and s.source_current and s.independent:
                out += [('verify',replace(s,verified=True,phase='verified'))]
        if s.phase in ('copying','verified'):
            out += [('interruption',replace(s,owner='none',phase='interrupted'))]
        if s.phase=='verified' and s.source_current and s.independent:
            out += [('publish_atomic',replace(s,published=True,phase='published',owner='none'))]
    if s.phase=='interrupted' and s.owner=='none':
        if s.source_current and s.independent:
            out += [('resume_revalidate',replace(s,owner='migration',phase='copying',verified=False))]
        else: out += [('quarantine',replace(s,phase='quarantined'))]
    if s.phase=='published': out += [('signed_candidate',replace(s,phase='ready',signed=True))]
    if s.phase=='ready' and s.owner=='none': out += [('launch',replace(s,phase='running',owner='candidate'))]
    if s.phase=='running':
        out += [('account_accepted',replace(s,authenticated=True)),
                ('normal_stop',replace(s,phase='stopped',owner='none'))]
    return [(a,n) for a,n in out if n!=s]

def oracle(before,action,after):
    assert not after.original_changed, 'original mutation'
    if after.published:
        assert after.backup and after.copied and after.verified and after.source_current and after.independent, 'unverified publication'
    if after.phase=='running':
        assert after.published and after.signed and after.owner=='candidate', 'unverified launch'
    if action in ('backup_verified','copy_complete','verify','publish_atomic'):
        assert before.owner=='migration', 'foreign ownership'
    if after.authenticated:
        assert after.signed and after.published and after.phase in ('running','stopped'), 'invented authentication'

seen={State()}; q=deque(seen); actions=set(); transitions=0
while q:
    s=q.popleft()
    for a,n in successors(s):
        oracle(s,a,n); actions.add(a); transitions+=1
        if n not in seen: seen.add(n);q.append(n)
assert {'interruption','resume_revalidate','quarantine','foreign_launch','source_drift','alias_detected','launch','account_accepted','normal_stop'} <= actions
bad=[(State(owner='foreign'),'copy_complete',State(copied=True)),
     (State(),'publish_atomic',State(published=True)),
     (State(),'bad',State(original_changed=True)),
     (State(),'launch',State(phase='running',owner='candidate')),
     (State(),'bad',State(authenticated=True)),
     (State(owner='migration'),'publish_atomic',State(published=True,backup=True,copied=True,verified=True,source_current=False)),
     (State(owner='migration'),'publish_atomic',State(published=True,backup=True,copied=True,verified=True,independent=False))]
for b,a,n in bad:
    try: oracle(b,a,n)
    except AssertionError: pass
    else: raise AssertionError('negative control survived')
report={'result':'PASS','source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'reachable_states':len(seen),'transitions':transitions,'reachable_actions':sorted(actions),'negative_controls_detected':len(bad),'scope':'CP3 offline migration and activation constraints; not real-world acceptance'}
print(json.dumps(report,indent=2))
