#!/usr/bin/env python3
"""Validate the challenges JSON bundle for the public-domain (KJV + WEB) v1.

Checks every copy of the challenge data:
  - 365 rows, unique ids, days exactly 1..365
  - scripture_text_kjv and scripture_text_web present and non-empty
  - no leftover esv/niv/nkjv keys
  - Resources/tests copies hash-identical to the root master
  - batch files partition the master by day

Exit code 0 on success, 1 with a report on any failure.
"""

import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

MASTER = REPO / "challenges.json"
COPIES = [
    REPO / "Faithfully" / "Resources" / "challenges.json",
    REPO / "FaithfullyTests" / "challenges.json",
]
BATCHES = [(1, 73), (74, 146), (147, 219), (220, 292), (293, 365)]

REQUIRED_KEYS = {
    "id", "day", "title", "category", "scripture_reference",
    "scripture_text_kjv", "scripture_text_web",
    "challenge_description", "reflection_prompt", "difficulty",
}
FORBIDDEN_KEYS = {"scripture_text_esv", "scripture_text_niv", "scripture_text_nkjv"}

errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


challenges = json.loads(MASTER.read_text())
check(len(challenges) == 365, f"expected 365 rows, got {len(challenges)}")

ids = [c["id"] for c in challenges]
check(len(set(ids)) == len(ids), "duplicate ids found")

days = sorted(c["day"] for c in challenges)
check(days == list(range(1, 366)), "days are not exactly 1..365")

for c in challenges:
    cid = c.get("id", "<no id>")
    missing = REQUIRED_KEYS - c.keys()
    check(not missing, f"{cid}: missing keys {sorted(missing)}")
    leftover = FORBIDDEN_KEYS & c.keys()
    check(not leftover, f"{cid}: forbidden keys {sorted(leftover)}")
    for key in ("scripture_text_kjv", "scripture_text_web"):
        check(bool(c.get(key, "").strip()), f"{cid}: {key} is empty")

master_hash = hashlib.sha256(MASTER.read_bytes()).hexdigest()
for copy in COPIES:
    copy_hash = hashlib.sha256(copy.read_bytes()).hexdigest()
    check(copy_hash == master_hash, f"{copy.relative_to(REPO)} differs from master")

seen_days = []
for lo, hi in BATCHES:
    path = REPO / f"challenges_{lo:03d}_{hi:03d}.json"
    batch = json.loads(path.read_text())
    expected = [c for c in challenges if lo <= c["day"] <= hi]
    check(batch == expected, f"{path.name} does not match master rows {lo}..{hi}")
    seen_days.extend(c["day"] for c in batch)
check(sorted(seen_days) == list(range(1, 366)), "batches do not partition days 1..365")

if errors:
    print(f"FAIL: {len(errors)} problem(s)")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"OK: 365 challenges valid across master, {len(COPIES)} copies, {len(BATCHES)} batches")
