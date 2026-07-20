# App Store Listing — Drafts

Draft metadata for App Store Connect. Everything here is copy-paste ready but **unsubmitted**; Greg reviews and enters it. Character limits noted per field.

## Basics

| Field | Value |
|---|---|
| App name | **Faithfully** (verify availability when creating the app record) |
| Bundle ID | `com.faithfully.app` |
| Primary category | Lifestyle |
| Secondary category | (optional) Health & Fitness — or leave empty |
| Age rating | 4+ (no objectionable content) |
| Price | Free |
| Copyright | © 2026 Greg Pietropaolo |

## Subtitle (30 chars max)

Ideas, from the PRD tagline list:

1. `Your daily walk with Jesus` (26) — recommended
2. `Walk it out. Every day.` (23)
3. `Daily faith in action` (21)

## Description draft (4000 chars max)

> Most Bible apps help you read the Word. Faithfully helps you live it.
>
> Every day, Faithfully gives you one challenge — the same one every user receives — rooted in a specific Bible passage. Pray for someone who hurt you. Give sacrificially. Fast. Share the Gospel. Memorize a psalm. Some days are comfortable. Some days aren't. That's the point.
>
> ONE CHALLENGE, EVERY DAY
> A full year of scripture-backed challenges across ten areas of the Christian life: prayer, scripture, obedience, giving, evangelism, spiritual warfare, discipline, worship, service, and growth. Everyone walks the same path on the same day.
>
> REFLECT AND REMEMBER
> Mark each challenge complete and capture a short journal reflection. Look back on your calendar and see the days you showed up.
>
> STREAKS AND BADGES
> Build a streak, earn milestone badges along your journey, and watch your year fill in — with grace built in for the days life happens.
>
> YOURS ALONE
> No account. No ads. No tracking. Everything stays on your device, and the whole app works offline.
>
> "Faith by itself, if it does not have works, is dead." — James 2:17
>
> Start your daily walk today.

*(~1,200 chars — room to grow. Scripture attribution notices may need to be appended here depending on the licensing outcome; see `docs/content/TRANSLATION_LICENSING.md`.)*

## Keywords (100 chars max)

Draft (97 chars, no spaces after commas, don't repeat "Faithfully"):

```
christian,bible,devotional,daily,faith,challenge,prayer,scripture,jesus,discipleship,habit,streak
```

## Promotional text (170 chars max)

Draft (139):

> One scripture-backed challenge every day. No account, no ads, works offline. Stop just reading the Word — start walking it out.

## What's New — 1.0

> Welcome to Faithfully. A year of daily, scripture-backed challenges; streaks, badges, and a journal — all private, all offline.

## URLs

| Field | Value |
|---|---|
| Support URL | TBD — placeholder: `https://github.com/gapietro/faithfully` (or a faithfully.app page) |
| Marketing URL | optional, TBD |
| Privacy policy URL | **Required.** Host `docs/ship/PRIVACY_POLICY.md` publicly first — see that file's header. |

## Privacy nutrition label (App Store Connect questionnaire)

- Data collection: **"Data Not Collected"** across the board — no account, no analytics, no tracking, no third-party SDKs. (Re-answer if CloudKit or analytics are ever added.)

## Review notes for Apple (draft)

> Faithfully is a daily Christian devotional/habit app. Each day it shows one challenge tied to a Bible passage; users mark it complete, optionally journal, and earn streaks/badges. There is no login or account — the app is fully usable immediately after launch, entirely on-device and offline. Notifications are optional local notifications. No demo credentials are needed: launch the app, complete onboarding, and today's challenge is on the home screen.
