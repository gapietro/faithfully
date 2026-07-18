# SPARC Phase 5: Completion
## Faithfully iOS App — Launch Readiness Checklist

### 1. Code Quality
- [ ] All tests pass (unit, integration, UI)
- [ ] Test coverage > 90% on Services and ViewModels
- [ ] SwiftLint: zero warnings
- [ ] No force-unwraps in production code
- [ ] No TODO/FIXME comments remaining
- [ ] All deprecated API usage resolved
- [ ] Memory leaks checked via Instruments (Leaks template)
- [ ] No retain cycles in closures

### 2. Performance
- [ ] App launch to home screen: < 2 seconds (iPhone 12+)
- [ ] Challenge JSON loads in < 100ms
- [ ] Calendar renders in < 200ms
- [ ] Badge evaluation completes in < 50ms
- [ ] No janky scrolling (60fps verified in Instruments)
- [ ] SwiftData queries optimized (no N+1 fetches)
- [ ] App size < 50MB (including all badge assets)

### 3. Content Verification
- [ ] All 365 challenges present in challenges.json
- [ ] Zero null or empty fields in any challenge
- [ ] Scripture text spot-checked against published Bible text (20+ random samples per translation)
- [ ] ESV text verified accurate
- [ ] NIV text verified accurate
- [ ] NKJV text verified accurate
- [ ] No consecutive same-category days in default schedule
- [ ] Giving challenges correctly pinned to first Saturdays
- [ ] All challenge descriptions are actionable (verb-first)
- [ ] No AI writing patterns (em-dashes, hedge words, filler phrases)

### 4. Badge Assets
- [ ] All journey badges designed (5): 5K, 10K, Half Marathon, Marathon, Ultra
- [ ] All streak badges designed (5): Ember, Flame, Fire, Furnace, Unquenchable
- [ ] All category badges designed (40): 10 categories x 4 levels
- [ ] Grayscale silhouette versions for unearned badges
- [ ] All badges at 3x resolution for Retina displays
- [ ] Badge celebration animation implemented and tested
- [ ] 10 category icons designed (line art style)

### 5. Accessibility
- [ ] VoiceOver: all screens navigable, all interactive elements labeled
- [ ] Dynamic Type: all text scales with system font size
- [ ] Color contrast: meets WCAG 2.1 AA minimum (4.5:1 for text)
- [ ] No information conveyed by color alone (badges use shape + text too)
- [ ] Reduce Motion: celebration animations respect this setting

### 6. Dark Mode
- [ ] All screens render correctly in light mode
- [ ] All screens render correctly in dark mode
- [ ] System setting toggle works
- [ ] Manual override in Settings works
- [ ] Badge art looks good on both backgrounds
- [ ] No hard-coded colors (all via Asset Catalog or semantic colors)

### 7. Edge Cases Tested
- [ ] First launch (no data, onboarding flow)
- [ ] Day 1 completion
- [ ] Day 365 completion (year boundary)
- [ ] Day 366 (year rotation)
- [ ] Leap year handling (Feb 29)
- [ ] Midnight timezone edge case (challenge changeover)
- [ ] User changes timezone mid-streak
- [ ] Device date changed manually (anti-cheat)
- [ ] App launched after 30 days of inactivity
- [ ] 1000+ completions (performance)
- [ ] Journal entry at max length (2000 chars)
- [ ] No internet connection (full offline operation)
- [ ] Low storage warning
- [ ] Background app refresh

### 8. Notifications
- [ ] Morning notification fires at configured time
- [ ] Evening reminder fires only if challenge not completed
- [ ] Streak warning fires only if streak >= 7 and not completed
- [ ] Badge celebration notification fires on badge earned
- [ ] All notifications respect user's enabled/disabled settings
- [ ] Tapping notification opens app to correct screen
- [ ] Notifications work when app is in background
- [ ] Notifications work when app is terminated

### 9. CloudKit
- [ ] Initial sync on first launch with iCloud enabled
- [ ] Completion syncs to cloud within 30 seconds on Wi-Fi
- [ ] Badge sync works
- [ ] Conflict resolution: last-writer-wins
- [ ] Graceful handling when iCloud is disabled
- [ ] Graceful handling when iCloud storage is full
- [ ] Restore from cloud on fresh install (same Apple ID)

### 10. App Store Preparation
- [ ] App name: "Faithfully" (verify availability)
- [ ] Bundle ID registered in Apple Developer Portal
- [ ] App category: Lifestyle
- [ ] Age rating: 4+ (no objectionable content)
- [ ] Privacy policy URL created and hosted
- [ ] App description written (4000 char max)
- [ ] Keywords researched and selected (100 char max)
- [ ] What's New text written
- [ ] 6.7" screenshots (iPhone 15 Pro Max): 5-8 screenshots
- [ ] 6.1" screenshots (iPhone 15 Pro): 5-8 screenshots
- [ ] App preview video (optional but recommended)
- [ ] App icon: 1024x1024 final version
- [ ] Promotional text (170 char max)
- [ ] Support URL
- [ ] Copyright notice

### 11. TestFlight Beta
- [ ] Internal testing: 3+ team members for 1 week
- [ ] External testing: 10+ beta users for 2 weeks
- [ ] All crash reports reviewed and fixed
- [ ] Beta feedback incorporated
- [ ] Final regression test after all fixes

### 12. Pre-Submission Final Check
- [ ] Archive build succeeds
- [ ] No warnings in Xcode build
- [ ] App Thinning verified (asset variants)
- [ ] Export compliance: No encryption (or proper declaration)
- [ ] Content rights: all scripture text used with permission/public domain
- [ ] IDFA: not used (no tracking)
- [ ] Third-party SDK compliance: none (pure native)
- [ ] Privacy nutrition label completed in App Store Connect
- [ ] Review notes for Apple: explain app purpose, any demo credentials needed

### 13. Post-Launch Monitoring
- [ ] Crash reporting enabled (native Xcode Organizer)
- [ ] App Store rating prompt configured (after 30 completed challenges)
- [ ] Support email configured and monitored
- [ ] v1.1 roadmap documented (top user-requested features)

---

## Launch Command

When all boxes above are checked:
```
1. Archive in Xcode (Product → Archive)
2. Upload to App Store Connect
3. Submit for Review
4. Expected review time: 24-48 hours
5. Release: Manual (so you can coordinate announcement)
```
