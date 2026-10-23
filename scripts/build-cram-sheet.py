#!/usr/bin/env python3
"""
Collect every EXAM TIP / EXAM TRAP callout from labs/*.md into
docs/exam-tips-cram-sheet.md, grouped by lab. Re-run after editing labs.

Usage:  python3 scripts/build-cram-sheet.py
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
out = ["# AZ-104 Exam Tips Cram Sheet",
       "",
       "Generated from the 🎯 EXAM TIP and ⚠️ EXAM TRAP callouts in every lab by `scripts/build-cram-sheet.py`. "
       "Don't edit this file directly: edit the lab and re-run the script.",
       "",
       "How to use it: read one lab's section, cover the detail, and explain each tip out loud. "
       "If you can't, go back to that lab's task.",
       ""]
total = 0
toc = []
sections = []

for lab in sorted((ROOT / "labs").glob("*.md")):
    lines = lab.read_text().splitlines()
    title = lines[0].lstrip("# ").strip()
    tips, i = [], 0
    while i < len(lines):
        if lines[i].startswith("> [!TIP]") or lines[i].startswith("> [!CAUTION]"):
            block = []
            i += 1
            while i < len(lines) and lines[i].startswith(">"):
                block.append(lines[i][1:].lstrip() if lines[i] != ">" else "")
                i += 1
            text = "\n".join(block).strip()
            if "EXAM" in text.split("\n")[0] or "TRAP" in text.split("\n")[0]:
                tips.append(text)
            continue
        i += 1
    if not tips:
        continue
    anchor = re.sub(r"[^a-z0-9 -]", "", title.lower()).replace(" ", "-")
    toc.append(f"- [{title}](#{anchor}) ({len(tips)})")
    sections.append(f"## {title}\n\nSource: [`labs/{lab.name}`](../labs/{lab.name})\n")
    for t in tips:
        sections.append(t + "\n")
    total += len(tips)

out.insert(4, f"**{total} tips** across {len(toc)} labs.\n")
out += ["## Contents", ""] + toc + [""] + sections
(ROOT / "docs/exam-tips-cram-sheet.md").write_text("\n".join(out).rstrip() + "\n")
print(f"Wrote docs/exam-tips-cram-sheet.md with {total} tips from {len(toc)} labs")
