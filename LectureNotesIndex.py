import os
import re
from os.path import isdir, isfile
from typing import Iterable

from dotenv import load_dotenv

intent_uri = (
    "http://127.0.0.1:8000/am?cmd=start%%20-a%%20android.intent.action.VIEW%%20-d%%20%%22lecturenotes://{path}%%22"
)


def ls(path: str):
    files_and_dirs = os.listdir(path)
    files_and_dirs = [os.path.join(path, x) for x in files_and_dirs]
    dirs, files = list(filter(isdir, files_and_dirs)), list(filter(lambda x: isfile(x), files_and_dirs))
    dirs = [x.replace(os.path.join(path, ""), "") for x in dirs]
    files = [x.replace(os.path.join(path, ""), "") for x in files]
    yield path, dirs, files


def lowercase(s: str):
    high = 10000
    if s.startswith("page") and s.endswith(".png") and s != "page.png":
        return int(s[4:-4]) * high
    if s.startswith("text") and s.endswith(".txt") and s != "text.txt":
        second = 0
        try:
            # text2_1.txt
            first = int(re.sub(r"text([0-9]+)_([0-9]+).txt", r"\1", s))
            second = int(re.sub(r"text([0-9]+)_([0-9]+).txt", r"\2", s))
        except ValueError:
            # text2.txt
            first = int(re.sub(r"text([0-9]+).txt", r"\1", s))

        return first * high + second
    else:
        return -1


def build_index(path: str, level: int) -> Iterable[str]:
    path = list(ls(path))
    # print(path)

    for root, directories, files in path:
        directories, files = sorted(directories, key=lambda x: x.lower()), sorted(files, key=lowercase)

        for directory in directories:
            yield "*" * (level + 1) + f" {directory}"
            yield from build_index(os.path.join(root, directory), level + 1)

        for file in files:
            if file.endswith(".png") and file.startswith("page") and file != "page.png":
                link = os.path.join(root.replace(LECTURE_NOTES_DIRECTORY, ""), file)
                uri = re.sub(r"page([0-9]+).png", r"\1/", link)
                notebook = intent_uri.format(path=uri)
                yield "*" * (level + 1) + f" {file}\n[[file:{LECTURE_NOTES_PREFIX}{link}]]\n[[{notebook}][{file}]]"
            elif file.endswith(".txt") and file.startswith("text") and file != "text.txt":
                with open(f"{root}/{file}") as f:
                    contents = "*" * (level + 2) + " " + file.replace(".txt", "") + "\n" + f.read()
                yield contents


load_dotenv()

LECTURE_NOTES_DIRECTORY = os.getenv("LECTURE_NOTES_DIRECTORY")
LECTURE_NOTES_ORG_FILE_INDEX = os.getenv("LECTURE_NOTES_ORG_FILE_INDEX")
LECTURE_NOTES_PREFIX = os.getenv("LECTURE_NOTES_PREFIX")
os.chdir(LECTURE_NOTES_DIRECTORY)


with open(LECTURE_NOTES_ORG_FILE_INDEX, "w") as f:

    print(
        "#+TITLE: LectureNotesIndex\n#+STARTUP: inlineimages\n#+FILETAGS: :private:\n"
        + "\n".join(build_index(LECTURE_NOTES_DIRECTORY, 0)),
        file=f,
    )
