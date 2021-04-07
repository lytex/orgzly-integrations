import os
import re
from glob import glob
from typing import Callable, Iterable
from uuid import uuid4

from dotenv import load_dotenv
from orgparse import loads
from orgparse.node import OrgBaseNode

from dotenv import load_dotenv

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
    with open(path, "r") as f:
        root = loads(f.read())
        clocked = recursive_filter(lambda x: x.clock, get_children(root))
        for item in clocked:
            clocked_info.append({'id': id(item), 'heading': item.heading, 'clock': item.clock})
