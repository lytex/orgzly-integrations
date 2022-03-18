import logging
import os
import re
from os.path import isdir, isfile
from time import sleep
from typing import Iterable

from dotenv import load_dotenv

intent_uri = (
    "http://127.0.0.1:8000/am?cmd=start%%20-a%%20android.intent.action.VIEW%%20-d%%20%%22lecturenotes://{path}%%22"
)

FORMAT = "%(asctime)s.%(msecs)03d %(levelname)s:%(filename)s:%(message)s"
FILENAME = "123.log"
logging.basicConfig(filename=FILENAME, level=logging.INFO, datefmt="%Y-%m-%d %H:%M:%S", format=FORMAT)


def adquire_lock_waiting():
    try:
        adquire_lock()
    except RuntimeError:
        wait_lock_release()


def wait_lock_release():
    logging.info("Waiting for lock...")
    while os.system(f"ls \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\"") == 0:
        sleep(1)
    if (
        os.system(
            f"! ls \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\" &> /dev/null && touch \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\""
        )
        == 0
    ):
        logging.info("Lock adquired")
    else:
        raise RuntimeError("Lock could not be adquired")


def release_lock():
    if (
        os.system(
            f"ls \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\" &> /dev/null && rm \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\""
        )
        == 0
    ):
        logging.info("Lock released")
    else:
        raise RuntimeError("Lock could not be released")


def adquire_lock():
    if (
        os.system(
            f"! ls \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\" &> /dev/null && touch \"{os.environ['LECTURE_NOTES_ORG_LOCK_FILE']}\""
        )
        == 0
    ):
        logging.info("Lock adquired")
    else:
        raise RuntimeError("Lock could not be adquired")


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
        # Order for textN.txt, after pageN.png but before textN_1.txt
        second = 0.5
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


def build_index(path: str, level: int, write=True) -> Iterable[str]:
    path = list(ls(path))
    # print(path)

    for root, directories, files in path:
        directories, files = sorted(directories, key=lambda x: x.lower()), sorted(files, key=lowercase)

        for directory in directories:
            if write:
                yield "*" * (level + 1) + f" {directory}"
            else:
                yield root, directory
            yield from build_index(os.path.join(root, directory), level + 1, write)

        for file in files:
            if file.endswith(".png") and file.startswith("page") and file != "page.png":
                if write:
                    link = os.path.join(root.replace(LECTURE_NOTES_DIRECTORY, ""), file)
                    uri = re.sub(r"page([0-9]+).png", r"\1/", link)
                    notebook = intent_uri.format(path=uri)
                    yield "*" * (
                        level + 1
                    ) + f" {file}\n#+ATTR_ORG: :width 430\n[[file:{LECTURE_NOTES_PREFIX}{link}]]\n[[{notebook}][{file}]]"
                else:
                    yield root, file
            elif file.endswith(".txt") and file.startswith("text") and file != "text.txt":
                if write:
                    adquire_lock_waiting()
                    with open(f"{root}/{file}") as f:
                        contents = "*" * (level + 2) + " " + file + "\n" + f.read()
                    sleep(1)
                    release_lock()
                    yield contents
                else:
                    yield root, file


if __name__ == "__main__":

    load_dotenv()

    LECTURE_NOTES_DIRECTORY = os.getenv("LECTURE_NOTES_DIRECTORY")
    LECTURE_NOTES_ORG_FILE_INDEX = os.getenv("LECTURE_NOTES_ORG_FILE_INDEX")
    LECTURE_NOTES_PREFIX = os.getenv("LECTURE_NOTES_PREFIX")
    os.chdir(LECTURE_NOTES_DIRECTORY)

    file_contents = "#+TITLE: LectureNotesIndex\n#+STARTUP: inlineimages\n#+FILETAGS: :private:\n" + "\n".join(
        build_index(LECTURE_NOTES_DIRECTORY, 0)
    )
    adquire_lock_waiting()
    with open(LECTURE_NOTES_ORG_FILE_INDEX, "w") as f:
        f.write(file_contents)

    sleep(1)
    release_lock()
