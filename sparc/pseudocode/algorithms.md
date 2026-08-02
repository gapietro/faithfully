# SPARC Phase 2: Pseudocode
## Faithfully iOS App — Core Algorithms & Logic

### 1. Challenge Scheduling Algorithm

The central algorithm that determines which challenge appears on any given date for any given year.

```
function getChallengeForDate(date, yearOffset):
    // All users see the same challenge on the same date
    // Year offset rotates challenges so a calendar date pairs with a different
    // challenge each year — globally, for everyone at once (see getYearOffset)

    dayOfYear = date.dayOfYear()  // 1-365 (ignore leap day)

    if dayOfYear > 365:
        dayOfYear = 365  // Cap for leap years

    // Check if this date is the first Saturday of its month
    if isFirstSaturdayOfMonth(date):
        givingChallenges = challenges.filter(c => c.category == "giving")
        monthIndex = date.month - 1  // 0-11
        givingIndex = (monthIndex + yearOffset) % givingChallenges.count
        return givingChallenges[givingIndex]

    // For all other days, rotate through non-giving challenges
    nonGivingChallenges = challenges.filter(c => c.category != "giving")

    // Offset by year to prevent same calendar-date pairing
    index = (dayOfYear + (yearOffset * 47)) % nonGivingChallenges.count
    // 47 is prime, ensures good distribution across rotations

    return nonGivingChallenges[index]

function isFirstSaturdayOfMonth(date):
    return date.weekday == .saturday AND date.day <= 7

// CLEAN-001: this offset is measured from a fixed global epoch, never from the
// user's own start date. Deriving it per-user made two users with different
// enrollment dates see different challenges on the same civil date, which
// contradicts the shared-experience contract asserted three lines above.
function getYearOffset(date):
    return date.year - ROTATION_EPOCH_YEAR   // ROTATION_EPOCH_YEAR = 2026, frozen
```

### 2. Streak Calculation

```
function calculateStreak(completedChallenges, today):
    // Sort completions by date, most recent first
    completionDates = completedChallenges
        .map(c => c.completedDate.startOfDay)
        .unique()
        .sorted(descending)

    if completionDates.isEmpty:
        return 0

    streak = 0
    checkDate = today.startOfDay

    // If today is not completed, start checking from yesterday
    if not completionDates.contains(checkDate):
        checkDate = checkDate.addingDays(-1)

    // Count backwards through consecutive days
    while completionDates.contains(checkDate):
        streak += 1
        checkDate = checkDate.addingDays(-1)

    return streak
```

### 3. Badge Evaluation Engine

```
function evaluateBadges(user, completedChallenges):
    newBadges = []

    // --- Journey Badges ---
    totalCompleted = completedChallenges.count
    journeyThresholds = [
        (31, "5K"), (90, "10K"), (182, "Half Marathon"),
        (365, "Marathon"), (730, "Ultra")
    ]

    for (threshold, badgeName) in journeyThresholds:
        if totalCompleted >= threshold AND not user.hasBadge(badgeName):
            badge = awardBadge(user, badgeName, type: .journey)
            newBadges.append(badge)

    // --- Streak Badges ---
    currentStreak = calculateStreak(completedChallenges, today)
    streakThresholds = [
        (7, "Ember"), (30, "Flame"), (90, "Fire"),
        (180, "Furnace"), (365, "Unquenchable")
    ]

    for (threshold, badgeName) in streakThresholds:
        if currentStreak >= threshold AND not user.hasBadge(badgeName):
            badge = awardBadge(user, badgeName, type: .streak)
            newBadges.append(badge)

    // --- Category Badges ---
    categories = [prayer, scripture, obedience, giving, evangelism,
                  spiritualWarfare, discipline, worshipAndThanks, service, growth]

    categoryThresholds = [
        (10, "Beginner"), (25, "Devoted"), (50, "Warrior"), (100, "Master")
    ]

    for category in categories:
        categoryCount = completedChallenges.filter(c => c.category == category).count

        for (threshold, level) in categoryThresholds:
            badgeName = "\(category)_\(level)"
            if categoryCount >= threshold AND not user.hasBadge(badgeName):
                badge = awardBadge(user, badgeName, type: .category, category: category)
                newBadges.append(badge)

    return newBadges

function awardBadge(user, name, type, category = nil):
    badge = Badge(
        id: generateId(),
        name: name,
        type: type,
        category: category,
        threshold: lookupThreshold(name),
        earnedDate: Date.now
    )
    user.badges.append(badge)
    triggerCelebration(badge)
    scheduleNotification(badge)
    return badge
```

### 4. Grace Period Logic

```
function canCompleteChallenge(challengeDate, today):
    daysDifference = Calendar.current.dateComponents(
        [.day], from: challengeDate.startOfDay, to: today.startOfDay
    ).day

    // Can complete today's challenge
    if daysDifference == 0:
        return true

    // Can complete challenges from the last 3 days
    if daysDifference >= 1 AND daysDifference <= 3:
        return true

    // Cannot complete older challenges
    return false

function isGracePeriodCompletion(challengeDate, completionDate):
    return challengeDate.startOfDay != completionDate.startOfDay
```

### 5. Notification Scheduling

