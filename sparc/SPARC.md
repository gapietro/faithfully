# Faithfully — SPARC Development Framework

> **HISTORICAL — the SPARC design phase, kept as a record.**
>
> Every document in this tree predates the shipped code. The stack line
> below still says CloudKit; v1 has none. For what is true now, read
> [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).


## Project Overview
**App:** Faithfully (iOS)
**Purpose:** Daily Christian action app that bridges hearing the Word and living it
**Stack:** Swift 5.9+ / SwiftUI / SwiftData / CloudKit
**Target:** iOS 17.0+

## SPARC Phases

### Phase 1: Specification ✅
**Location:** `sparc/specification/requirements.md`
**Contents:** 50+ testable requirements in GIVEN/WHEN/THEN format covering all features: daily challenges, translations, streaks, badges, calendar, notifications, settings, journal, persistence, and content.

**Also see:** `PRD.md` (full product requirements) and `challenges.json` (365-challenge content library)

### Phase 2: Pseudocode ✅
**Location:** `sparc/pseudocode/algorithms.md`
**Contents:** 9 core algorithms with full pseudocode:
1. Challenge scheduling (date-based, deterministic, year rotation)
2. Streak calculation (consecutive days with grace period)
3. Badge evaluation engine (3 layers: journey, streak, category)
4. Grace period logic (3-day window)
5. Notification scheduling (morning, evening, streak, badge)
6. Challenge completion flow (validation through CloudKit sync)
7. Journal share card generation
8. Calendar data provider
9. Year rotation algorithm (prime-offset for fresh pairings)

### Phase 3: Architecture ✅
**Location:** `sparc/architecture/system-design.md`
**Contents:** Complete system architecture including:
- High-level component diagram
- MVVM pattern with dependency flow
- Full SwiftData model definitions
- Service layer protocols
- View hierarchy tree
- Data flow diagram
- Xcode file structure
- Interface contracts between Views and ViewModels
- Technology decision matrix
- CloudKit schema

### Phase 4: Refinement (TDD Plan) ✅
**Location:** `sparc/refinement/tdd-plan.md`
**Contents:** 5-round TDD plan with specific test cases:
- Round 1: Models & Data (35 tests)
- Round 2: Services (20 tests)
- Round 3: ViewModels (25 tests)
- Round 4: Integration tests (8 tests)
- Round 5: UI tests (20 tests)
- Iteration strategy and coverage targets

### Phase 5: Completion ✅
**Location:** `sparc/completion/checklist.md`
**Contents:** 100+ item pre-launch checklist covering:
- Code quality, performance, content verification
- Badge assets, accessibility, dark mode
- Edge cases, notifications, CloudKit
- App Store preparation, TestFlight beta
- Pre-submission and post-launch monitoring

## How to Use with Claude Code

Point Claude Code at this project directory and give it this instruction:

```
Read the SPARC framework files in the /sparc directory, starting with SPARC.md.
Then read the PRD.md for full product context.

Build the Faithfully iOS app following the SPARC methodology:
1. Read specification/requirements.md for testable requirements
2. Read pseudocode/algorithms.md for core algorithm designs
3. Read architecture/system-design.md for project structure and data models
4. Follow refinement/tdd-plan.md using Red-Green-Refactor TDD
5. Use completion/checklist.md to verify launch readiness

Start with Round 1 of the TDD plan: Models & Data.
The challenge content library is in challenges.json (365 challenges, 3 Bible translations).
```

## Project Files

```
Faithfully/
├── SPARC.md                          ← You are here
├── PRD.md                            ← Full product requirements
├── challenges.json                   ← 365 challenges (master file)
├── challenges_001_073.json           ← Batch files (for reference)
├── challenges_074_146.json
├── challenges_147_219.json
├── challenges_220_292.json
├── challenges_293_365.json
└── sparc/
    ├── specification/
    │   └── requirements.md           ← Testable requirements (GIVEN/WHEN/THEN)
    ├── pseudocode/
    │   └── algorithms.md             ← Core algorithms
    ├── architecture/
    │   └── system-design.md          ← System design + file structure
    ├── refinement/
    │   └── tdd-plan.md               ← TDD test plan (5 rounds)
    └── completion/
        └── checklist.md              ← Launch readiness checklist
```
