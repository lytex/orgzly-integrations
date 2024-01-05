import os
from functools import partial, reduce
from itertools import accumulate, groupby

import pandas as pd
from dotenv import load_dotenv
from git import Repo

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
PREVIOUS_DIR = os.getcwd()
os.chdir(ORG_DIRECTORY)

repo = Repo(ORG_DIRECTORY)

# source = list(repo.iter_commits())[:1000]
source = repo.iter_commits()

# Get files changed and committed date per unique set of files
aa = map(lambda x: (set(x.stats.files.keys()), x.committed_date), source)
# Multi commit files have multiple keys per
aa = ((z, y) for x, y in aa for z in x)

# Group by first row as key
cc = [(k, list(map(lambda x: x, list(zip(*list(g)))[1]))) for k, g in groupby(aa, lambda x: x[0])]


# Calculate max datetime for each one
dd = list(map(lambda x: (x[0], reduce(lambda y, z: max(y, z), x[1])), cc))

df = pd.DataFrame(dd).rename(columns={0: "file", 1: "timestamp"})
