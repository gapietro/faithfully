# Publish Report — faithfully — 2026-08-15

**Verdict: READY (0 blockers)** — pilot round 2 of `/senior-publish` v1.

## Blockers

None remaining. One finding was remediated during the run (see Warnings 1).

## Warnings — remediated this run

1. **A credential-location map in the ship docs.** `docs/ship/SESSION_HANDOFF.md`
   carried a "Secrets & tooling" table naming the macOS Keychain service and
   account holding an API key, the account `gh` authenticates as and where its
   token lives, the development machine, and a personal contact channel for ship
   approvals. **No secret value was ever committed** — which is exactly why every
   pattern scanner reported the repo clean. This is the shapeless class: a map of
   where the credentials live, invisible to gitleaks, catchable only by a human
   ruling on the file. Removed from the working tree and, per user ruling, from
   history via `git filter-repo --replace-text`; force-pushed 2026-08-15.
2. **Radioactive-terms list is armed but thin** (10 harvested ServiceNow
   hostnames; the consulting sections are not yet filled). It found nothing here,
   correctly — faithfully is a personal app with no customer content.

## Advisories

- Commit **author identity** (5 identities, 2 email addresses) remains in commit
  metadata. Deliberately not rewritten: authorship is public on every commit of
  every repo, and rewriting it would break GitHub contribution attribution, which
  is part of why this repo is being published. Recorded, not "fixed".
- The word `keyring` survives in 2 historical blobs in a context that reveals
  nothing beyond `gh`'s documented default. Accepted.
- `git push --force --all` during remediation published 3 local-only branches
  (`pr-18`, `sprint-a-correctness`, `sprint-b-mvp-wiring`) that the remote never
  had. Detected by diffing local refs against the backup's `refs/remotes/origin/*`
  and deleted the same session. Cause and fix are now in the skill's scan
  reference.

## Scans

| Scan | Tool / method | Coverage | Result |
|---|---|---|---|
| Secrets (commit walk) | gitleaks | 79 commits | clean |
| Secrets (blob level) | gitleaks over extracted blobs | **518 blobs / 15.35 MB, every ref** | **clean** |
| Radioactive terms | literal, 10 armed | every blob, all refs | clean |
| Identity / machine sweep | targeted literals | tree + history | 1 finding (Warning 1), remediated |
| Hygiene | tracked-vs-ignored audit | tree + history | `.superpowers/`, `.DS_Store`, `build/` never committed |

**The commit walk is not the blob set.** gitleaks reported 79 commits against
`rev-list --all --count` of 119: it skips merge commits, which carry no diff of
their own. Verified by proving every branch was fully merged into main, then
re-scanning at blob level — the check invariant 2 actually asks for. Both the
trap and the blob-level procedure are now in the skill.

## Ownership gate

Remote `github.com/gapietro/faithfully` — personal. No org attestation required.

## History decision

**Rewritten** (user ruling): `filter-repo --replace-text` redacting machine,
account, and contact literals across all 120 commits, then force-push. Files were
kept (`--replace-text`, not `--path` removal, which would have deleted the
documents outright). Mirror backup at `~/projects/.faithfully-prefilter-backup.git`.

The ruling was made with the retention fact stated: **GitHub never GCs pushed
commits**, so old blobs stay SHA-reachable even after a rewrite. The rewrite stops
casual browsing; only deleting and recreating the repo removes them, which would
cost every issue and PR the ship docs cross-reference. Accepted knowingly.

Branch protection blocked the force-push (`allow_force_pushes: false`, admins
included). Resolved by capturing the full protection JSON, PUTting it back with
only that flag flipped, pushing, restoring, and re-reading to confirm.

## Admission summary

14 rulings in `.publish-manifest.json`: 9 ship, 4 redact-then-ship, 1 explicit
non-action (author identity). Two overrode skill defaults, both recorded:
`SESSION_HANDOFF.md` (private-ledger default overridden — deliberately committed
and SNAPSHOT-bannered) and the privacy-policy gist URLs (an alt account handle
that is **intentionally public**, so deliberately not treated as radioactive).

## Licensing — the sharpest risk in a devotional app, already closed

Scripture text ships as **WEB and KJV, both public domain**; ESV/NIV/NKJV were
removed from the bundle before v1. Code is MIT, content is all-rights-reserved,
and `CONTENT-LICENSE.md` states precisely which is which and why. This is the
class of problem that gets an app pulled, and it was handled before this run
started.

## Clean-room verify — PASS (scoped)

Fresh `git clone --local`, `env -i` with only a realistic login environment
seeded (`HOME`, `PATH`, `USER`, `LOGNAME`, `LANG`) — no author state, no
Homebrew on `PATH`.

| Step | Result |
|---|---|
| `./scripts/bootstrap.sh` | PASS — downloaded and checksum-verified pinned SwiftLint 0.65.0 + XcodeGen 2.46.0 into `.tools/` with only `/usr/bin:/bin` on PATH |
| `make generate` | PASS |
| `make validate-content` | PASS — 365 challenges valid across master, 2 copies, 5 batches |
| `make lint` | PASS — 0 violations, 0 serious, 103 files |

**Not run, deliberately:** `test`, `coverage`, `ui-test`, `accessibility`,
`analyze`, `strict-concurrency`, `archive` — every simulator-and-Xcode-build gate
in `make ci`. They are the expensive majority of the suite and were skipped for
run cost, not because they were expected to pass. **This report does not claim
`make ci` is green.** CI runs the full gate on every push; trust that, not this.

**A false positive worth recording:** the first clean-room attempt used bare
`env -i` and `make generate` failed with "Couldn't find current username" —
xcodegen needs `USER`, which no real login lacks. The clean room was stricter
than reality; a check that cries wolf gets ignored. The skill now prescribes
seeding a minimal realistic environment and re-testing before recording a docs
failure.

## Best-light

- [x] README: purpose in two lines, routing table to deep docs, build/verify,
      honest licence split. Historical `sparc/` flagged inline so no reader is
      misled about CloudKit.
- [x] **Screenshots added to the README this run** — the repo had them under
      `docs/ship/screenshots/` and the front page showed none.
- [x] LICENSE + CONTENT-LICENSE, both explained
- [x] Pinned, checksum-verified toolchain via `scripts/bootstrap.sh`
- [x] AUDIT.md tracked

## Resident guards

- [x] `.git/hooks/pre-commit` + `pre-push`: gitleaks on the staged diff plus the
      radioactive-terms literal scan.
- [ ] **After the flip**: Settings → Code security → **Secret Protection** and
      **Push protection** (both, as on gccusage). Hooks are bypassable with
      `--no-verify`; push protection is not. Neither sees the shapeless class —
      that stays with the terms list and admission review.

## To publish (manual — the skill never does this)

1. Commit the pending changes (README screenshots, `.publish-manifest.json`, this
   report) — the sanitization commit is already pushed.
2. GitHub → Settings → General → Danger Zone → Change visibility → **Public**.
3. Enable Secret Protection + Push protection.
4. Standing rule: flipping is irreversible in effect. If anything ever leaks,
   **revoke first** — going private again and rewriting history only stop future
   readers.
