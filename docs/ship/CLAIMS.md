# Product claims and the tests that hold them

Status: current. Introduced by CLEAN-011 (audit tracker #39, issue #50).

Every user-facing promise the App Store listing or the PRD makes, and the
executable check that proves it still true. A claim with no check is listed as
such rather than quietly assumed — the audit found the listing promising
behaviour the code did not have, and nothing would have caught it.

**Adding a public claim means adding a row here.** If you cannot name the check,
the claim is not ready to publish.

## Claims with automated proof

| Claim | Where it is made | Proof |
|---|---|---|
| "the same one every user receives" — one challenge a day, identical for everyone on a given date | `APP_STORE_LISTING.md`, PRD §6.3 | `ChallengeServiceTests.testEnrollmentDateDoesNotAffectWhichChallengeADateResolvesTo` — 5 enrollment dates 2020–2029, 16 dates across 4 years |
| Challenges rotate each calendar year so a returning user does not repeat a date | PRD §11.4 | `ChallengeServiceTests.testAdjacentCalendarYearsRotateToDifferentChallenges` |
| The schedule is deterministic and needs no server | PRD §6.3 | `ChallengeServiceTests.testRotationIsStableAcrossServiceInstances`; no network code exists |
| Giving challenges fall on the first Saturday of each month | PRD §11.6 | `ChallengeSchedulerTests.testFirstSaturdayOfEachMonthReturnsGivingCategory` |
| A missed day can be completed for up to three days | PRD §11.5 | `GracePeriodTests`; `CalendarUITests.testGraceDayOffersCompletionAndRecordsIt` |
| Days before you joined are not counted against you | product behaviour (CLEAN-002) | `ChallengeServiceEnrollmentTests`; `AppEnvironmentTests.testNewUserSeesNoMissedDaysOnTheirFirstDay` |
| Journal entries are private and stored on device | `PRIVACY_POLICY.md` | No network code; journal text is never logged. Store file protection is verified manually — see #54 |
| A reflection you write is saved whole | product behaviour (CLEAN-003) | `ChallengeServiceJournalTests` (1,999 / 2,000 / 2,001 chars); `HomeScreenUITests.testJournalTextIsSavedAndVisibleInTheJournal` |
| You can change or remove a reflection you wrote | product behaviour | `JournalEditTests`; `JournalEditUITests.testEditingAnEntryPersistsAcrossRelaunch`, `...testDeletingAnEntryRemovesItButKeepsTheDayCompleted` |
| Removing a reflection does not affect your streak or badges | delete confirmation copy | `JournalEditTests.testEditingDoesNotMoveStreakTotalOrBadges` |
| Your streak reflects consecutive days completed | PRD §7 | `StreakCalculationTests`; `CivilDayTests.testStreakSurvivesATimeZoneChange` and `testStreakBreaksOnAGenuinelyMissedDay` |
| Badges are earned at the stated thresholds | PRD §8 | `BadgeEvaluationTests`, `BadgeServiceTests`; `JourneyUITests.testEarnedBadgesAreDistinguishableFromUnearnedOnes` |
| Scripture is shown in your chosen translation | Settings UI | `SettingsUITests.testChangingTranslationChangesTheScriptureShownAndPersists` |
| Scripture text is public-domain WEB and KJV | `TRANSLATION_LICENSING.md` | `scripts/validate_challenges.py` (in CI); independent spot check in `../content/SCRIPTURE_SPOT_CHECK_PD.md` |
| Your data survives closing the app | implicit | `IntegrationTests.testForceQuitAndRelaunchPreservesAllData`; several UI tests assert across a relaunch |
| iPhone app | PRD §2 | `scripts/check_archive.sh` asserts the archive declares iPhone-only |

## Claims verified by hand, not by CI

Honest list. Each has an open issue; none may be treated as proven until it is
closed.

| Claim | Why CI cannot prove it | Issue |
|---|---|---|
| Works correctly on a real device | The simulator is not a device | #52 |
| Usable with VoiceOver and large Dynamic Type | Needs a device-level accessibility pass | #55 |
| Launches and scrolls acceptably | Needs measurement on representative hardware | #56 |
| Journal data is protected at rest and behaves as described on backup and delete | Needs on-device inspection of the file protection class | #54 |
| Passes App Store validation, privacy manifest included | Needs App Store Connect credentials | #52 |

## Claims deliberately not made

- **No sync, no cloud backup.** v1 is local-only. The listing must not imply
  otherwise — see [`CLOUDKIT_DECISION.md`](CLOUDKIT_DECISION.md).
- **No ESV, NIV, or NKJV.** Licensed translations are out of scope for v1.
- **No iPad experience.** The archive declares iPhone-only.
