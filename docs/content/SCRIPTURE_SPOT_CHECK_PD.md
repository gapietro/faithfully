# Scripture Spot Check — Public Domain Bundle (WEB + KJV)

Verification record for the Sprint F1 public-domain scripture bundle (2026-07-20). Supersedes [SCRIPTURE_SPOT_CHECK.md](SCRIPTURE_SPOT_CHECK.md), which audited the retired ESV/NIV/NKJV bundle.

## How the bundle was built

- Source texts: full-Bible JSON dumps from **getbible.net v2** — `https://api.getbible.net/v2/web.json` (World English Bible) and `https://api.getbible.net/v2/kjv.json` (King James Version). Both translations are public domain.
- Every one of the **251 unique** `scripture_reference` values across the 365 challenges was resolved programmatically (no hand-typed or model-generated verse text) by `scripts/fetch_pd_scripture.py`: reference parsing, book-name normalization (Psalm/Psalms, Dan/Deut/Eph/Heb/Isa abbreviations), multi-verse span concatenation, and whole-chapter refs (Psalm 23, Psalm 91).
- Result: **251/251 references resolved, 0 failures, 0 empty fields** across all 365 challenges in both translations. `scripts/validate_challenges.py` enforces this and runs clean.

## Independent spot check

24 rows (12 references × 2 translations) were compared against **bible-api.com** — an independent public-domain scripture API unrelated to getbible.net — using `?translation=web` and `?translation=kjv`. Comparison: lowercase, punctuation-stripped, whitespace-normalized similarity (difflib ratio); 1.00 means the texts are identical after normalization.

The sample deliberately covers the tricky cases: abbreviated book names, "Psalms N" vs "Psalm N", whole chapters, long multi-verse spans, single-chapter books.

| Reference | Translation | Bundle text (first words) | Similarity |
|---|---|---|---|
| Philippians 4:6-7 | WEB | In nothing be anxious, but in everything, by prayer and… | 1.00 |
| Philippians 4:6-7 | KJV | Be careful for nothing; but in every thing by prayer and… | 1.00 |
| John 3:16 | WEB | For God so loved the world, that he gave his one and only… | 1.00 |
| John 3:16 | KJV | For God so loved the world, that he gave his only begotten… | 1.00 |
| Psalm 23 (whole chapter) | WEB | Yahweh is my shepherd: I shall lack nothing. He makes me… | 1.00 |
| Psalm 23 (whole chapter) | KJV | The Lord is my shepherd; I shall not want. He maketh me to… | 1.00 |
| Proverbs 3:5-6 | WEB | Trust in Yahweh with all your heart, and don’t lean on your… | 1.00 |
| Proverbs 3:5-6 | KJV | Trust in the Lord with all thine heart; and lean not unto… | 1.00 |
| Isaiah 30:15 | WEB | For thus said the Lord Yahweh, the Holy One of Israel, “You… | 1.00 |
| Isaiah 30:15 | KJV | For thus saith the Lord God, the Holy One of Israel; In… | 1.00 |
| Dan 6:10 (abbrev.) | WEB | When Daniel knew that the writing was signed, he went into… | 1.00 |
| Dan 6:10 (abbrev.) | KJV | Now when Daniel knew that the writing was signed, he went… | 1.00 |
| Deut 17:18 (abbrev.) | WEB | It shall be, when he sits on the throne of his kingdom,… | 1.00 |
| Deut 17:18 (abbrev.) | KJV | And it shall be, when he sitteth upon the throne of his… | 1.00 |
| Psalms 54:6 | WEB | With a free will offering, I will sacrifice to you. I will… | 1.00 |
| Psalms 54:6 | KJV | I will freely sacrifice unto thee: I will praise thy name,… | 1.00 |
| Matthew 5:3-10 | WEB | “Blessed are the poor in spirit, for theirs is the Kingdom… | 1.00 |
| Matthew 5:3-10 | KJV | Blessed are the poor in spirit: for theirs is the kingdom… | 1.00 |
| Romans 8:28 | WEB | We know that all things work together for good for those… | 1.00 |
| Romans 8:28 | KJV | And we know that all things work together for good to them… | 1.00 |
| 3 John 1:6 (single-chapter book) | WEB | They have testified about your love before the assembly.… | 1.00 |
| 3 John 1:6 (single-chapter book) | KJV | Which have borne witness of thy charity before the church:… | 1.00 |
| Ephesians 6:10-18 (9-verse span) | WEB | Finally, be strong in the Lord, and in the strength of his… | 1.00 |
| Ephesians 6:10-18 (9-verse span) | KJV | Finally, my brethren, be strong in the Lord, and in the… | 1.00 |

**Result: 24/24 rows match the independent source exactly (1.00 after normalization). 0 mismatches.**

Notes:

- The WEB Old Testament renders the divine name as "Yahweh" (e.g. Psalm 23:1). This is the authentic WEB text, not an error.
- An automated artifact scan across all 730 text fields (365 × 2 translations) found no footnote markers, bracketed insertions, embedded verse numbers, or empty fields.

## Verdict

🟢 The public-domain bundle is text-accurate against two independent sources and safe to ship. Re-run `scripts/validate_challenges.py` (and this spot check via the script in the repo history) if challenge content is regenerated.
