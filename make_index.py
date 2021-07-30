import os
from os.path import isdir, isfile
from typing import Iterable

from dotenv import load_dotenv

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
ORGZLY_FILE_INDEX = os.getenv("ORGZLY_FILE_INDEX")
with open(".lnignore") as f:
    ignored = f.read().split("\n")

os.chdir(ORG_DIRECTORY)


def ls(path: str):
    files_and_dirs = os.listdir(path)
    files_and_dirs = [os.path.join(path, x) for x in files_and_dirs]
    dirs, files = list(filter(isdir, files_and_dirs)), list(filter(lambda x: isfile(x), files_and_dirs))
    dirs = [x.replace(os.path.join(path, ""), "") for x in dirs]
    files = [x.replace(os.path.join(path, ""), "") for x in files]
    yield path, dirs, files


def lowercase(s: str):
    return s.lower()


def build_index(path: str, level: int) -> Iterable[str]:
    path = list(ls(path))

    for root, directories, files in path:
        directories, files = sorted(directories, key=lowercase), sorted(files, key=lowercase)

        for directory in directories:
            if directory not in ignored:
                yield "*" * (level + 1) + f" {directory}"
                yield from build_index(os.path.join(root, directory), level + 1)

        for file in files:
            if file.endswith(".org"):
                yield "*" * (level + 1) + f" [[file:{file}][{file}]]"


with open(ORGZLY_FILE_INDEX, "w") as f:
    print("#+FILETAGS: :private:\n" + "\n".join(build_index(ORG_DIRECTORY, 0)), file=f)
