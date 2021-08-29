import locale
import os
import re
from glob import glob
from typing import Callable, Iterable

from datetime import datetime, timedelta
from dotenv import load_dotenv
from orgparse import loads
from orgparse.node import OrgBaseNode
from pytz import timezone

import sched_config

dt = datetime.now(tz=timezone("Europe/Madrid"))
locale.setlocale(locale.LC_ALL, "es_ES.utf8")

load_dotenv()


ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")


for path in glob(f"{ORG_DIRECTORY}/Mantenimiento.org", recursive=True):
    print(path)

    with open(path, "r") as f:
        content = f.read()

    root = loads(content)
    root = list(root)

    for org_id in scheduled.keys():
        targets = [(ind + 1, x) for ind, x in enumerate(root[1:]) if x.properties.get("ID") == org_id]
        for ind, node in targets:
            content = str(node)

            if (scheduled_date := scheduled.get(org_id).get("SCHEDULED")) is not None:
                content = re.sub(r"SCHEDULED:[ ]+<[^>]+\>", f"SCHEDULED: {scheduled_date()}", content)

            if (deadline_date := scheduled.get(org_id).get("DEADLINE")) is not None:
                content = re.sub(r"DEADLINE:[ ]+<[^>]+\>", f"DEADLINE: {deadline_date()}", content)

            root[ind] = content

    result = str(root[0]) + "\n" + "\n".join([str(x) for x in root[1:]])

    if result != content:
        with open(path, "w") as f:
            # Overwrite content
            f.seek(0)
            f.write(result)
