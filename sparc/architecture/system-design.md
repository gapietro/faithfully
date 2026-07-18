# SPARC Phase 3: Architecture
## Faithfully iOS App — System Design

### 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │DailyWalk │ │ Calendar │ │ Journey  │ │Settings│ │
│  │  View    │ │   View   │ │   View   │ │  View  │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ │
│       │             │            │            │      │
├───────┼─────────────┼────────────┼────────────┼──────┤
│       ▼             ▼            ▼            ▼      │
│                  ViewModels (ObservableObject)        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │DailyWalk │ │ Calendar │ │ Journey  │ │Settings│ │
│  │ViewModel │ │ ViewModel│ │ ViewModel│ │ViewModel│ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ │
│       │             │            │            │      │
├───────┼─────────────┼────────────┼────────────┼──────┤
│       ▼             ▼            ▼            ▼      │
│                    Service Layer                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │  Challenge    │ │    Badge     │ │ Notification │ │
│  │   Service     │ │   Service    │ │   Service    │ │
│  └──────┬───────┘ └──────┬───────┘ └──────────────┘ │
│         │                │                           │
├─────────┼────────────────┼───────────────────────────┤
│         ▼                ▼                           │
│              Persistence Layer                        │
│  ┌──────────────────────────────────────────────┐   │
│  │              SwiftData ModelContext            │   │
│  │  ┌──────────┐ ┌───────────┐ ┌─────────────┐ │   │
│  │  │   User   │ │ Completed │ │    Badge     │ │   │
│  │  │          │ │ Challenge │ │              │ │   │
│  │  └──────────┘ └───────────┘ └─────────────┘ │   │
│  └──────────────────────┬───────────────────────┘   │
│                         │                           │
│  ┌──────────────────────┼───────────────────────┐   │
│  │               CloudKit Sync                   │   │
│  └───────────────────────────────────────────────┘   │
│                                                      │
│  ┌───────────────────────────────────────────────┐   │
│  │          challenges.json (Bundled)             │   │
│  │          365 challenges + 3 translations       │   │
│  └───────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

### 2. Architecture Pattern: MVVM

**Why MVVM:**
- Native SwiftUI pattern (Views + ObservableObject)
- Clean separation: Views are pure UI, ViewModels handle logic, Services handle data
- Testable: ViewModels can be unit tested without UI
- Reactive: @Published properties drive automatic UI updates

**Dependency Flow:**
```
Views → ViewModels → Services → SwiftData/CloudKit
         ↓
    Models (shared)
```

Views never access Services directly. ViewModels are the single source of truth for each screen.

### 3. Data Models (SwiftData)

```swift
// ── Enums ──

enum ChallengeCategory: String, Codable, CaseIterable {
    case prayer, scripture, obedience, giving, evangelism
    case spiritualWarfare, discipline, worshipAndThanks, service, growth
}

enum BibleTranslation: String, Codable {
    case esv, niv, nkjv
}

enum BadgeType: String, Codable {
    case journey, streak, category
}

enum Difficulty: String, Codable {
    case standard, challenging, stretch
}

// ── Persisted Models (SwiftData) ──

@Model class UserProfile {
    var id: UUID
    var displayName: String
    var startDate: Date
    var preferredTranslation: BibleTranslation  // default: .esv
    var morningNotificationTime: Date           // default: 7:00 AM
    var eveningReminderTime: Date               // default: 8:00 PM
    var morningNotificationsEnabled: Bool        // default: true
    var eveningRemindersEnabled: Bool            // default: true
    var streakWarningsEnabled: Bool              // default: true
    var badgeNotificationsEnabled: Bool          // default: true
    var darkModePreference: DarkModePreference   // system/light/dark
}

@Model class CompletedChallenge {
    var id: UUID
    var challengeId: String          // maps to DailyChallenge.id
    var challengeCategory: String    // denormalized for badge counting
    var completedDate: Date
    var scheduledDate: Date          // the date the challenge was assigned
    var journalEntry: String?
}

@Model class EarnedBadge {
    var id: UUID
    var badgeName: String
    var badgeType: BadgeType
    var category: ChallengeCategory? // only for category badges
    var threshold: Int
    var earnedDate: Date
}

// ── Non-Persisted Model (loaded from JSON) ──

struct DailyChallenge: Codable, Identifiable {
    let id: String
    let day: Int
    let title: String
    let category: ChallengeCategory
    let scriptureReference: String
    let scriptureTextESV: String
    let scriptureTextNIV: String
    let scriptureTextNKJV: String
    let challengeDescription: String
    let reflectionPrompt: String
    let difficulty: Difficulty

    func scriptureText(for translation: BibleTranslation) -> String {
        switch translation {
        case .esv: return scriptureTextESV
        case .niv: return scriptureTextNIV
        case .nkjv: return scriptureTextNKJV
        }
    }
}
```

### 4. Service Layer

