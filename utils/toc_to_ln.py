import argparse
from typing import Dict

import fitz  # pip install pymupdf

parser = argparse.ArgumentParser(
    prog="ToC to LectureNotes",
    description="Generate the structure of keyN.txt text files for Lecture Notes based on the ToC of a pdf",
    epilog="",
)

parser.add_argument("filename")  # positional argument
args = parser.parse_args()


def get_bookmarks(filepath: str) -> Dict[int, str]:
    # WARNING! One page can have multiple bookmarks!
    bookmarks = {}
    with fitz.open(filepath) as doc:
        toc = doc.get_toc()  # [[lvl, title, page, …], …]
        for level, title, page in toc:
            bookmarks[page] = title
    return bookmarks


for page, name in get_bookmarks(args.filename).items():
    with open(f"key{page}.txt", "w") as f:
        f.write(name)
