# SPARC Phase 4: Refinement

> **HISTORICAL — SPARC design phase, Phase 4.**
>
> Kept as a record of how the app was originally specified. It is **not** a
> description of the code as it stands, and several decisions here were later
> reversed: the suite has grown well beyond this plan; see the Makefile for the checks that actually run.
>
> For what is true now, see [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md). For release status,
> see [`docs/ship/README.md`](../../docs/ship/README.md).


## Faithfully iOS App — Test-Driven Development Plan

### TDD Cycle: Red → Green → Refactor

For each component below, Claude Code should:
1. **RED:** Write the failing test first
2. **GREEN:** Write the minimum code to make it pass
3. **REFACTOR:** Clean up while keeping tests green

### Test Priority Order

Build in this order. Each layer depends on the one before it.

---

## Round 1: Models & Data (No UI)

### 1.1 ChallengeLoader Tests
```
Test: loads 365 challenges from bundled JSON
Test: all challenges have non-empty required fields
Test: all challenge IDs are unique
Test: all days 1-365 are represented
Test: category enum maps correctly for all challenges
Test: difficulty enum maps correctly
Test: scriptureText(for:) returns correct translation
```

### 1.2 ChallengeScheduler Tests
```
Test: returns a challenge for any valid date
Test: same date always returns same challenge (deterministic)
Test: two different dates return different challenges
Test: first Saturday of each month returns giving category
Test: non-first-Saturday never returns giving category
Test: year 1 and year 2 return different challenges for same calendar date
Test: no two consecutive days have same category
Test: all 365 days of a year are covered
```

### 1.3 StreakCalculation Tests
```
Test: zero completions returns streak of 0
Test: only today completed returns streak of 1
Test: 3 consecutive days ending today returns streak of 3
Test: gap yesterday breaks streak (returns 0 or 1 depending on today)
Test: today not yet completed, yesterday completed, returns streak counting from yesterday
Test: grace period completion (day completed late) maintains streak
Test: 365 consecutive days returns streak of 365
```

### 1.4 GracePeriod Tests
```
Test: today's challenge is completable
Test: yesterday's challenge is completable
Test: 3-days-ago challenge is completable
Test: 4-days-ago challenge is NOT completable
Test: future challenge is NOT completable
Test: already-completed challenge is NOT completable
Test: grace period completion records correct scheduledDate vs completedDate
```

### 1.5 BadgeEvaluation Tests
```
Test: 0 completions earns no badges
Test: 31 completions earns 5K journey badge
Test: 90 completions earns 10K (and still has 5K)
Test: 365 completions earns Marathon
Test: 7-day streak earns Ember
Test: 30-day streak earns Flame (and still has Ember)
Test: 10 prayer completions earns Prayer Beginner
Test: 25 prayer completions earns Prayer Devoted (and keeps Beginner)
Test: same badge is not awarded twice
Test: badge earnedDate is recorded correctly
Test: evaluateAndAward returns only NEW badges (not previously earned)
```

---

## Round 2: Services

### 2.1 ChallengeService Tests
```
Test: loadChallenges returns 365 items
Test: challengeForDate returns correct challenge
Test: completeChallenge creates CompletedChallenge record
Test: completeChallenge with journal saves journal text
Test: completeChallenge throws on expired grace period
Test: completeChallenge throws on already-completed challenge
Test: completeChallenge triggers badge evaluation
Test: fetchCompletions returns correct records for date range
Test: calculateStreak delegates to streak algorithm correctly
```

### 2.2 BadgeService Tests
```
Test: allBadgeDefinitions returns all journey + streak + category badges
Test: progress for unearned badge shows correct numerator/denominator
Test: progress for earned badge shows 100%
Test: earnedBadges returns all badges from SwiftData
Test: evaluateAndAward persists new badges
Test: evaluateAndAward does not duplicate existing badges
```