```swift
// ── ChallengeService ──
// Owns: challenge loading, scheduling, completion logic
protocol ChallengeServiceProtocol {
    func loadChallenges() -> [DailyChallenge]
    func challengeForDate(_ date: Date) -> DailyChallenge
    func completeChallenge(_ challenge: DailyChallenge, journal: String?) throws -> CompletionResult
    func canComplete(_ challenge: DailyChallenge) -> Bool
    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge]
    func calculateStreak() -> Int
}

// ── BadgeService ──
// Owns: badge evaluation, awarding, progress calculation
protocol BadgeServiceProtocol {
    func evaluateAndAward() -> [EarnedBadge]  // returns newly earned badges
    func allBadgeDefinitions() -> [BadgeDefinition]
    func progress(for badge: BadgeDefinition) -> BadgeProgress
    func earnedBadges() -> [EarnedBadge]
}

// ── NotificationService ──
// Owns: scheduling, canceling, updating push notifications
protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func scheduleAllNotifications()
    func cancelTodayReminders()
    func scheduleStreakWarning(streak: Int)
    func scheduleBadgeCelebration(_ badge: EarnedBadge)
}

// ── PersistenceService ──
// Owns: SwiftData ModelContext, CloudKit sync coordination
protocol PersistenceServiceProtocol {
    var modelContext: ModelContext { get }
    func save() throws
    func syncToCloudKit() async
}
```

### 5. View Hierarchy

```
FaithfullyApp (App entry point)
├── ContentView (TabView)
│   ├── Tab 1: DailyWalkView
│   │   ├── ChallengeCardView (today's challenge)
│   │   │   ├── CategoryBadgeView
│   │   │   ├── ScriptureTextView
│   │   │   └── CompletionButtonView
│   │   ├── CompletionSheetView (journal entry + celebration)
│   │   ├── StreakCounterView
│   │   └── YesterdayChallengeView (collapsed)
│   │
│   ├── Tab 2: CalendarView
│   │   ├── MonthGridView
│   │   ├── DayDetailView
│   │   └── CompletionSheetView (for grace period completions)
│   │
│   ├── Tab 3: JourneyView
│   │   ├── JourneyProgressRingView (distance badge)
│   │   ├── BadgeGridView
│   │   │   ├── BadgeCellView (earned: full color)
│   │   │   └── BadgeCellView (unearned: silhouette + progress)
│   │   └── JournalTimelineView
│   │       └── JournalEntryView
│   │           └── ShareCardView
│   │
│   └── Tab 4: SettingsView
│       ├── TranslationPickerView
│       ├── NotificationSettingsView
│       ├── DarkModeToggleView
│       └── AboutView
│
└── OnboardingView (first launch only)
    ├── WelcomeView
    ├── NotificationPermissionView
    └── FirstChallengeView
```

### 6. Data Flow Diagram

```
App Launch
    │
    ├── Load challenges.json → ChallengeService.challenges[]
    ├── Load UserProfile from SwiftData
    ├── Load CompletedChallenges from SwiftData
    ├── Load EarnedBadges from SwiftData
    │
    ▼
DailyWalkViewModel
    │
    ├── challengeForDate(today) → DailyChallenge
    ├── isCompleted(today) → Bool
    ├── currentStreak → Int
    │
    ▼ (user taps "I Did It")
    │
    ├── ChallengeService.completeChallenge()
    │   ├── Persist CompletedChallenge
    │   ├── BadgeService.evaluateAndAward()
    │   │   └── Persist new EarnedBadge (if any)
    │   ├── NotificationService.cancelTodayReminders()
    │   └── PersistenceService.syncToCloudKit()
    │
    └── Update UI (streak, completion state, badge celebration)
```

### 7. File Structure (Xcode Project)

