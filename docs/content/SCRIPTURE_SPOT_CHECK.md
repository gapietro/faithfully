# Scripture Spot-Check Log

> **SUPERSEDED.** This audited the licensed ESV/NIV/NKJV bundle, which v1
> does not ship. v1 uses public-domain WEB + KJV; the current check is
> [`SCRIPTURE_SPOT_CHECK_PD.md`](SCRIPTURE_SPOT_CHECK_PD.md). Kept because it
> records why the licensed route was abandoned.


Sprint D accuracy audit of the scripture text bundled in `Faithfully/Resources/challenges.json`. Checked 2026-07-20.

## Method

- **Deterministic sample of 34 challenges** (>20 per translation): every 18th day (days 1, 19, 37, … 361), plus all 11 giving challenges, plus 4 stretch-difficulty challenges (days 30, 38, 40, 47).
- Each sampled row's `scripture_text_esv`, `scripture_text_niv`, and `scripture_text_nkjv` was compared word-by-word against the corresponding passage fetched from **biblegateway.com** in that translation.
- Trivial differences ignored: verse numbers, curly vs straight quotes, capitalization of a mid-sentence opening word, footnote markers.
- Verdicts: **Pass** (matches), **Fail** (wrong wording, wrong translation, or misleading truncation), **Needs human pastor review** (could not verify against a fetched source).

**Honesty note:** this audit compares against publicly displayed web text and is a strong signal, not a legal or textual guarantee. Final sign-off should come from a human checking against licensed editions (ESV Text Edition 2025, NIV 2011, NKJV 1982) — see the failure list and the systemic finding below.

## Results — 34 samples

| Day | ID | Reference | ESV | NIV | NKJV | Notes |
|---|---|---|---|---|---|---|
| 1 | challenge_001 | Philippians 4:6-7 | Pass | Pass | Pass | |
| 6 | challenge_006 | 2 Corinthians 9:7 | Pass | Pass | Pass | |
| 19 | challenge_019 | Hebrews 10:24-25 | **Fail** | **Fail** | **Fail** | All three silently drop v25's final clause ("and all the more as you see the Day drawing near/approaching"), cut mid-sentence. Complete v25 or cite 10:24-25a. |
| 30 | challenge_030 | Colossians 3:13 | Pass | Pass | Pass | |
| 34 | challenge_034 | Galatians 6:9-10 | Pass | Pass | Pass | |
| 37 | challenge_037 | Genesis 13:17 | Pass | Pass | Pass | |
| 38 | challenge_038 | Matthew 5:23-24 | Pass | Pass | Pass | |
| 40 | challenge_040 | Romans 1:16 | Pass | Pass | Pass | Includes NKJV "gospel of Christ" variant correctly. |
| 47 | challenge_047 | Romans 12:14 | Pass | Pass | Pass | |
| 55 | challenge_055 | Habakkuk 2:2 | Pass | Pass | Pass | Intro clause trimmed in all three; body verbatim. |
| 73 | challenge_073 | Philippians 2:3-4 | Pass | Pass | Pass | |
| 91 | challenge_091 | Isaiah 58:6 | **Fail** | Pass | Pass | ESV field contains NIV text ("kind of fasting I have chosen… chains of injustice"). |
| 97 | challenge_097 | 2 Corinthians 9:7 | Pass | Pass | Pass | |
| 109 | challenge_109 | 1 Thessalonians 5:11 | Pass | Pass | Pass | |
| 116 | challenge_116 | Proverbs 11:25 | Pass | Pass | Pass | |
| 125 | challenge_125 | Malachi 3:10 | **Fail** | Pass | **Fail** | ESV field is NIV text. NKJV opens with NIV wording "Bring the whole tithe" (NKJV: "Bring all the tithes"). |
| 127 | challenge_127 | Psalm 139:7-8 | **Fail** | Pass | Pass | ESV field contains NIV text. |
| 145 | challenge_145 | Ephesians 4:15 | Pass | **Fail** | Pass | NIV field uses retired NIV 1984 wording, not current NIV 2011. |
| 153 | challenge_153 | 2 Corinthians 9:7 | Pass | Pass | Pass | |
| 163 | challenge_163 | John 13:14 | Pass | Pass | Pass | ESV and NKJV genuinely coincide here. |
| 181 | challenge_181 | Proverbs 19:17 | **Fail** | Pass | Pass | ESV field duplicates NIV text. |
| 199 | challenge_199 | Psalm 107:1 | **Fail** | Pass | Pass | ESV field duplicates NIV text. |
| 217 | challenge_217 | Romans 12:1 | **Fail** | Pass | Pass | ESV field duplicates NIV text. NIV also drops the verse's em dash ("to God—this is"), creating a run-on; minor. |
| 235 | challenge_235 | Acts 4:29-30 | Pass | **Fail** | Pass | NIV field uses NIV 1984 "miraculous signs and wonders"; NIV 2011 omits "miraculous". |
| 244 | challenge_244 | Proverbs 22:6 | **Fail** | **Fail** | Pass | ESV field is NIV-style text. NIV field mixes wording ("depart" for "turn from", drops "and"). |
| 253 | challenge_253 | 2 Timothy 2:2 | **Fail** | Pass | Pass | ESV field duplicates NIV text. |
| 271 | challenge_271 | James 5:16 | **Fail** | Pass | Pass | ESV field duplicates NIV text. |
| 272 | challenge_272 | 2 Corinthians 9:6-7 | **Fail** | **Fail** | Pass | ESV field is NIV wording. NIV omits "also" twice in v6. |
| 289 | challenge_289 | 1 Peter 2:12 | **Fail** | Pass | Pass | ESV field duplicates NIV text. |
| 307 | challenge_307 | Mark 12:43-44 | Pass | Pass | Pass | |
| 325 | challenge_325 | Ephesians 1:7-8 | **Fail** | Pass | **Fail** | All three stop partway through v8 without notation; ESV/NKJV cut mid-clause (misleading). NIV text verbatim to a real sentence break, but reference should be 1:7-8a. |
| 335 | challenge_335 | Matthew 6:1-2 | Pass | Pass | Pass | All three omit v2's final sentence at a clean boundary; acceptable, consider citing 6:1-2a. |
| 343 | challenge_343 | Psalm 66:16 | Pass | Pass | Pass | |
| 361 | challenge_361 | Revelation 21:4 | Pass | Pass | Pass | |

