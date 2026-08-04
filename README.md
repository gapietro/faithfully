# Faithfully

A daily Christian action app: one scripture-backed challenge a day, the same one
for everyone, done on your phone and kept on your phone.

iPhone · SwiftUI · SwiftData · no account, no backend, no third-party dependencies.

## Start here

| I want to… | Read |
|---|---|
| Understand how it is built | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Know if it is ready to ship | [`docs/ship/README.md`](docs/ship/README.md) |
| Run the checks | [`docs/ship/MERGE_CHECKLIST.md`](docs/ship/MERGE_CHECKLIST.md) |
| See which promises are proven | [`docs/ship/CLAIMS.md`](docs/ship/CLAIMS.md) |
| Understand the product | [`PRD.md`](PRD.md) |
| Touch anything involving dates | [`docs/architecture/TIMEZONE_POLICY.md`](docs/architecture/TIMEZONE_POLICY.md) |

The [`sparc/`](sparc/) tree is the original design phase. It is **historical** and
still describes CloudKit sync and licensed translations, neither of which v1 has.

## Build and verify

```sh
./scripts/bootstrap.sh   # pinned swiftlint + xcodegen into .tools/
make ci                  # every quality gate, same as CI
```

`make help` lists the individual targets.

## Licence

Split, deliberately.

- **Code is MIT** — [`LICENSE`](LICENSE). Take the civil-day model, the
  persistence contract, the accessibility work, the `make ci` gate. They cost
  this project nothing to share and are the parts worth borrowing.
- **Content is all rights reserved** — [`CONTENT-LICENSE.md`](CONTENT-LICENSE.md).
  The 365 challenges, the docs, the artwork. The scripture text itself is public
  domain (WEB and KJV) and no rights are claimed over it; what is claimed is
  which verse belongs to which day and the challenge written against it.

The code is more useful to other people than it is valuable to keep closed. The
content is the product.
