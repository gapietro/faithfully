#!/usr/bin/env python3
"""Build public-domain scripture texts (KJV + WEB) for every challenge.

Reads full-Bible JSON dumps from getbible.net v2 (KJV and WEB, both public
domain), resolves every scripture_reference in challenges.json, and rewrites
the challenge files with scripture_text_kjv / scripture_text_web fields.

Usage:
    curl -sL -o /tmp/getbible_kjv.json https://api.getbible.net/v2/kjv.json
    curl -sL -o /tmp/getbible_web.json https://api.getbible.net/v2/web.json
    python3 scripts/fetch_pd_scripture.py
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

BOOK_ALIASES = {
    "psalm": "Psalms",
    "psalms": "Psalms",
    "dan": "Daniel",
    "deut": "Deuteronomy",
    "eph": "Ephesians",
    "heb": "Hebrews",
    "isa": "Isaiah",
    "song of solomon": "Song of Songs",
}

REF_RE = re.compile(
    r"^\s*(?P<book>[1-3]?\s?[A-Za-z ]+?)\s+(?P<chapter>\d+)"
    r"(?::(?P<start>\d+)(?:-(?P<end>\d+))?)?\s*$"
)


def load_bible(path):
    data = json.loads(Path(path).read_text())
    bible = {}
    for book in data["books"]:
        chapters = {}
        for ch in book["chapters"]:
            chapters[ch["chapter"]] = {v["verse"]: v["text"] for v in ch["verses"]}
        bible[book["name"].lower()] = chapters
    return bible


def normalize_book(raw):
    key = raw.strip().lower()
    return BOOK_ALIASES.get(key, raw.strip())


def clean(text):
    return " ".join(text.split())


def resolve(bible, reference):
    m = REF_RE.match(reference)
    if not m:
        raise ValueError(f"unparseable reference: {reference!r}")
    book = normalize_book(m.group("book"))
    chapters = bible.get(book.lower())
    if chapters is None:
        raise ValueError(f"unknown book {book!r} in {reference!r}")
    chapter = chapters.get(int(m.group("chapter")))
    if chapter is None:
        raise ValueError(f"missing chapter in {reference!r}")
    if m.group("start") is None:
        verse_nums = sorted(chapter)  # whole chapter, e.g. "Psalm 23"
    else:
        start = int(m.group("start"))
        end = int(m.group("end") or start)
        verse_nums = list(range(start, end + 1))
    parts = []
    for n in verse_nums:
        if n not in chapter:
            raise ValueError(f"missing verse {n} in {reference!r}")
        parts.append(clean(chapter[n]))
    text = " ".join(p for p in parts if p)
    if not text:
        raise ValueError(f"empty text for {reference!r}")
    return text


def main():
    kjv = load_bible("/tmp/getbible_kjv.json")
    web = load_bible("/tmp/getbible_web.json")

    master = REPO / "challenges.json"
    challenges = json.loads(master.read_text())

    refs = sorted({c["scripture_reference"] for c in challenges})
    resolved = {}
    failures = []
    for ref in refs:
        try:
            resolved[ref] = {
                "kjv": resolve(kjv, ref),
                "web": resolve(web, ref),
            }
        except ValueError as exc:
            failures.append(str(exc))

    if failures:
        print(f"FAILED to resolve {len(failures)} reference(s):", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)

    for c in challenges:
        texts = resolved[c["scripture_reference"]]
        rebuilt = {}
        for key, value in c.items():
            rebuilt[key] = value
            if key == "scripture_reference":
                rebuilt["scripture_text_kjv"] = texts["kjv"]
                rebuilt["scripture_text_web"] = texts["web"]
        for old in ("scripture_text_esv", "scripture_text_niv", "scripture_text_nkjv"):
            rebuilt.pop(old, None)
        c.clear()
        c.update(rebuilt)

    payload = json.dumps(challenges, indent=2, ensure_ascii=False) + "\n"
    for target in (
        master,
        REPO / "Faithfully" / "Resources" / "challenges.json",
        REPO / "FaithfullyTests" / "challenges.json",
    ):
        target.write_text(payload)
        print(f"wrote {target.relative_to(REPO)}")

    batches = [(1, 73), (74, 146), (147, 219), (220, 292), (293, 365)]
    for lo, hi in batches:
        subset = [c for c in challenges if lo <= c["day"] <= hi]
        target = REPO / f"challenges_{lo:03d}_{hi:03d}.json"
        target.write_text(json.dumps(subset, indent=2, ensure_ascii=False) + "\n")
        print(f"wrote {target.name} ({len(subset)} rows)")

    print(f"resolved {len(refs)}/{len(refs)} unique references for {len(challenges)} challenges")


if __name__ == "__main__":
    main()