## Pass rates

| Translation | Pass | Fail | Needs review | Pass rate |
|---|---|---|---|---|
| ESV | 21/34 | 13 | 0 | **62%** |
| NIV | 29/34 | 5 | 0 | **85%** |
| NKJV | 31/34 | 3 | 0 | **91%** |
| Rows clean in all three | 19/34 | 15 | 0 | **56%** |

## Systemic finding: the ESV column is frequently NIV text

Every sampled ESV failure between days 91 and 289 is the **NIV text pasted into the ESV field**. A dataset-wide scan confirms this is structural, not random: **110 of 365 rows have `scripture_text_esv` byte-identical to `scripture_text_niv`**, heavily concentrated in the day 184–292 block (the same generation batch that also uses sentence-case titles). By contrast only 28 rows have ESV==NKJV and 11 NIV==NKJV, many of which are short verses where translations genuinely coincide (e.g. John 13:14 ESV/NKJV).

Identical text is not automatically wrong — but all six sampled rows from the ESV==NIV set were confirmed wrong, so the working assumption must be that **most of the ~110 ESV fields in that set are not actually ESV text**.

## Failures needing human fix (this sample)

1. **ESV field replacement** (confirmed NIV text): days 91, 125, 127, 181, 199, 217, 244, 253, 271, 272, 289 — plus the ~100 other ESV==NIV rows not sampled. Requires re-sourcing genuine ESV text from a licensed source (e.g. the ESV API, which permits caching up to 500 verses).
2. **NIV 1984 wording**: days 145, 235 (and likely others). Zondervan's gratis policy covers **only the current NIV (2011)** — this is a licensing issue as well as an accuracy one.
3. **Misleading truncation**: day 19 (Hebrews 10:24-25, all three), day 325 (Ephesians 1:7-8, ESV/NKJV). Complete the verse or cite the partial verse (e.g. "10:24-25a").
4. **NKJV/NIV blend**: day 125 NKJV field.

## Recommendation

Do not represent the bundled text as ESV/NIV/NKJV to end users until the ESV column is re-sourced and the NIV column is confirmed to be 2011-edition throughout. See `TRANSLATION_LICENSING.md` for the licensing implications and interim options. Scripture text fields were deliberately **not** edited in Sprint D — corrections should come from licensed sources, not from-memory patching.
