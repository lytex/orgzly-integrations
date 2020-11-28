#!/usr/bin/python3

import os
import sys

from dotenv import load_dotenv
from git import Repo

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
os.chdir(ORG_DIRECTORY)

repo = Repo(ORG_DIRECTORY)

last_commit = next(repo.iter_commits())

if last_commit.stats.total["deletions"] - last_commit.stats.total["insertions"] > 50:
    sys.exit(1)
else:
    sys.exit(0)
