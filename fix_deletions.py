import os
import sys

from dotenv import load_dotenv
from git import Repo

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
ORG_DIRECTORY = "."
PREVIOUS_DIR = os.getcwd()
os.chdir(ORG_DIRECTORY)

repo = Repo(ORG_DIRECTORY)

last_commit = next(repo.iter_commits())
os.chdir(PREVIOUS_DIR)

if (deleted := list(filter(lambda x: x.a_blob is None, repo.index.diff(repo.head.commit.parents[0])))) != []:
    for file in deleted:
        print(f'"{file.a_path}"', end=" ")
    sys.exit(1)
else:
    sys.exit(0)
