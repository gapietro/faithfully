# Scheduler Distribution Notes

Sprint D analysis of `ChallengeScheduler` (`Faithfully/Utilities/ChallengeScheduler.swift`), produced by simulating the exact scheduler logic in Python over full calendar years. Simulation date: 2026-07-20, against the 365-challenge dataset (11 giving, 354 non-giving).

## How the scheduler works today

- **First Saturday of each month** (weekday == Saturday, day-of-month ≤ 7): shows a giving challenge, chosen by `(monthIndex + yearOffset) % 11` over the 11 giving challenges in dataset order.
- **Every other day**: shows a non-giving challenge, chosen by `(dayOfYear + yearOffset × 47) % 354` over the 354 non-giving challenges in dataset order. Day-of-year is capped at 365, so Dec 31 of a leap year reuses Dec 30's index.
- `yearOffset` is `Calendar.dateComponents([.year])` between the user's start date and today (i.e. increments on the anniversary of the start date, not on Jan 1).

## Simulation results

Simulated calendar years 2026 (365 days) and 2028 (leap, 366 days) at `yearOffset` 0, 1, and 2.

| Metric | 2026 (any offset) | 2028 leap (any offset) |
|---|---|---|
| Unique challenges shown | 354 of 365 | 354 of 365 |
| Challenges repeated within the year | 11 (each twice) | 11 (one shown 3×, due to leap-day cap) |
| Non-giving challenges never shown that year | 11 | 11 |
| First-Saturday giving days | 12 of 12, all giving | 12 of 12, all giving |
| Unique giving challenges used | 11 of 11 | 11 of 11 |
| Max consecutive same-category run | 1 | 2 (only from the Dec 30/31 leap-day duplicate) |

### Why 11 repeats and 11 never-shown per year

Two independent effects, both of size ~11–12:

1. **365 days mod 354 challenges**: day-of-year indices wrap, so the last 11 days of the year (Dec 21–31 in a 365-day year) land on the same indices as early-January days. At offset 0 the repeated challenges are the ones from source-days 2–13.
2. **12 first-Saturday overrides**: the non-giving challenge that would have shown on each first Saturday is skipped. At offset 0 the never-shown challenges are source-days 41, 69, 98, 128, 164, 193, 221, 257, 286, 322, 351.

### yearOffset rotation works

- The `× 47` stride (47 is coprime with 354 = 2·3·59) shifts which non-giving challenges are repeated/skipped each year. **Across any 2 consecutive years, zero non-giving challenges are missed** — everything skipped in year N appears in year N+1.
- Giving rotation `(month + yearOffset) % 11` also rotates: each year starts one challenge later in the giving list, so a long-term user sees giving challenges paired with different months over an 11-year cycle.

### Known quirks (accepted for v1)

- **12 months vs 11 giving challenges**: within any single year, December's giving challenge repeats January's (`(0 + y) % 11 == (11 + y) % 11`). One giving challenge always appears twice per year. Adding a 12th giving challenge would eliminate this; not required for v1.
- **Leap-day duplicate**: `min(dayOfYear, 365)` makes Dec 31 of a leap year repeat Dec 30's challenge (the only consecutive same-category/same-challenge pair). Harmless, and date-keyed completion keeps the two days' records separate.
- **yearOffset boundary is the user's start-date anniversary**, not Jan 1. Around the anniversary the index stream jumps by 47; simulation shows no missed or clumped categories from this, just a one-time reshuffle.

## Date-keyed completion makes ID reuse safe

Completions are keyed by date (Sprint B fix), not by challenge ID. So when the same challenge ID appears twice in a year (the 11 late-December repeats, the December giving repeat, or the leap-day duplicate), completing one occurrence does **not** mark the other as complete, and streak/calendar logic stays correct. This is what makes the modulo-reuse design acceptable.

## Recommendation

**No code change for v1.** The distribution is healthy: 97% of the pool is shown every year, everything is shown within any 2-year window, first-Saturday giving pinning is exact, and category runs don't clump. The candidate fixes (a 12th giving challenge, uncapping day 366) are content/design decisions with small payoff and nonzero regression risk to first-Saturday and rotation behavior, so they are documented here instead of patched.
