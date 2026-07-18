# Faithfully — Product Requirements Document

**Version:** 1.0
**Date:** April 1, 2026
**Author:** Repository ownerpaolo
**Platform:** iOS (iPhone) — Swift / SwiftUI
**Status:** Pre-Development

---

## 1. Vision & Purpose

Faithfully is a daily Christian action app that bridges the gap between *hearing* the Word of God and *living* it. Most Bible apps focus on reading, listening, and learning. Faithfully focuses on doing. Each day, every user receives the same scripture-backed challenge that calls them to step out in faith, practice obedience, and put the Christian life into action.

**Core Belief:** It's not enough to know the Word. You have to walk it out.

**Tagline Ideas:**
- "Faith without works is dead." (James 2:26)
- "Walk it out."
- "Your daily walk with Jesus."

---

## 2. Target Audience

**Primary:** Individual Christian believers who want to move beyond passive Bible consumption into active, daily obedience and spiritual growth.

**Persona:** A believer who reads their Bible regularly (possibly using Mission 119 or a similar plan) but recognizes that knowing the Word and living it are two different things. They want accountability, structure, and a nudge to step outside their comfort zone each day.

---

## 3. Core Concept

### 3.1 The Daily Walk

Every day, all users receive the same Daily Walk challenge. This is intentional:

- **Shared experience:** Everyone is walking the same path together, enabling community and accountability.
- **No comfort zone:** Users cannot cherry-pick easy challenges. Some days will push them into uncomfortable territory, and that's the point.
- **Scripture-rooted:** Every challenge is tied to a specific Bible verse or passage that grounds the action in God's Word.

### 3.2 Challenge Categories

Challenges are organized into the following categories. Each challenge belongs to one primary category.

| Category | Description | Example Challenges |
|----------|-------------|-------------------|
| **Prayer** | Intercession, personal prayer, prayer for others | Pray for the sick; Pray for persecuted Christians worldwide; Pray for government officials; Find something in the media to pray about today |
| **Scripture** | Reading, memorizing, meditating on the Word | Memorize the Lord's Prayer; Memorize Psalm 23; Memorize Psalm 91; Read a short Bible commentary; Meditate on the Word today |
| **Obedience** | Following Christ's commands, submitting to God's will | Follow His commandments today; Listen to the Holy Spirit; Trust in the Lord today, stay calm no matter the situation |
| **Giving** | Sacrificial generosity (it has to cost you something) | Give sacrificially (monthly challenge); Buy a physical Bible for someone; Volunteer in service of God |
| **Evangelism** | Sharing the Gospel, being a witness | Share the Gospel with someone today; Help the poor; Act like everyone you meet is Jesus in disguise |
| **Spiritual Warfare** | Guarding your heart, mind, and spirit | Put on the full armor of God today; Protect your eyes, ears, heart, and mind; Stay off social media for a day; Make a covenant with your eyes; Read a passage on spiritual warfare |
| **Discipline** | Fasting, self-control, spiritual habits | Fast today; Pay attention to your thoughts — are they yours?; Work hard for your employer, give 110%; Remove the veil over your heart and mind |
| **Worship & Thanks** | Gratitude, confession, surrender | Give thanks to God today; Confess your sins, ask the Holy Spirit for help; Ask God for help better serving Him |
| **Service** | Helping others, forgiving, showing love | Forgive someone who hurt you; Help others, ask God for help; Put yourself in someone else's shoes today |
| **Growth** | Investing in deeper understanding | Buy a study Bible; Take your Bible to church; Pray for wisdom; Ask God for help better serving Him |

### 3.3 Challenge Content Structure

Each Daily Walk challenge includes:

1. **Challenge Title** — A short, clear action statement (e.g., "Pray for the Persecuted")
2. **Category Badge** — Visual indicator of the category (Prayer, Scripture, Giving, etc.)
3. **Scripture Anchor** — The Bible verse(s) grounding this challenge
4. **The Challenge** — A 2-3 sentence description of what to do today and why it matters
5. **Reflection Prompt** — A short question for the end of the day (e.g., "How did God show up when you stepped out?")
6. **Completion Toggle** — User marks it done (with optional journal entry)

---

## 4. Feature Specifications

### 4.1 Daily Walk Screen (Home)

The primary screen users see when they open the app each morning.

**Elements:**
- Current date and "Day X" counter (how many days since the user started)
- Today's challenge card (title, category, scripture, description)
- "I Did It" completion button
- Optional: brief journal/reflection text entry after completion (private by default, shareable via share sheet)
- Yesterday's challenge (collapsed, with completion status)
- Streak counter (visible, motivating)