### 2.3 NotificationService Tests
```
Test: requestPermission calls UNUserNotificationCenter
Test: scheduleAllNotifications creates morning notification at configured time
Test: scheduleAllNotifications creates evening notification at configured time
Test: cancelTodayReminders removes pending today-specific notifications
Test: scheduleStreakWarning creates notification only if streak >= 7
Test: notifications respect user's enabled/disabled preferences
```

---

## Round 3: ViewModels

### 3.1 DailyWalkViewModel Tests
```
Test: init loads today's challenge
Test: isCompleted reflects actual completion state
Test: currentStreak reflects calculated streak
Test: complete() calls ChallengeService.completeChallenge
Test: complete() updates isCompleted to true
Test: complete() updates currentStreak
Test: complete() sets newBadges if badges awarded
Test: complete() sets showCelebration to true if badges awarded
Test: translation change updates scripture text
```

### 3.2 CalendarViewModel Tests
```
Test: calendarDays contains correct number of days for current month
Test: completed days show .completed status
Test: missed days within grace period show .missedRecoverable
Test: missed days outside grace period show .missed
Test: future days show .future
Test: nextMonth advances by one month
Test: previousMonth goes back one month
Test: selectDay sets selectedDay
Test: completeGracePeriod calls ChallengeService and updates calendar
```

### 3.3 JourneyViewModel Tests
```
Test: totalCompleted reflects actual count
Test: currentStreak reflects calculated streak
Test: journeyBadge shows correct progress toward next distance badge
Test: allBadges includes all earned and unearned badges
Test: journalEntries loaded in reverse chronological order
Test: searchJournal filters by text content
Test: searchJournal filters by challenge title
Test: shareEntry generates share card data
```

### 3.4 SettingsViewModel Tests
```
Test: init loads all preferences from UserProfile
Test: updateTranslation persists to SwiftData
Test: updateTranslation immediately reflects in published property
Test: toggle notifications updates preferences
Test: dark mode change persists
```

---

## Round 4: Integration Tests

### 4.1 Full Completion Flow
```
Test: launch app → view challenge → complete → verify persistence → verify streak → verify badge
Test: complete 31 challenges → 5K badge appears in Journey view
Test: miss a day → streak resets → grace period allows recovery
Test: complete challenge with journal → journal appears in timeline
```

### 4.2 Year Transition
```
Test: day 365 completion → day 366 shows different challenge than day 1
Test: giving challenges on first Saturdays persist across year boundary
```

### 4.3 Data Integrity
```
Test: force-quit and relaunch preserves all data
Test: 1000 completions does not degrade performance
Test: JSON loading handles malformed data gracefully
```

---

## Round 5: UI Tests (XCUITest)

### 5.1 Home Screen
```
Test: challenge card displays on launch
Test: "I Did It" button is tappable
Test: completion triggers animation
Test: streak counter is visible
Test: yesterday's challenge is collapsed
```

### 5.2 Calendar
```
Test: month grid renders all days
Test: tapping a day opens detail
Test: completed days show colored indicator
Test: grace period days show completion button
```

### 5.3 Journey
```
Test: badge grid renders
Test: earned badges show in color
Test: progress bars are visible on unearned badges
Test: journal entries display
Test: search field filters entries
```

### 5.4 Settings
```
Test: translation picker shows 3 options
Test: changing translation updates home screen
Test: notification toggles persist
Test: dark mode toggle works
```

### 5.5 Onboarding
```
Test: first launch shows onboarding
Test: second launch skips onboarding
Test: notification permission request appears
Test: completing onboarding shows first challenge
```

---

## Refinement Iteration Strategy

After each round, review:
1. **Test coverage:** Aim for 90%+ on Services and ViewModels
2. **Performance:** Profile with Instruments after Round 4
3. **Code quality:** Run SwiftLint, fix all warnings
4. **Accessibility:** Verify VoiceOver on all screens after Round 5

Repeat Red-Green-Refactor until all specifications from Phase 1 pass.
