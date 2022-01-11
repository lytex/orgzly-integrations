import locale
import os
import re
from datetime import datetime
from glob import glob

from dotenv import load_dotenv
from orgparse import loads
from pytz import timezone

import sched_config
from sched_config import scheduled

dt = datetime.now(tz=timezone("Europe/Madrid"))
locale.setlocale(locale.LC_ALL, "es_ES.utf8")

load_dotenv()


ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")


for path in glob(f"{ORG_DIRECTORY}/**/*.org", recursive=True) + glob(f"{ORG_DIRECTORY}/*.org"):
    print(path)

    with open(path, "r") as f:
        content = f.read()

    root = loads(content)
    root = list(root)
    # Copy root so that we ensure we are always iterating over a list of OrgNode
    # root is going to be modified so it well be a mix of OrgNode and str
    root_copy = root.copy()

    for org_id in scheduled.keys():
        targets = [(ind + 1, x) for ind, x in enumerate(root_copy[1:]) if x.properties.get("ID") == org_id]
        for ind, node in targets:
            content = str(node)

            scheduled_date = scheduled.get(org_id).get("SCHEDULED")
            if scheduled_date is not None:
                content = re.sub(r"SCHEDULED:[ ]+<[^>]+\>", f"SCHEDULED: {scheduled_date()}", content)

            deadline_date = scheduled.get(org_id).get("DEADLINE")
            if deadline_date is not None:
                content = re.sub(r"DEADLINE:[ ]+<[^>]+\>", f"DEADLINE: {deadline_date()}", content)

            event_date = scheduled.get(org_id).get("EVENT")
            if event_date is not None:
                content = re.sub(r"\n<[^>]+\>\n", f"\n{event_date()}\n", content, re.MULTILINE)

            if scheduled.get(org_id).get("REMOVE_LOGBOOK"):
                content = re.sub(r":LOGBOOK:\n(\n.+)+?:END:", "", content)

            # ind allows us to relate it back to root
            # node is not directly modified, only content
            root[ind] = content

    result = str(root[0]) + "\n" + "\n".join([str(x) for x in root[1:]])

    if result != content:
        with open(path, "w") as f:
            # Overwrite content
            f.seek(0)
            f.write(result)
