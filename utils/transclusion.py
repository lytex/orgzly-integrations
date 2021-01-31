import os
import re
from itertools import islice

from dotenv import load_dotenv
from git import Repo

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
PREVIOUS_DIR = os.getcwd()
os.chdir(ORG_DIRECTORY)

repo = Repo(ORG_DIRECTORY)

commits = repo.iter_commits()
prev_commits = islice(repo.iter_commits(), 1, None)


for curr, prev in zip(commits, prev_commits):

    try:
        try:
            diff = "\n".join(map(lambda x: x.diff.decode("utf-8"), curr.diff(prev, create_patch=True)))
        except UnicodeDecodeError:
            # fmt: off
            diff = "\n".join(
                map(lambda x: x.diff.decode(" iso-8859-1 ").encode("utf-8").decode("utf-8"),
                    curr.diff(prev, create_patch=True)))
            # fmt: on
        if re.search(r"-#\+transclude", diff) and not re.search(r"\+#\+transclude", diff):
            diff = re.sub(r"^-.*$", r"\033[31m\g<0>\033[0m", diff, flags=re.MULTILINE)
            diff = re.sub(r"^\+.*$", r"\033[32m\g<0>\033[0m", diff, flags=re.MULTILINE)
            print(diff)
    except BrokenPipeError:
        break
