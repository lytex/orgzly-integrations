import os
import re
from glob import glob
from typing import Callable, Iterable
from uuid import uuid4

from dotenv import load_dotenv
from orgparse import loads
from orgparse.node import OrgBaseNode

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
ORGZLY_CUSTOM_ID_FILE = os.getenv("ORGZLY_CUSTOM_ID_FILE")

# Global variables specifying what whe mean when we say directorypath, orgfile, linkname, ...
# ext4 allows every character except / and NULL to be part of a directory or filename
directorypath_regex = r"([^\[\]/]*/)+"
orgfile_regex = r"[^\[\]/]*\.org"
linkname_regex = r"[^\[\]]+"
linksearch_regex = r"[\*#]" + linkname_regex
generic_orglink_regex = r"[^\[\]]+"


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


# This dictionary maps each custom_id to their id (either existent id or newly generated id)
custom_to_id = {}


def add_id(node: OrgBaseNode) -> str:
    """add id if not exists to the str representation of an OrgBaseNode, using custom_to_id dict"""

    if (node.properties.get("custom_id") in custom_to_id.keys()) and (
        set(node.properties.keys()).intersection(set(("id", "ID", "iD", "Id"))) == set()
    ):
        return re.sub(
            r"(:custom_id: " + node.properties["custom_id"] + r")",
            r"\1\n:ID: " + custom_to_id[node.properties["custom_id"]],
            str(node),
        )
    else:
        return str(node)


def substitute_customid_links(content: str) -> str:
    # Substitute simple links [[#link]]
    content = re.sub(r"\[\[#" + custom + r"\]\]", f"[[id:{uuid}][{custom}]]", content)

    # Substitute links with names [[#link][name]]
    content = re.sub(
        r"\[\[#" + custom + r"\]\[(" + linkname_regex + r")\]\]",
        "[[id:" + uuid + r"][\1]]",
        content,
    )

    return content


def add_orgzly_flat_links(content: str) -> str:
    """Strips the directories out of file links to work with orgzly, flattening the directory structure in one big
    directory so that orgzly can work with it
    Also retains the previous links with \g<0> so that everything works as normal in emacs"""

    # Substitute simple links [[file:folder1/folder2/my.org]] -> [[file:my.org]]
    # Substitute links with names [[file:folder1/folder2/my.org][name]] ->[[file:my.org][name]]
    content = re.sub(
        r"\[\[file:"
        + directorypath_regex
        + r"("
        + orgfile_regex
        + r")\]((:?\["
        + linkname_regex
        + r"\])?)\]"
        + r"(?! \[\[file:\2\]\3\])",  # Do not replace if already replaced
        r"\g<0> [[file:\2]\3]",
        content,
    )

    # Substitute simple links [[file:~/Documents/doc.pdf]] -> [[file:Documents/doc.pdf]]
    # Substitute links with names [[file:~/Documents/doc.pdf][Name]] -> [[file:Documents/doc.pdf][Name]]
    content = re.sub(
        r"\[\[file:~/"
        + r"("
        + generic_orglink_regex
        + r")\]((:?\["
        + linkname_regex
        + r"\])?)\]"
        + r"(?! \[\[file:\1\]\2\])",  # Do not replace if already replaced
        r"\g<0> [[file:\1]\2]",
        content,
    )

    return content


# First pass, create ID if not exists for each heading with custom_id
for path in glob(f"{ORG_DIRECTORY}/**/*.org", recursive=True):
    with open(path, "r") as f:
        root = loads(f.read())

    custom_id = recursive_filter(lambda x: x.properties.get("custom_id") is not None, get_children(root))

    for item in custom_id:
        uuid = item.properties.get("ID", str(uuid4()))  # Create id if not exists only
        custom_to_id.update({item.properties["custom_id"]: uuid})

    if ORGZLY_CUSTOM_ID_FILE is not None:
        with open(ORGZLY_CUSTOM_ID_FILE, "w") as f:
            for custom_id, regular_id in custom_to_id.items():
                f.write(f"* [[id:{regular_id}][{custom_id}]]\n")

    result = str(root[0]) + "\n" + "\n".join([add_orgzly_flat_links(add_id(x)) for x in root[1:]])

    with open(path, "w") as f:
        # Overwrite content
        f.seek(0)
        f.write(result)

# Second pass, substitute links with the custom_to_id mapping
for path in glob(f"{ORG_DIRECTORY}/**/*.org", recursive=True):

    with open(path, "r") as f:
        content = f.read()

    for custom, uuid in custom_to_id.items():
        content = substitute_customid_links(content)  # TODO Try to do it node by node, seems faster

    with open(path, "w") as f:
        # Overwrite content
        f.seek(0)
        f.write(content)