**Behavior:**
- New challenge appears at midnight local time (or configurable morning time like 5:00 AM)
- Challenge is the same for all users on the same calendar day
- Completing a challenge is binary: done or not done. No partial credit.
- Users can go back and complete missed days within a 3-day grace window (e.g., on Thursday you can still complete Monday's challenge, but not Sunday's)

### 4.2 Challenge Calendar

A monthly calendar view showing:
- Completed days (filled/colored)
- Missed days (empty/dimmed)
- Current streak highlighted
- Tapping a day shows that day's challenge and the user's journal entry (if any)

### 4.3 Reward & Badge System

Three interlocking layers of gamification, all designed to encourage persistence.

#### Layer 1: The Journey (Distance Metaphor)

Total completed challenges map to a spiritual race:

| Badge | Challenges Completed | Metaphor |
|-------|---------------------|----------|
| **5K** | 31 (1 month) | You've started the race |
| **10K** | 90 (3 months) | Building endurance |
| **Half Marathon** | 182 (6 months) | Halfway through the year of faith |
| **Marathon** | 365 (1 year) | A full year walking with Jesus |
| **Ultra** | 730 (2 years) | Unstoppable. This is who you are now. |

#### Layer 2: Streaks

| Badge | Streak Length |
|-------|-------------|
| **Ember** | 7 consecutive days |
| **Flame** | 30 consecutive days |
| **Fire** | 90 consecutive days |
| **Furnace** | 180 consecutive days |
| **Unquenchable** | 365 consecutive days |

#### Layer 3: Category Mastery

Users earn category badges as they complete challenges in each area:

| Level | Challenges in Category |
|-------|----------------------|
| **Beginner** | 10 |
| **Devoted** | 25 |
| **Warrior** | 50 |
| **Master** | 100 |

Category-specific badge names:
- Prayer: Prayer Beginner → Prayer Devoted → Prayer Warrior → Prayer Master
- Scripture: Scripture Beginner → Scripture Scholar → Scripture Warrior → Scripture Master
- Evangelism: Witness Beginner → Witness Devoted → Gospel Warrior → Gospel Master
- Giving: Giver Beginner → Generous Heart → Sacrificial Giver → Cheerful Giver
- (Apply similar naming to all 10 categories)

#### Badge Display
- Badges appear on a dedicated "My Journey" profile screen
- Earned badges are full color; unearned badges are grayed silhouettes
- Each badge has a progress bar showing how close the user is
- New badge earned triggers a celebratory animation and optional share card

### 4.4 My Journey (Profile Screen)

- User's name and start date
- Total days completed / total days since joining
- Current streak
- Journey badge (5K, 10K, etc.) with progress ring
- Grid of all category badges
- Grid of streak badges
- Journal history (searchable)

### 4.5 Scripture Library

- A collection of all scripture references used across challenges
- Organized by category
- Tapping a verse opens it (link to Bible app or in-app display)
- Tracks which verses the user has engaged with

### 4.6 Notifications

- Morning notification with today's challenge (configurable time, default 7:00 AM)
- Evening reminder if challenge not yet completed (configurable, default 8:00 PM)
- Streak-at-risk notification ("Don't break your 45-day streak!")
- Badge earned celebration notification
- All notifications are optional and individually configurable

### 4.7 Settings

- Notification preferences (morning time, evening reminder, badge alerts)
- Start-of-day time (when new challenge appears)
- Bible translation preference (ESV default, NIV, NKJV)
- Display preferences (dark mode / light mode)
- About / Contact
- Data export (journal entries as text/PDF)
- Share individual journal entries (generates a styled card for Messages, social, etc.)

---

## 5. Content Pipeline

### 5.1 Challenge Database

The app needs a pre-built library of at minimum 365 daily challenges (one full year) before launch. Each challenge record contains:

```
{
  "id": "challenge_001",
  "title": "Pray for the Persecuted",
  "category": "prayer",
  "scripture_reference": "Hebrews 13:3",
  "scripture_text_esv": "Remember those who are in prison, as though in prison with them, and those who are mistreated, since you also are in the body.",
  "scripture_text_niv": "Continue to remember those in prison as if you were together with them in prison, and those who are mistreated as if you yourselves were suffering.",
  "scripture_text_nkjv": "Remember the prisoners as if chained with them—those who are mistreated—since you yourselves are in the body also.",
  "challenge_description": "Today, spend intentional time praying for Christians around the world who face persecution for their faith. Look up a country where believers are suffering and pray specifically for them by name or by situation.",
  "reflection_prompt": "What did God put on your heart as you prayed? How does your freedom to worship freely feel different now?",
  "difficulty": "standard",
  "recurrence": "quarterly"
}
```