```
Faithfully/
├── FaithfullyApp.swift                 // @main App entry
├── ContentView.swift                    // TabView root
│
├── Models/
│   ├── DailyChallenge.swift            // Codable struct (from JSON)
│   ├── UserProfile.swift               // @Model (SwiftData)
│   ├── CompletedChallenge.swift        // @Model (SwiftData)
│   ├── EarnedBadge.swift               // @Model (SwiftData)
│   ├── BadgeDefinition.swift           // Static badge catalog
│   ├── Enums/
│   │   ├── ChallengeCategory.swift
│   │   ├── BibleTranslation.swift
│   │   ├── BadgeType.swift
│   │   └── Difficulty.swift
│   └── Results/
│       ├── CompletionResult.swift
│       └── BadgeProgress.swift
│
├── Services/
│   ├── ChallengeService.swift
│   ├── BadgeService.swift
│   ├── NotificationService.swift
│   └── PersistenceService.swift
│
├── ViewModels/
│   ├── DailyWalkViewModel.swift
│   ├── CalendarViewModel.swift
│   ├── JourneyViewModel.swift
│   └── SettingsViewModel.swift
│
├── Views/
│   ├── DailyWalk/
│   │   ├── DailyWalkView.swift
│   │   ├── ChallengeCardView.swift
│   │   ├── CategoryBadgeView.swift
│   │   ├── ScriptureTextView.swift
│   │   ├── CompletionButtonView.swift
│   │   ├── CompletionSheetView.swift
│   │   ├── StreakCounterView.swift
│   │   └── YesterdayChallengeView.swift
│   ├── Calendar/
│   │   ├── CalendarView.swift
│   │   ├── MonthGridView.swift
│   │   └── DayDetailView.swift
│   ├── Journey/
│   │   ├── JourneyView.swift
│   │   ├── JourneyProgressRingView.swift
│   │   ├── BadgeGridView.swift
│   │   ├── BadgeCellView.swift
│   │   ├── JournalTimelineView.swift
│   │   ├── JournalEntryView.swift
│   │   └── ShareCardView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── TranslationPickerView.swift
│   │   ├── NotificationSettingsView.swift
│   │   └── AboutView.swift
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── WelcomeView.swift
│   │   ├── NotificationPermissionView.swift
│   │   └── FirstChallengeView.swift
│   └── Shared/
│       ├── BadgeCelebrationView.swift
│       └── LoadingView.swift
│
├── Resources/
│   ├── challenges.json                  // 365 challenges, 3 translations
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   ├── Colors/                     // Design system colors
│   │   ├── Badges/                     // Custom Recraft.ai badge art
│   │   │   ├── journey/               // 5K, 10K, Half, Marathon, Ultra
│   │   │   ├── streak/                // Ember, Flame, Fire, Furnace, Unquenchable
│   │   │   └── category/              // 10 categories x 4 levels = 40 badges
│   │   └── CategoryIcons/             // 10 category line-art icons
│   └── Localizable.strings
│
├── Utilities/
│   ├── DateExtensions.swift
│   ├── Constants.swift
│   └── ChallengeScheduler.swift        // Year rotation algorithm
│
└── Tests/
    ├── ChallengeServiceTests.swift
    ├── BadgeServiceTests.swift
    ├── StreakCalculationTests.swift
    ├── GracePeriodTests.swift
    ├── ChallengeSchedulerTests.swift
    └── NotificationServiceTests.swift
```

### 8. Interface Contracts

```swift
// ── Between Views and ViewModels ──

// DailyWalkView expects:
@Published var todayChallenge: DailyChallenge
@Published var isCompleted: Bool
@Published var currentStreak: Int
@Published var showCelebration: Bool
@Published var newBadges: [EarnedBadge]
func complete(journal: String?) async

// CalendarView expects:
@Published var calendarDays: [CalendarDay]
@Published var selectedDay: CalendarDay?
@Published var currentMonth: Date
func selectDay(_ day: CalendarDay)
func nextMonth()
func previousMonth()
func completeGracePeriod(_ day: CalendarDay, journal: String?) async

// JourneyView expects:
@Published var totalCompleted: Int
@Published var currentStreak: Int
@Published var journeyBadge: BadgeProgress      // current distance badge
@Published var allBadges: [BadgeDisplayItem]     // full badge grid
@Published var journalEntries: [JournalDisplayItem]
func searchJournal(_ query: String)
func shareEntry(_ entry: JournalDisplayItem)

// SettingsView expects:
@Published var translation: BibleTranslation
@Published var morningTime: Date
@Published var eveningTime: Date
@Published var morningEnabled: Bool
@Published var eveningEnabled: Bool
@Published var streakWarningsEnabled: Bool
@Published var badgeNotificationsEnabled: Bool
@Published var darkMode: DarkModePreference
func updateTranslation(_ t: BibleTranslation)
func updateNotificationTime(morning: Date?, evening: Date?)
```

### 9. Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | Swift 5.9+ | Native iOS, required for SwiftData |
| UI | SwiftUI | Declarative, reactive, native feel |
| Architecture | MVVM | Natural fit for SwiftUI + testable |
| Local Storage | SwiftData | Apple's modern persistence, replaces Core Data |
| Cloud Sync | CloudKit | Free, automatic with Apple ID, no backend needed |
| Notifications | UserNotifications | Native iOS, reliable, supports local scheduling |
| Min iOS | 17.0 | Required for SwiftData; 85%+ device coverage |
| Challenge Data | Bundled JSON | Offline-first, no API dependency |
| Badge Assets | Recraft.ai | Custom art, professional quality |
| Analytics | None (v1) | Privacy-first; consider TelemetryDeck for v2 |

### 10. CloudKit Schema

```
CKRecord Types:

CompletedChallengeRecord
  - challengeId: String
  - challengeCategory: String
  - completedDate: Date
  - scheduledDate: Date
  - journalEntry: String?
  - deviceId: String (for conflict resolution)

EarnedBadgeRecord
  - badgeName: String
  - badgeType: String
  - category: String?
  - earnedDate: Date

UserProfileRecord
  - displayName: String
  - startDate: Date
  - preferredTranslation: String

Conflict Resolution: Last-writer-wins based on modifiedDate
Sync Strategy: Additive only (completions and badges are append-only)
```
