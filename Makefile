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

.PHONY: ui-test
ui-test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:FaithfullyUITests test

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
ci: bootstrap verify-project validate-content lint test coverage ui-test analyze strict-concurrency archive
	@echo
	@echo "All checks passed."
