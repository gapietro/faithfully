# Bible Translation Licensing — v1 Decision

Sprint D research and product recommendation for shipping ESV, NIV, and NKJV scripture text in Faithfully. Researched 2026-07-20 from the publishers' official pages (fetch log at bottom).

> **This is product guidance, not legal advice.** It summarizes publicly posted publisher policies to inform a product decision. Anything App Store-bound should get a real permissions inquiry (cheap) and, if in doubt, a lawyer (rarely needed at this scale).

## What the app does

Faithfully bundles 365 daily challenges, each quoting 1–4 verses, stored offline in the app bundle in three translations (~365 verse-quotations per translation). The app is commercial (App Store distribution), and every verse is accompanied by substantial original text (title, challenge, reflection prompt).

## Publisher policies (as fetched)

All three publishers share the same gratis-use shape:

| Condition | ESV (Crossway) | NIV (Biblica / Zondervan) | NKJV (Thomas Nelson / HCCP) |
|---|---|---|---|
| Max verses without written permission | 500 | 500 | 500 |
| Max share of any one Bible book | ≤ 50% | ≤ 50% | ≤ 50% |
| Scripture share of your work's total text | < 25% | < 25% | ≤ 25% |
| Not a commentary/reference work | required | required | required |
| Copyright notice | required | required | required |
| Text edition | ESV Text Edition 2025 | **NIV 2011 only** (older editions explicitly not permitted) | NKJV 1982 |

Faithfully passes the numeric tests for all three: 365 < 500 verses per translation, scattered short quotes nowhere near half a book, and scripture well under 25% of total app text.

**But two documented carve-outs matter:**

1. **Apps are an ambiguous or excluded category.** Biblica's permissions page states website/app use "requires written permission" (Express License or Standard Publishing License). Thomas Nelson's and HCCP's FAQ answer for "Bible translation in a smartphone application or other digital product" is "contact our licensing department." Crossway's standard policy covers "print, digital, and audio" quotation but doesn't classify apps; its ESV API terms (which allow local caching of up to 500 verses and mobile app use with attribution and an esv.org link) are the closest explicit fit. The likely intent of the app FAQs is full-Bible reader apps, not sub-500-verse quotation inside an original work — but no page says that explicitly.
2. **Standalone-verse products are excluded** (NIV and NKJV explicitly; ESV similarly for artwork/stationery). Relevant to Faithfully's share images / any widget where a verse appears alone without the challenge text.

There is also a **factual blocker found by the spot check** (`SCRIPTURE_SPOT_CHECK.md`): ~110 of the app's "ESV" fields actually contain NIV text, and some NIV fields contain retired NIV 1984 wording. Shipping mislabeled or non-current text would violate the terms of the very policies above (misattribution; NIV 2011-only rule) regardless of verse counts.

## Decision for Greg (v1): **Not cleared to ship as-is**

**Recommendation: do not ship the current ESV/NIV/NKJV bundle to external TestFlight or the App Store without (a) fixing the text and (b) resolving the app-classification ambiguity — via permission inquiries or by falling back to public domain.**

Ranked options:

1. **(Recommended) Seek written confirmation, fix text first.**
   - Re-source the ESV column from a licensed source (ESV API allows caching up to 500 verses) and confirm NIV text is 2011 throughout.
   - Send two short permission inquiries describing the app: one to Crossway (permissions form), one to HarperCollins Christian Publishing (covers NIV North America **and** NKJV). Mention: 365 verses/translation, verses always accompanied by original devotional text, offline bundle, commercial app, worldwide distribution (worldwide NIV rights pull in Hodder & Stoughton for UK/EU — ask HCCP how to handle).
   - Approval is plausible given the gratis numbers; the inquiry removes the ambiguity in writing.
2. **(Fastest safe v1) Ship public domain now, add licensed translations later.** Replace or supplement with **KJV** and/or **WEB** (World English Bible, a modern-English public domain translation) for v1. Zero licensing risk, no permission latency. Keep the three-translation UI behind a data swap.
3. **(Middle path) Gate by translation.** Ship whichever translations are text-verified and policy-clear (NKJV is closest: 91% spot-check pass rate and clear numeric gratis fit) and hide the others until cleared. Requires the app-classification question answered even for NKJV, so option 1's HCCP inquiry is still needed.

**Do not** ship the current bundle labeled "ESV" — independent of licensing, ~30% of that column is not ESV text.

## Attribution strings (required if/when shipping)

For an in-app "About the translations" screen and the App Store description's legal section. Exact publisher-prescribed wording (multi-translation form for ESV; NIV wording is the Zondervan/North America commercial form):

> Scripture quotations marked (ESV) are from the ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. ESV Text Edition: 2025. Used by permission. All rights reserved.
>
> Scripture quotations taken from The Holy Bible, New International Version®, NIV®. Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc. Used with permission of Zondervan. All rights reserved worldwide. www.zondervan.com
>
> Scripture taken from the New King James Version®. Copyright © 1982 by Thomas Nelson. Used by permission. All rights reserved.

(If Crossway licensing lands via the ESV API route, its terms additionally require a link to www.esv.org. The exact NKJV multi-translation "quotations marked (NKJV)" wording was not on the fetched page — confirm with HCCP.)

If v1 goes public domain: KJV needs no notice in the US (note: the KJV is under Crown patent in the UK); WEB requests but does not require the notice "World English Bible (WEB), public domain."

## Checklist before external TestFlight / App Store

- [ ] ESV column re-sourced from licensed ESV text (or ESV dropped/replaced for v1)
- [ ] NIV column verified as NIV 2011 wording throughout (or NIV dropped/replaced for v1)
- [ ] Spot-check re-run and passing after re-sourcing; human/pastor final review of a sample
- [ ] Permission inquiries sent to Crossway and HCCP — written responses on file (or v1 shipped public-domain instead)
- [ ] Attribution screen added in-app with the exact notices above; notice also in App Store description if required by the license response
- [ ] Share images / widgets reviewed against the "standalone verse" exclusion (always include challenge text alongside the verse, or exclude licensed translations from share assets)
- [ ] Verse count per translation confirmed ≤ 500 and scripture < 25% of total app text (currently true; re-check if content grows)
- [ ] Worldwide-rights question (Hodder & Stoughton for NIV outside North America) answered by HCCP

## Fetch log / sources

- Crossway permissions: https://www.crossway.org/permissions/ (fetched OK)
- ESV API conditions: https://api.esv.org/ (fetched OK; commercial scope of API partially unverified)
- Thomas Nelson / HCCP permissions (NKJV + NIV North America commercial policy): https://www.thomasnelson.com/about-us/permissions/ (fetched OK via curl; WebFetch blocked)
- Biblica permissions: https://www.biblica.com/permissions/ (403 bot-blocked; text obtained via reader proxy of the official URL — treat as near-verified)
- harpercollinschristian.com/permissions and thenivbible.com FAQ: blocked (403), not recovered

Figures above are only those actually read on fetched pages; anything not confirmable is marked unverified.