```
function scheduleNotifications(user):
    removeAllPendingNotifications()

    preferences = user.notificationPreferences

    // Morning challenge notification
    if preferences.morningEnabled:
        scheduleDailyNotification(
            id: "morning_challenge",
            time: preferences.morningTime,  // default 7:00 AM
            title: "Your Daily Walk",
            body: getTodayChallenge().title,
            repeats: true
        )

    // Evening reminder (only if not completed)
    if preferences.eveningEnabled:
        scheduleDailyNotification(
            id: "evening_reminder",
            time: preferences.eveningTime,  // default 8:00 PM
            title: "Don't Forget Your Walk",
            body: "You haven't completed today's challenge yet.",
            repeats: true,
            condition: { not isTodayCompleted() }
        )

    // Streak warning
    if preferences.streakWarningEnabled:
        currentStreak = calculateStreak()
        if currentStreak >= 7 AND not isTodayCompleted():
            scheduleNotification(
                id: "streak_warning",
                time: gracePeriodEnd.addingHours(-2),
                title: "Protect Your Streak!",
                body: "Don't break your \(currentStreak)-day streak!"
            )

function updateNotificationsOnCompletion():
    // Cancel evening reminder and streak warning for today
    removePendingNotification("evening_reminder_today")
    removePendingNotification("streak_warning_today")
```

### 6. Challenge Completion Flow

```
function completeChallenge(challenge, journalEntry = nil):
    // 1. Validate completion is allowed
    if not canCompleteChallenge(challenge.scheduledDate, today):
        throw GracePeriodExpiredError

    if isAlreadyCompleted(challenge):
        throw AlreadyCompletedError

    // 2. Create completion record
    completion = CompletedChallenge(
        id: UUID(),
        challengeId: challenge.id,
        completedDate: Date.now,
        journalEntry: journalEntry?.trimmed().prefix(2000)
    )

    // 3. Persist to SwiftData
    modelContext.insert(completion)
    try modelContext.save()

    // 4. Evaluate badges (may award new ones)
    allCompletions = fetchAllCompletions()
    newBadges = evaluateBadges(user, allCompletions)

    // 5. Update streak
    user.currentStreak = calculateStreak(allCompletions, today)

    // 6. Update notifications
    updateNotificationsOnCompletion()

    // 7. Sync to CloudKit (async, non-blocking)
    Task { await syncToCloudKit(completion) }

    // 8. Return result for UI
    return CompletionResult(
        completion: completion,
        newBadges: newBadges,
        currentStreak: user.currentStreak,
        totalCompleted: allCompletions.count
    )
```

### 7. Journal Share Card Generation

```
function generateShareCard(completion):
    challenge = lookupChallenge(completion.challengeId)

    card = ShareCardView(
        title: challenge.title,
        category: challenge.category,
        date: completion.completedDate.formatted(),
        scripture: challenge.scriptureReference,
        journalText: completion.journalEntry ?? "",
        streakCount: calculateStreak(),
        appBranding: "Faithfully"
    )

    // Render to UIImage for sharing
    image = card.renderToImage(size: CGSize(width: 1080, height: 1350))

    // Present iOS share sheet
    presentShareSheet(items: [image, card.shareText])
```

### 8. Calendar Data Provider

```
function getCalendarData(month, year):
    daysInMonth = Calendar.current.range(of: .day, in: .month, for: date).count

    calendarDays = []

    for day in 1...daysInMonth:
        date = makeDate(year, month, day)
        challenge = getChallengeForDate(date)
        completion = fetchCompletion(challengeId: challenge.id)

        calendarDay = CalendarDay(
            date: date,
            challenge: challenge,
            status: determineStatus(date, completion),
            journalEntry: completion?.journalEntry
        )
        calendarDays.append(calendarDay)

    return calendarDays

function determineStatus(date, completion):
    if date > today:
        return .future
    if completion != nil:
        return .completed
    if canCompleteChallenge(date, today):
        return .missedRecoverable
    return .missed
```

### 9. Year Rotation Algorithm (Detailed)

```
function buildYearSchedule(startDate, challenges):
    // Separate giving from non-giving
    givingPool = challenges.filter(c => c.category == "giving")
    mainPool = challenges.filter(c => c.category != "giving")

    yearOffset = getYearOffset(startDate)
    schedule = [:]  // date -> challenge mapping

    // Step 1: Pin giving challenges to first Saturdays
    firstSaturdays = getFirstSaturdaysOfYear(startDate.year)
    for (index, saturday) in firstSaturdays.enumerated():
        givingIndex = (index + yearOffset) % givingPool.count
        schedule[saturday] = givingPool[givingIndex]

    // Step 2: Fill remaining days from main pool
    // Use prime offset to ensure different year-to-year mapping
    allDays = getAllDaysOfYear(startDate.year)
    remainingDays = allDays.filter(d => not schedule.containsKey(d))

    for (index, day) in remainingDays.enumerated():
        mainIndex = (index + (yearOffset * 47)) % mainPool.count
        schedule[day] = mainPool[mainIndex]

    // Step 3: Validate no consecutive same-category
    // If violation found, swap with next available different-category challenge
    fixConsecutiveCategoryViolations(schedule)

    return schedule
```
