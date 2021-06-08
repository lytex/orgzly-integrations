import os
from os.path import isdir, isfile
from typing import Iterable

from dotenv import load_dotenv


def ls(path: str):
    files_and_dirs = os.listdir(path)
    files_and_dirs = [os.path.join(path, x) for x in files_and_dirs]
    dirs, files = list(filter(isdir, files_and_dirs)), list(filter(lambda x: isfile(x), files_and_dirs))
    dirs = [x.replace(os.path.join(path + ""), "") for x in dirs]
    files = [x.replace(os.path.join(path, ""), "") for x in files]
    yield path, dirs, files


def lowercase(s: str):
    return s.lower()


def build_index(path: str, level: int) -> Iterable[str]:
    print(path)
    path = list(ls(path))
    print(path)

    for root, directories, files in path:
        directories, files = sorted(directories, key=lowercase), sorted(files, key=lowercase)

        for directory in directories:
            yield "*" * (level + 1) + f" {directory}"
            yield from sorted(build_index(root + "/" + directory, level + 1), key=lowercase)

        for file in files:
            if file.endswith(".png") and file.startswith("page"):
                link = root.replace(LECTURE_NOTES_DIRECTORY, "")[1:] + "/" + file
                yield "*" * (level + 1) + f" {file}\n[[file:{link}][{file}]]"


load_dotenv()

LECTURE_NOTES_DIRECTORY = os.getenv("LECTURE_NOTES_DIRECTORY")
LECTURE_NOTES_ORG_FILE_INDEX = os.getenv("LECTURE_NOTES_ORG_FILE_INDEX")
os.chdir(LECTURE_NOTES_DIRECTORY)


with open(LECTURE_NOTES_ORG_FILE_INDEX, "w") as f:

    print("#+STARTUP: inlineimages\n" + "\n".join(build_index(LECTURE_NOTES_DIRECTORY, 0)), file=f)
