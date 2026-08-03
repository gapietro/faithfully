# SPARC Phase 1: Specification

> **HISTORICAL — SPARC design phase, Phase 1.**
>
> Kept as a record of how the app was originally specified. It is **not** a
> description of the code as it stands, and several decisions here were later
> reversed: CloudKit sync and the licensed ESV/NIV/NKJV translations were both dropped for v1.
>
> For what is true now, see [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md). For release status,
> see [`docs/ship/README.md`](../../docs/ship/README.md).


## Faithfully iOS App — Testable Requirements

### 1. Daily Challenge System

**REQ-DC-001: Challenge Display**
- GIVEN the app is launched
- WHEN the current date has a scheduled challenge
- THEN the home screen displays the challenge card with: title, category badge, scripture text (in the user's selected translation), challenge description, and reflection prompt
- ACCEPTANCE: Challenge card renders all 6 fields; missing fields fail validation

**REQ-DC-002: Same Challenge for All Users**
- GIVEN two users on the same calendar date
- WHEN both open the app
- THEN both see the identical challenge (same id, title, scripture, description)
- ACCEPTANCE: Challenge selection is deterministic based on date only

**REQ-DC-003: Challenge Rotation (Year 2+)**
- GIVEN a user has completed 365 days
- WHEN day 366 arrives
- THEN the challenge for that date is different from what was shown on day 1
- ACCEPTANCE: Year-offset algorithm produces non-repeating calendar-date pairings for at least 3 years

**REQ-DC-004: New Challenge Timing**
- GIVEN the user has configured a start-of-day time (default: midnight local)
- WHEN the clock passes that time
- THEN the previous challenge is archived and the new challenge appears
- ACCEPTANCE: Challenge transitions within 1 minute of configured time

**REQ-DC-005: Challenge Completion**
- GIVEN the user views today's challenge
- WHEN they tap "I Did It"
- THEN the challenge is marked complete with a timestamp
- AND an optional journal entry text field is presented
- ACCEPTANCE: CompletedChallenge record is persisted to SwiftData; journal field accepts 0-2000 characters

**REQ-DC-006: Grace Period**
- GIVEN the user missed a challenge within the last 3 days
- WHEN they view the calendar
- THEN missed days within the 3-day window show a "Complete" option
- AND days older than 3 days are locked
- ACCEPTANCE: Day N-1, N-2, N-3 are completable; N-4 and older are not

**REQ-DC-007: Giving Challenge Scheduling**
- GIVEN the challenge schedule for any month
- WHEN the first Saturday of that month arrives
- THEN the challenge for that day is category "giving"
- ACCEPTANCE: All 12 first-Saturdays in a year map to giving challenges

### 2. Bible Translation

**REQ-BT-001: Default Translation**
- GIVEN a new user (first launch)
- WHEN the app displays scripture
- THEN ESV text is shown
- ACCEPTANCE: Default preferredTranslation is .esv

**REQ-BT-002: Translation Selection**
- GIVEN the user opens Settings
- WHEN they select NIV or NKJV
- THEN all scripture text throughout the app updates to the selected translation
- ACCEPTANCE: Home screen, calendar details, and scripture library all reflect the chosen translation within 1 second

**REQ-BT-003: Translation Persistence**
- GIVEN the user selects NKJV and closes the app
- WHEN they reopen the app
- THEN NKJV is still selected
- ACCEPTANCE: Translation preference survives app termination and restart

### 3. Streak System

**REQ-STR-001: Streak Calculation**
- GIVEN the user has completed challenges on consecutive calendar days
- WHEN the streak count is calculated
- THEN it equals the number of consecutive completed days ending with today (or yesterday if today is not yet complete)
- ACCEPTANCE: Completing days 1,2,3 and missing day 4 resets streak to 0 on day 5

**REQ-STR-002: Grace Period Does Not Break Streak**
- GIVEN the user completes day 5's challenge on day 7 (within grace period)
- WHEN the streak is recalculated
- THEN day 5 counts as completed and the streak is maintained
- ACCEPTANCE: Late completion within 3 days preserves the streak chain

**REQ-STR-003: Streak Display**
- GIVEN the user has an active streak
- WHEN they view the home screen
- THEN the current streak count is visible
- ACCEPTANCE: Streak counter is always visible on home screen; updates in real-time on completion

### 4. Badge System

**REQ-BDG-001: Journey Badges**
- GIVEN the user has completed N total challenges
- WHEN N crosses a threshold (31, 90, 182, 365, 730)
- THEN the corresponding journey badge (5K, 10K, Half, Marathon, Ultra) is awarded
- AND a celebration animation plays
- ACCEPTANCE: Badge earned immediately upon threshold crossing; earnedDate is recorded

**REQ-BDG-002: Streak Badges**
- GIVEN the user has a consecutive streak of N days
- WHEN N crosses a threshold (7, 30, 90, 180, 365)
- THEN the corresponding streak badge (Ember, Flame, Fire, Furnace, Unquenchable) is awarded
- ACCEPTANCE: Badge earned at exact threshold; higher badge does not remove lower badge

**REQ-BDG-003: Category Badges**
- GIVEN the user has completed N challenges in a specific category
- WHEN N crosses a threshold (10, 25, 50, 100)
- THEN the corresponding category badge level (Beginner, Devoted, Warrior, Master) is awarded for that category
- ACCEPTANCE: Each of 10 categories has independent badge progression; counts persist across years

**REQ-BDG-004: Badge Display**
- GIVEN the user opens "My Journey"
- WHEN badge grid renders
- THEN earned badges show full color with earnedDate; unearned badges show grayed silhouettes with progress bars
- ACCEPTANCE: All badge types (journey, streak, category) displayed; progress bars are accurate

### 5. Calendar

**REQ-CAL-001: Calendar View**
- GIVEN the user opens the Calendar tab
- WHEN the current month displays
- THEN completed days show colored fill; missed days show empty/dimmed; future days are neutral
- ACCEPTANCE: Visual state is correct for all days in the month

**REQ-CAL-002: Day Detail**
- GIVEN the user taps a past day on the calendar
- WHEN the detail view opens
- THEN it shows: challenge title, category, scripture, description, completion status, and journal entry (if any)
- ACCEPTANCE: All fields render; journal entry shows "No entry" if empty

### 6. Notifications

**REQ-NOT-001: Morning Notification**
- GIVEN the user has morning notifications enabled (default: 7:00 AM)
- WHEN the configured time arrives
- THEN a push notification appears with today's challenge title
- ACCEPTANCE: Notification fires within 1 minute of configured time

**REQ-NOT-002: Evening Reminder**
- GIVEN the user has evening reminders enabled AND has not completed today's challenge
- WHEN the configured time arrives (default: 8:00 PM)
- THEN a reminder notification appears
- ACCEPTANCE: No notification if challenge is already completed

**REQ-NOT-003: Streak Warning**
- GIVEN the user has an active streak of 7+ days AND has not completed today's challenge
- WHEN 2 hours before the end of the grace period
- THEN a "Don't break your streak!" notification fires
- ACCEPTANCE: Only fires if streak >= 7 and challenge incomplete

**REQ-NOT-004: Badge Celebration**
- GIVEN the user earns a new badge
- WHEN the badge is awarded
- THEN a notification is sent (if badge notifications are enabled)
- ACCEPTANCE: Notification includes badge name and type

### 7. Settings

**REQ-SET-001: Notification Preferences**
- GIVEN the user opens Settings
- WHEN they toggle individual notification types (morning, evening, streak, badge)
- THEN each preference is persisted independently
- ACCEPTANCE: Toggling one does not affect others; preferences survive restart

**REQ-SET-002: Bible Translation Picker**
- GIVEN the user opens Settings
- WHEN they tap the Translation option
- THEN they see ESV, NIV, NKJV as options with current selection highlighted
- ACCEPTANCE: Selection immediately updates preferredTranslation

**REQ-SET-003: Dark Mode**
- GIVEN the user toggles dark mode in Settings
- WHEN the toggle changes
- THEN the entire app UI switches to dark/light theme
- ACCEPTANCE: All screens respect the theme; respects system setting if set to "System"

### 8. Journal

**REQ-JRN-001: Journal Entry**
- GIVEN the user completes a challenge
- WHEN they enter text in the journal field
- THEN the text is saved as part of the CompletedChallenge record
- ACCEPTANCE: Text persists across app restarts; max 2000 characters

**REQ-JRN-002: Journal Sharing**
- GIVEN the user views a past journal entry
- WHEN they tap "Share"
- THEN a styled share card is generated and the iOS share sheet appears
- ACCEPTANCE: Share card includes challenge title, date, scripture reference, and journal text

**REQ-JRN-003: Journal Search**
- GIVEN the user has multiple journal entries
- WHEN they search in the My Journey screen
- THEN entries matching the search text are displayed
- ACCEPTANCE: Search matches against journal text, challenge title, and scripture reference

### 9. Data & Persistence

**REQ-DAT-001: Offline Operation**
- GIVEN the device has no internet connection
- WHEN the user opens the app
- THEN all functionality works (challenge display, completion, badges, calendar)
- ACCEPTANCE: Full feature set available offline; zero network requests required

**REQ-DAT-002: Data Persistence**
- GIVEN the user has completed challenges and earned badges
- WHEN the app is force-quit and restarted
- THEN all data is intact
- ACCEPTANCE: SwiftData store survives app termination

**REQ-DAT-003: CloudKit Sync**
- GIVEN the user has iCloud enabled
- WHEN they complete a challenge on one device
- THEN the completion syncs to other devices via CloudKit
- ACCEPTANCE: Sync occurs within 30 seconds on Wi-Fi; conflict resolution favors most recent write

### 10. Content

**REQ-CON-001: Challenge Library**
- GIVEN the app is installed
- WHEN the challenge schedule is loaded
- THEN 365 challenges are available with all required fields (id, title, category, scripture in 3 translations, description, reflection prompt, difficulty)
- ACCEPTANCE: JSON validation passes for all 365 entries; zero null fields

**REQ-CON-002: Scripture Accuracy**
- GIVEN any challenge displays scripture
- WHEN the ESV, NIV, or NKJV text is shown
- THEN it matches the canonical text of that translation for the given reference
- ACCEPTANCE: Spot-check 20 random challenges against published Bible text

### 11. Non-Functional Requirements

**REQ-NF-001: Launch Time**
- App launches to home screen in under 2 seconds on iPhone 12 or newer
- ACCEPTANCE: Measured via Instruments; p95 < 2s

**REQ-NF-002: Minimum iOS Version**
- App requires iOS 17.0 or later
- ACCEPTANCE: Xcode deployment target set to 17.0; builds and runs on iOS 17 simulator

**REQ-NF-003: No Account Required**
- First-time users can use all features without creating an account, entering an email, or logging in
- ACCEPTANCE: Full walkthrough from install to Day 1 completion with zero auth screens

**REQ-NF-004: Accessibility**
- All screens support Dynamic Type and VoiceOver
- ACCEPTANCE: VoiceOver reads all interactive elements; text scales with system font size setting