### 5.2 Content Principles

- Every challenge must be actionable (something you DO, not just think about)
- Every challenge must be scripture-grounded
- Challenges should range from simple daily habits to genuinely uncomfortable acts of faith
- "Giving" challenges appear roughly once a month and must cost the user something real
- No challenge should require spending money except the intentional "Giving" category
- Challenges shift/rotate each year so returning users don't repeat the same calendar-date challenge. The scheduling algorithm offsets the pool annually.
- "Giving" challenges are pinned to the first Saturday of each month

---

## 6. Technical Architecture

### 6.1 Platform & Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Minimum iOS:** 17.0
- **Architecture:** MVVM (Model-View-ViewModel)
- **Data Persistence:** SwiftData (local) + CloudKit (sync)
- **Notifications:** UserNotifications framework

### 6.2 Data Model

```
User
  - id: UUID
  - displayName: String
  - startDate: Date
  - preferredTranslation: BibleTranslation (enum: .esv, .niv, .nkjv — default .esv)
  - notificationPreferences: NotificationPrefs
  - streakCount: Int (computed)
  - totalCompleted: Int (computed)

DailyChallenge
  - id: String
  - title: String
  - category: ChallengeCategory (enum)
  - scriptureReference: String
  - scriptureTextESV: String
  - scriptureTextNIV: String
  - scriptureTextNKJV: String
  - challengeDescription: String
  - reflectionPrompt: String
  - scheduledDate: Date
  - difficulty: Difficulty (enum)

CompletedChallenge
  - id: UUID
  - challengeId: String
  - completedDate: Date
  - journalEntry: String? (optional)
  - userId: UUID

Badge
  - id: String
  - name: String
  - type: BadgeType (journey | streak | category)
  - category: ChallengeCategory? (for category badges)
  - threshold: Int
  - iconName: String
  - earnedDate: Date?

ChallengeCategory (enum)
  - prayer
  - scripture
  - obedience
  - giving
  - evangelism
  - spiritualWarfare
  - discipline
  - worshipAndThanks
  - service
  - growth
```

### 6.3 Challenge Scheduling

- All users see the same challenge on the same calendar date
- Challenges are scheduled in advance (full year pre-loaded)
- Schedule is deterministic: derived from date, no server required at launch
- Category distribution across the year ensures variety (no two "Giving" days back-to-back, etc.)
- A content JSON file ships with the app and can be updated via CloudKit

### 6.4 Offline-First

- The entire challenge library is bundled with the app
- All completion data is stored locally via SwiftData
- CloudKit sync is additive (for backup/restore and future multi-device)
- The app works fully offline after initial install

### 6.5 No Account Required

- No login, no email, no account creation at launch
- User data lives on-device
- CloudKit provides anonymous sync via Apple ID (automatic)
- Future: optional profile for community features

---

## 7. Design Direction

### 7.1 Visual Identity

- **Palette:** Warm, grounded earth tones. Think: deep navy, warm gold/amber, soft cream, forest green accents. Not clinical or corporate. Feels like a leather-bound journal.
- **Typography:** Clean, readable serif for scripture; modern sans-serif for UI. Consider a handwritten accent font for badge names.
- **Iconography:** Simple, meaningful icons for each category. Subtle, not cartoonish. Think line art.
- **Overall Feel:** Quiet confidence. Not flashy or gamified to the point of being distracting. The badges should feel like achievements, not candy.

### 7.2 Key Screens (Wireframe Descriptions)

1. **Home / Daily Walk:** Full-screen card with today's challenge. Scripture at top, challenge in center, "I Did It" button at bottom. Minimal chrome.
2. **Calendar:** Standard month grid. Colored dots for completed days. Tap to expand.
3. **My Journey:** Vertical scroll. Journey progress ring at top, badge grid below, journal timeline at bottom.
4. **Settings:** Standard iOS settings list style.

---

## 8. MVP Scope (v1.0)

### In Scope
- Daily challenge display (same for all users)
- Challenge completion with optional journal entry
- Challenge calendar with history
- Streak tracking and display
- All three badge layers (journey, streak, category)
- Badge celebration animations
- Morning and evening push notifications
- Settings (notifications, display)
- 365 pre-built challenges
- Offline-first, no account required
- Dark mode support

