import os
import re
from glob import glob
from typing import Callable, Iterable
from uuid import uuid4

from dotenv import load_dotenv
from orgparse import loads
from orgparse.node import OrgBaseNode
from datetime import datetime, timedelta

import pandas as pd

import drawSvg as draw

from random import getrandbits


load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")


def recursive_filter(condition: Callable[[OrgBaseNode], bool], root: Iterable[OrgBaseNode]) -> Iterable[OrgBaseNode]:
    """recursively trasvese all possible nodes from root and return only those for which
        condition returns True

    Args:
        condition: condition which evaluates to true
        nodes: nodes to be traversed

    Yields each node with matches the condition
    """
    for node in root:
        if condition(node):
            yield node
        if node.children:
            yield from recursive_filter(condition, node.children)


def get_children(parent: OrgBaseNode) -> Iterable[OrgBaseNode]:
    if parent.children:
        for node in parent.children:
            yield node
            if node.children:
                yield from get_children(node)


clocked_info = []

# First pass, create ID if not exists for each heading with custom_id
for path in glob(f"{ORG_DIRECTORY}/**/*.org", recursive=True):
    if not ("/src/" in path or "/doom/" in path):
        with open(path, "r") as f:
            root = loads(f.read())
            clocked = recursive_filter(lambda x: x.clock, get_children(root))
            for item in clocked:
                clocked_info.append(
                    {
                        "id": id(item),
                        "heading": item.heading,
                        "clock": item.clock,
                        "file": path,
                        "color": "#%.6x" % getrandbits(24),
                    }
                )


df = pd.DataFrame(clocked_info)
df = df.groupby("id").max().reset_index()  # Headings are duplicated, deduplicate


from orgparse.date import OrgDateClock

# Split intervals by day
def split_by_day(clocklist: Iterable[OrgDateClock]) -> Iterable[OrgDateClock]:
    result = clocklist.copy()
    for clock in clocklist:
        if clock.start.day != clock.end.day:
            if (clock.end - clock.start).days < 1:
                # Remove entry spanning 2 days
                result.remove(clock)
                # Split into 2 days,
                result += [
                    OrgDateClock(clock.start, clock.start.replace(hour=23, minute=59)),
                    OrgDateClock(clock.end.replace(hour=0, minute=0), clock.end),
                ]
            else:
                raise NotImplementedError(f"Clocks spanning several days are not supported:\n{clock}")
    return result


df.clock = df.clock.apply(split_by_day)


max_date = df.clock.apply(lambda x: max(map(lambda x: x.end, sorted(x, key=lambda x: x.end)))).max()
max_date_start = (max_date + timedelta(days=1)).replace(hour=0, minute=0)
min_date = df.clock.apply(lambda x: min(map(lambda x: x.start, sorted(x, key=lambda x: x.start)))).min()
min_date_start = min_date.replace(hour=0, minute=0)
total_days = (max_date - min_date).days + 1

# 24h equals 100
width = 200 * total_days
height = 100

d = draw.Drawing(width, height, origin=(0, 0), displayInline=False)

# fecha = día + hora
# posición = (día*100, hora*/24*100, 90, duracion_horas/24*100)

a = []

for _, row in df.iterrows():
    for clock in row.clock:
        x = (clock.start - min_date_start).days * 100
        y = (clock.start - clock.start.replace(hour=0, minute=0)).total_seconds() / 3600 / 24 * 100
        y_length = clock.duration.total_seconds() / 3600 / 24 * 100
        a.append(y_length)
        r = draw.Rectangle(
            x,
            y,
            90,
            y_length,
            fill=row.color,
        )
        r.appendTitle(f"{row.heading}\n{clock.start}--{clock.end}→{clock.duration}")
        d.append(r)
        d.append(draw.Text(row.heading, 1 + 0.01 * y_length, x, y))


r = draw.Rectangle(-80, 0, 40, 50, fill="#1248ff")
r.appendTitle("Our first rectangle")  # Add a tooltip
d.append(r)

d.setPixelScale(2)  # Set number of pixels per geometry unit
# d.setRenderSize(400,200)  # Alternative to setPixelScale
d.saveSvg("example.svg")

a = pd.DataFrame(a)
