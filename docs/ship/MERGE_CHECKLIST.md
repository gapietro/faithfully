# Merge policy

Status: current. Introduced by CLEAN-007 (audit tracker #39, issue #49).

## The gate

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
| Static analysis | `analyze` | analyzer findings |
| Strict concurrency | `strict-concurrency` | Swift 6 data-race diagnostics in project-owned code |
| Release archive | `archive` | a broken release build, and a device-family/orientation regression |

The workflow is `.github/workflows/ci.yml`. It runs on every pull request and on
every push to `main`.

## Required checks

Require the single **`All checks`** job in branch protection. It aggregates the
others, so adding a check to the workflow does not require editing the
protection rule to match — a rule that lists jobs individually silently stops
covering anything added later.

Settings → Branches → Add rule for `main`:

- Require a pull request before merging
- Require status checks to pass → **All checks**
- Require branches to be up to date before merging

**If branch protection is unavailable** — the audit recorded GitHub returning
403 for this repository's account tier — the workflow still runs on every pull
request and its result is visible on the PR. Until protection can be enabled,
the rule is enforced by hand:

> Do not merge a pull request whose **All checks** job is not green. If a check
> is failing for a reason unrelated to the change, say so in the PR and link the
> evidence; do not merge past a red check silently.

Re-check whether protection can be enabled whenever the plan changes:

```sh
gh api repos/:owner/:repo/branches/main/protection
```

## Changing a pinned tool

Versions and SHA-256 checksums live in `scripts/versions.env`. Both change in
the same commit; `scripts/bootstrap.sh` refuses a download whose checksum does
not match, so a bumped version with a stale checksum fails loudly rather than
installing an unverified binary.

## What CI still does not cover

Honest list, so nobody mistakes a green tick for more than it is:

- **Signing, TestFlight upload, and App Store validation** — needs App Store
  Connect credentials. The archive is built unsigned. Tracked in #52.
- **Physical-device behaviour**, including accessibility and performance on real
  hardware. Tracked in #55 and #56.
- **Crash reporting and incident response.** Tracked in #53.

`make archive` proves the release build compiles and declares the right device
family. It does not prove the app is shippable.
