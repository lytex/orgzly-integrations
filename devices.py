import locale
import os
import re

from datetime import datetime
from dotenv import load_dotenv
from orgparse import loads
from pytz import timezone

import dev_config
from dev_config import scheduled

dt = datetime.now(tz=timezone("Europe/Madrid"))
locale.setlocale(locale.LC_ALL, "es_ES.utf8")

load_dotenv()


ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
DEVICE_PATH = os.getenv("DEVICE_PATH")


path = f"{ORG_DIRECTORY}/{DEVICE_PATH}"
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

        if node.todo != "TODO":
            content = str(node)

            if (scheduled_date := scheduled.get(org_id).get("SCHEDULED")) is not None:
                content = re.sub(r"SCHEDULED:[ ]+<[^>]+\>", f"SCHEDULED: {scheduled_date()}", content)

            if (deadline_date := scheduled.get(org_id).get("DEADLINE")) is not None:
                content = re.sub(r"DEADLINE:[ ]+<[^>]+\>", f"DEADLINE: {deadline_date()}", content)

            if (event_date := scheduled.get(org_id).get("EVENT")) is not None:
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
