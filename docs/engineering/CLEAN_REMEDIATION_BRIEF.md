# CLEAN remediation brief — Issue #39

**Goal:** Remediate all CLEAN-001…012 findings to A-level production readiness before public release.

**Baseline:** main @ 9ffe014 (or current main HEAD).

**Product decisions (the owner / Scout, 2026-08):**
1. **CLEAN-001:** Global civil-date shared schedule — NOT tenure/enrollment-relative. Same challenge for all users on the same civil calendar date. Derive year rotation from a fixed global epoch / calendar year, not `userStartDate`.
2. **CLEAN-010:** v1 is **iPhone-only**. Set `TARGETED_DEVICE_FAMILY: "1"` in project.yml / settings. No iPad orientation work.
3. **CLEAN-005:** Design + implement a stable civil-day model. Prefer a day-key (yyyy-MM-dd in a documented timezone policy). Document TZ policy (recommend: device local calendar for v1, with tests for TZ change / DST). Migration if schema changes — include tests. Do NOT bundle with unrelated cleanup.

**Discipline (mandatory):**
- One logical finding per commit; commit message includes finding ID e.g. `CLEAN-001: ...`
- Regression test before or with every behavioral fix
- TDD preferred
- `xcodegen generate` after project.yml changes; keep pbxproj deterministic
- Do not open ASC / TestFlight / store submit
- Do not force-push main; work on this branch; open PR when phases complete or large logical chunks ready

**Order:**
Phase 1: 001 → 002 → 003 → 010
Phase 2: 004 → 005 → 006 → 009
Phase 3: 008 → 007
Phase 4: ops docs (crash/support/privacy/perf budgets) — concise markdown under docs/ship or docs/engineering
Phase 5: 011 → 012 → Swift 6 strict concurrency zero project-owned warnings

**Verify after each finding (or batch):**
```
xcodegen generate
python3 scripts/validate_challenges.py
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:FaithfullyTests test
```
Full suite + archive when phases complete.

**Full requirements:** GitHub issue #39 body.

**Done when:** All P1/P2 checkboxes addressable in code/docs are done; PR description maps each CLEAN-ID to commits; tests green.
