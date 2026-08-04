# Every quality gate, runnable identically on a laptop and in CI.
#
# Before this existed, verification was a past local event recorded in prose:
# another engineer could not reproduce the claimed gate from the repository
# alone, and swiftlint could not run at all. `make ci` is now the whole contract.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

TOOLS := .tools
SWIFTLINT := $(TOOLS)/swiftlint
XCODEGEN := $(TOOLS)/xcodegen

PROJECT := Faithfully.xcodeproj
SCHEME := Faithfully
# Resolved once per make invocation, preferring the pinned device and falling
# back to any available iPhone. Override with `make DESTINATION='...'`.
DESTINATION ?= $(shell ./scripts/resolve_simulator.sh)
ARCHIVE_PATH := build/Faithfully.xcarchive
RESULT_BUNDLE := build/TestResults.xcresult

# Aggregate line coverage floor for Services and ViewModels — the logic the app
# is actually made of. Set just below the measured value so a real regression
# trips it while ordinary churn does not.
COVERAGE_MIN := 90

.PHONY: help
help:
	@echo "make bootstrap        Install pinned tools into .tools/"
	@echo "make generate         Regenerate the Xcode project from project.yml"
	@echo "make verify-project   Fail if the committed project differs from project.yml"
	@echo "make validate-content Validate the 365 bundled challenges"
	@echo "make lint             swiftlint --strict"
	@echo "make test             Unit and integration tests, with coverage"
	@echo "make coverage         Enforce the Services/ViewModels coverage floor"
	@echo "make ui-test          Simulator UI tests"
	@echo "make accessibility    Apple's accessibility audit over every screen"
	@echo "make analyze          Xcode static analyzer"
	@echo "make strict-concurrency  Build under complete concurrency checking"
	@echo "make archive          Release archive for a generic iOS device"
	@echo "make ci               Everything above, in order"

$(SWIFTLINT) $(XCODEGEN):
	./scripts/bootstrap.sh

.PHONY: bootstrap
bootstrap:
	./scripts/bootstrap.sh

.PHONY: generate
generate: $(XCODEGEN)
	$(XCODEGEN) generate

# The generated project is committed, so a change to project.yml that nobody
# regenerated would otherwise be invisible until someone's build diverged.
.PHONY: verify-project
verify-project: generate
	@git diff --exit-code -- $(PROJECT)/project.pbxproj \
		|| (echo "ERROR: $(PROJECT) is out of date. Run 'make generate' and commit." >&2; exit 1)
	@echo "OK: generated project matches project.yml"

.PHONY: validate-content
validate-content:
	python3 scripts/validate_challenges.py

.PHONY: lint
lint: $(SWIFTLINT)
	$(SWIFTLINT) lint --strict

.PHONY: test
test:
	rm -rf $(RESULT_BUNDLE)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-enableCodeCoverage YES -resultBundlePath $(RESULT_BUNDLE) \
		-only-testing:FaithfullyTests test

.PHONY: coverage
coverage:
	@./scripts/check_coverage.sh $(RESULT_BUNDLE) $(COVERAGE_MIN)

# The audit class is skipped here because `accessibility` below owns it. Without
# the skip it ran twice per `make ci` — the same ten tests, same pinned date,
# same scenarios — costing about four minutes and doubling the exposure to the
# flake handled below (#98).
.PHONY: ui-test
ui-test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:FaithfullyUITests \
		-skip-testing:FaithfullyUITests/AccessibilityAuditTests test

# Retries a failed audit test once, in a fresh process.
#
# The audit machinery reports `-56 "Audit failed to complete in time"` when the
# simulator stalls mid-audit. Measured over sixteen hosted `macos-26` suite
# runs, that happens on roughly a third of them, and it is not a statement
# about any screen: the audit's own duration (separated from launch and
# navigation) runs 2.0s median on onboarding to 7.8s on the calendar day
# detail, a 23.8s audit passed while a ~19s one failed, and the screen it lands
# on varies. It is an inner request going unanswered, so the screen that makes
# the most requests tends to be hit first (#97).
#
# Neither of the obvious fixes exists. `performAccessibilityAudit` takes audit
# types and an issue handler and nothing else — there is no timeout to raise —
# and it is declared on `XCUIApplication` only, so the audit cannot be scoped to
# a subtree to walk less.
#
# Retrying *inside* the test was tried first and made things worse: of three
# real timeouts across ten runs, one was absorbed, one timed out again after
# 133s, and one killed the test runner so the test reported neither pass nor
# fail. The stall outlives the attempt, so re-asking the same wedged automation
# session is the wrong move. `-test-repetition-relaunch-enabled YES` is the part
# that matters here: the retry gets a new process and a fresh app launch, which
# is the only thing that escapes a stalled session.
#
# This does not soften the gate. A real accessibility finding is deterministic,
# so it fails both iterations and still goes red — it just takes twice as long
# to say so. `-test-iterations 2` bounds it to exactly one retry.
.PHONY: accessibility
accessibility:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:FaithfullyUITests/AccessibilityAuditTests \
		-retry-tests-on-failure -test-iterations 2 \
		-test-repetition-relaunch-enabled YES test

.PHONY: analyze
analyze:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' analyze

.PHONY: strict-concurrency
strict-concurrency:
	@./scripts/check_strict_concurrency.sh

.PHONY: archive
archive:
	rm -rf $(ARCHIVE_PATH)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH) CODE_SIGNING_ALLOWED=NO archive
	@./scripts/check_archive.sh $(ARCHIVE_PATH)

.PHONY: ci
ci: bootstrap verify-project validate-content lint test coverage ui-test accessibility analyze strict-concurrency archive
	@echo
	@echo "All checks passed."
