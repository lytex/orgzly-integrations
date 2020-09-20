from typing import Iterable
import os
from os.path import isdir

ORG_DIRECTORY = os.environ.get("ORG_DIRECTORY")
ORGZLY_FILE_INDEX = os.environ.get("ORGZLY_FILE_INDEX")

os.chdir(ORG_DIRECTORY)


def ls(path: str):
    files_and_dirs = os.listdir(path)
    yield path, filter(isdir, files_and_dirs), filter(lambda x: not isdir(x), files_and_dirs)


def lowercase(s: str):
    return s.lower()


def build_index(path: str, level: int) -> Iterable[str]:
    path = ls(path)

    for root, directories, files in path:
        directories, files = sorted(directories, key=lowercase), sorted(files, key=lowercase)

        for directory in directories:
            yield "*" * (level + 1) + f" {directory}"
            yield from sorted(build_index(root + "/" + directory, level + 1), key=lowercase)

        for file in files:
            if file.endswith(".org"):
                yield "*" * (level + 1) + f" [[file:{file}][{file}]]"


with open(ORGZLY_FILE_INDEX, "w") as f:
    print("\n".join(build_index(ORG_DIRECTORY, 0)), file=f)
