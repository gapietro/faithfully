# Merge policy

Status: current. Introduced by CLEAN-007 (audit tracker #39, issue #49).

## The gate is `make ci`, and now also CI

**Triggers restored 2026-08-03 (#89).** The workflow runs on every pull request
and every push to `main`. Making the repository public unblocked hosted capacity;
what kept the triggers off after that was a red `ui-test` job, resolved in #89
and #90 — both were gates whose result depended on the clock they ran at rather
than on the change under test.

**Nothing merges without a green `make ci` run on the branch, pasted or
summarised in the pull request.** This rule stands even with CI running: a
hosted run and a local run have caught different things, and #89 is the case in
point — three tests that passed locally and failed on the runner.

**Branch protection is set (2026-08-03).** `main` requires the aggregate
**`All checks`** job, requires branches to be up to date before merging, and
refuses force pushes. A red gate now *blocks* a merge rather than merely
embarrassing one, which is the first time that has been true in this
repository.

With one exception, stated because the difference matters: `enforce_admins` is
**false**, so a repository admin can still merge past a failing check. On a
solo-maintained repository that is most merges. The mechanism is real for
anyone else and for the admin's own mistakes-by-default, but it is not
absolute — treat the rule above as still load-bearing. Setting
`enforce_admins=true` would close the gap, at the cost of no manual override
when CI itself is broken.

Every check lives in the `Makefile` and runs identically on a laptop and in CI:

```sh
make bootstrap   # pinned swiftlint + xcodegen into .tools/, checksum-verified
make ci          # every gate below, in order
```

| Check | Target | Catches |
|---|---|---|
| Generated-project drift | `verify-project` | `project.yml` changed without regenerating the committed project |
| Content validation | `validate-content` | a malformed or missing challenge among the 365 |
| Lint | `lint` | `swiftlint --strict`, warnings promoted to errors |
| Unit and integration tests | `test` | logic regressions |
| Coverage floor | `coverage` | Services/ViewModels line coverage falling below 90% |
| UI tests | `ui-test` | product behaviour regressions in the real simulator |
| Accessibility audit | `accessibility` | Apple's audit over every screen: contrast, hit targets, Dynamic Type, clipping, missing labels |
| Static analysis | `analyze` | analyzer findings |
| Strict concurrency | `strict-concurrency` | Swift 6 data-race diagnostics in project-owned code |
| Release archive | `archive` | a broken release build, and a device-family/orientation regression |

The workflow is `.github/workflows/ci.yml`. It runs the same targets in the same
order, on `pull_request`, on pushes to `main`, and on `workflow_dispatch`.

## Turning the triggers on

Kept as a record of the order used, because the order was the point — and
because it is the procedure to repeat if the triggers ever come back off.

**1. Prove a hosted run works first.** Restoring the triggers before that would
produce a check that always fails if capacity is still unavailable, or if a test
is environment-dependent — worse than no check, because it teaches everyone to
ignore red.

```sh
gh workflow run ci.yml --ref <branch>
gh run watch
```

Both failure modes actually happened. Capacity was the first (jobs dying in ~2s
with no runner assigned, fixed by going public). A date-dependent test suite was
the second: #89 for three UI tests, #90 for two unit tests that failed only
after 21:00 local — and on a UTC runner, that is a gate red for three hours
every day.

**2. Then require the check.** Done 2026-08-03. Requires the single
**`All checks`** job, which aggregates the others — so adding a check later does
not require editing the protection rule to match. A rule that lists jobs
individually silently stops covering anything added afterwards.

```sh
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -F required_status_checks[strict]=true \
  -F required_status_checks[contexts][]="All checks" \
  -F enforce_admins=false \
  -F required_pull_request_reviews=null \
  -F restrictions=null
```

Or Settings → Branches → Add rule for `main`:

- Require a pull request before merging
- Require status checks to pass → **All checks**
- Require branches to be up to date before merging

Verify it actually took, rather than assuming the call succeeded:

```sh
gh api repos/:owner/:repo/branches/main/protection --jq '.required_status_checks.contexts'
```

## Changing a pinned tool

Versions and SHA-256 checksums live in `scripts/versions.env`. Both change in
the same commit; `scripts/bootstrap.sh` refuses a download whose checksum does
not match, so a bumped version with a stale checksum fails loudly rather than
installing an unverified binary.

## Toolchain selection

`XCODE_PREFERRED_VERSION` is used when that bundle is present;
`scripts/select_xcode.sh` otherwise falls back to the newest installed Xcode,
provided it meets `XCODE_MIN_VERSION`, and logs which one it chose.
`scripts/resolve_simulator.sh` does the same for the simulator.

This is deliberate. Pinning only an exact bundle path looks stricter but is a
bet that a specific app exists on the machine — the first version of this
workflow hard-coded `/Applications/Xcode_26.6.app` and every job died in 20
seconds on a runner image that did not have it. A minimum plus a logged choice
fails when the toolchain is genuinely too old, and not when an image is
updated.

## Runner capacity

**Resolved by making the repository public (2026-08-03).** Actions minutes are
unlimited on public repositories and branch protection becomes available, which
closes both halves of this at once — the capacity block *and* the enforcement
gap. The decision is recorded in [`../../CONTENT-LICENSE.md`](../../CONTENT-LICENSE.md):
the code is MIT, the challenge content is not, so publishing the repository does
not hand anyone a finished competing app.

For the record, the problem it solved: a private repository on the free plan
gets 2,000 Actions minutes a month and macOS bills at **10x**, so about 200
macOS minutes — the UI job alone is roughly 20 of them. Part-way through the
remediation pass, hosted macOS runs stopped being scheduled entirely: jobs
failed in about two seconds with no runner assigned and no steps executed. That
was a resource block, not a code failure.

A self-hosted runner was the alternative and was rejected: a workflow run
executes repository code as the host user, which is unacceptable on a public
repository, and CI would only exist while that machine was awake.

## What CI still does not cover

Honest list, so nobody mistakes a green tick for more than it is:

- **Signing, TestFlight upload, and App Store validation** — needs App Store
  Connect credentials. The archive is built unsigned. Tracked in #52.
- **Physical-device behaviour** and performance on real hardware. Tracked in
  #55 and #56.
- **Whether the app makes sense read aloud.** The audit catches contrast, hit
  targets, Dynamic Type, clipping, and missing labels. It cannot tell you
  whether the announced order is sensible or the wording is comprehensible —
  that still needs a person with VoiceOver switched on (#55).
- **Crash reporting and incident response.** Tracked in #53.

`make archive` proves the release build compiles and declares the right device
family. It does not prove the app is shippable.