### Out of Scope (Future Versions)
- Community/social features (seeing friends' progress)
- Small group integration (shared accountability)
- Custom challenge creation
- Android version
- Web companion
- In-app Bible reader
- Apple Watch companion
- Widgets
- Sharing challenge cards to social media
- Backend/server infrastructure
- In-app purchases or monetization

---

## 9. Success Metrics

| Metric | Target |
|--------|--------|
| Daily active users (DAU) | — (track from launch) |
| 7-day retention | > 60% |
| 30-day retention | > 40% |
| Average streak length | > 14 days |
| Challenge completion rate | > 70% of active days |
| App Store rating | > 4.5 stars |

---

## 10. Resolved Decisions

1. **Bible translation:** Default is ESV. Users can choose between ESV, NIV, and NKJV in Settings. Scripture text for all three translations must be included in the challenge data (or fetched via API). The app ships with ESV as the bundled default; NIV and NKJV text is also bundled or fetched on first selection.
2. **Content creation:** AI-assisted generation with human curation. The initial 365-challenge library will be generated with AI assistance, then personally reviewed and curated by the creator before shipping.
3. **Badge art:** Custom-designed badge artwork generated via Recraft.ai, not SF Symbols. Each badge gets a unique, polished design that feels like a real achievement. Badge assets will be created during Phase 4 (Content & Launch).

## 11. Additional Resolved Decisions

4. **Challenge rotation:** Challenges shift/rotate yearly so returning users don't see the same challenge on the same calendar date. The scheduling algorithm offsets the challenge pool each year to keep content fresh for long-term users.
5. **Grace period:** 3 days. Users can go back and complete up to 3 missed days. This balances forgiveness with accountability.
6. **Giving frequency:** First Saturday of every month. Predictable so users can plan financially, and landing on a weekend gives them time to act.
7. **Journal privacy:** Optionally shareable. Journal entries are private by default, but users can choose to share a specific entry as a text or image card (e.g., to Messages, social media, or a small group chat).
8. **App Store category:** Lifestyle. Broadest discovery potential and where most faith/devotional apps are categorized.

---

## 12. Development Phases

### Phase 1: Foundation (Weeks 1-3)
- Project setup (Xcode, SwiftUI, SwiftData)
- Data models and persistence layer
- Challenge JSON schema and sample data (30 challenges)
- Home screen with daily challenge display
- Challenge completion flow

### Phase 2: Tracking & Badges (Weeks 4-5)
- Calendar view
- Streak calculation engine
- Badge system (all three layers)
- My Journey profile screen
- Badge progress tracking and animations

### Phase 3: Notifications & Polish (Weeks 6-7)
- Push notification system
- Settings screen
- Dark mode
- Onboarding flow (first launch)
- Animation and transition polish

### Phase 4: Content & Launch (Weeks 8-10)
- Build full 365-challenge content library
- Content review and scripture verification
- App Store assets (screenshots, description, metadata — Category: Lifestyle)
- TestFlight beta
- App Store submission

---

## 13. File & Folder Structure (Xcode Project)

```
Faithfully/
├── App/
│   ├── FaithfullyApp.swift
│   └── ContentView.swift
├── Models/
│   ├── DailyChallenge.swift
│   ├── CompletedChallenge.swift
│   ├── Badge.swift
│   ├── ChallengeCategory.swift
│   └── User.swift
├── ViewModels/
│   ├── DailyWalkViewModel.swift
│   ├── CalendarViewModel.swift
│   ├── JourneyViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── DailyWalk/
│   │   ├── DailyWalkView.swift
│   │   ├── ChallengeCardView.swift
│   │   └── CompletionView.swift
│   ├── Calendar/
│   │   ├── CalendarView.swift
│   │   └── DayDetailView.swift
│   ├── Journey/
│   │   ├── JourneyView.swift
│   │   ├── BadgeGridView.swift
│   │   └── JournalTimelineView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Onboarding/
│       └── OnboardingView.swift
├── Services/
│   ├── ChallengeService.swift
│   ├── BadgeService.swift
│   ├── NotificationService.swift
│   └── PersistenceService.swift
├── Resources/
│   ├── challenges.json
│   ├── Assets.xcassets/
│   └── Localizable.strings
└── Utilities/
    ├── DateExtensions.swift
    └── Constants.swift
```

---

*This PRD is intended to be handed to Claude Code as the primary specification for building the Faithfully iOS app. All architectural decisions, feature specs, and scope boundaries defined here should be treated as authoritative unless explicitly overridden during development.*
