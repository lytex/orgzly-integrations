import asyncio
import os
import subprocess
import sys
from pathlib import Path
from typing import AsyncGenerator, Generator

from asyncinotify import Event, Inotify, Mask
from dotenv import load_dotenv

load_dotenv()

with open(".lnignore") as f:
    ignored = f.read().split("\n")

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
os.chdir(ORG_DIRECTORY)


# from https://gitlab.com/Taywee/asyncinotify/-/blob/master/examples/recursivewatch.py


def get_directories_recursive(path: Path) -> Generator[Path, None, None]:
    """Recursively list all directories under path, including path itself, if
    it's a directory.

    The path itself is always yielded before its children are iterated, so you
    can pre-process a path (by watching it with inotify) before you get the
    directory listing.

    Passing a non-directory won't raise an error or anything, it'll just yield
    nothing.
    """

    if path.is_dir():
        yield path
        for child in path.iterdir():
            yield from get_directories_recursive(child)


async def watch_recursive(path: Path, mask: Mask) -> AsyncGenerator[Event, None]:
    with Inotify() as inotify:
        for directory in get_directories_recursive(path):
            print(os.realpath(directory, ORG_DIRECTORY))
            if not any(map(lambda x: os.path.relpath(directory, ORG_DIRECTORY).startswith(x), ignored)):
                print(f"INIT: watching {directory}")
                inotify.add_watch(
                    directory, mask | Mask.MOVED_FROM | Mask.MOVED_TO | Mask.CREATE | Mask.DELETE_SELF | Mask.IGNORED
                )

        # Things that can throw this off:
        #
        # * Moving a watched directory out of the watch tree (will still
        #   generate events even when outside of directory tree)
        #
        # * Doing two changes on a directory or something before the program
        #   has a time to handle it (this will also throw off a lot of inotify
        #   code, though)
        #
        # * Moving a watched directory within a watched directory will get the
        #   wrong path.  This needs to use the cookie system to link events
        #   together and complete the move properly, which can still make some
        #   events get the wrong path if you get file events during the move or
        #   something silly like that, since MOVED_FROM and MOVED_TO aren't
        #   guaranteed to be contiguous.  That exercise is left up to the
        #   reader.
        #
        # * Trying to watch a path that doesn't exist won't automatically
        #   create it or anything of the sort.
        #
        # * Deleting and recreating or moving the watched directory won't do
        #   anything special, but it probably should.
        async for event in inotify:

            # Add subdirectories to watch if a new directory is added.  We do
            # this recursively here before processing events to make sure we
            # have complete coverage of existing and newly-created directories
            # by watching before recursing and adding, since we know
            # get_directories_recursive is depth-first and yields every
            # directory before iterating their children, we know we won't miss
            # anything.
            if Mask.CREATE in event.mask and event.path is not None and event.path.is_dir():
                for directory in get_directories_recursive(event.path):
                    if not any(map(lambda x: os.path.relpath(directory, ORG_DIRECTORY).startswith(x), ignored)):
                        print(f"EVENT: watching {directory}")
                        inotify.add_watch(
                            directory,
                            mask | Mask.MOVED_FROM | Mask.MOVED_TO | Mask.CREATE | Mask.DELETE_SELF | Mask.IGNORED,
                        )

            # If there is at least some overlap, assume the user wants this event.
            if event.mask & mask:
                yield event
            else:
                # Note that these events are needed for cleanup purposes.
                # We'll always get IGNORED events so the watch can be removed
                # from the inotify.  We don't need to do anything with the
                # events, but they do need to be generated for cleanup.
                # We don't need to pass IGNORED events up, because the end-user
                # doesn't have the inotify instance anyway, and IGNORED is just
                # used for management purposes.
                print(f"UNYIELDED EVENT: {event}")


async def main():
    last_event_name = ""
    async for event in watch_recursive(Path(ORG_DIRECTORY), Mask.CLOSE_WRITE | Mask.MOVE | Mask.DELETE | Mask.CREATE):
        print(f"MAIN: got {event} for path {event.path}")
        if str(event.name).endswith(".org") and str(event.name) != last_event_name:
            cmd = (
                "emacs --batch --eval="
                '\'(progn (load-file "$HOME/.emacs.d/early-init.el") (load-file "$HOME/.emacs.d/init.el" )'
                f'(find-file "{event.path}") (org-transclusion-mode t) (org-html-export-to-html))\''
            )
            print(cmd)
            subprocess.run(
                cmd,
                stdout=sys.stdout,
                shell=True,
            )
            last_event_name = str(event.name)


loop = asyncio.get_event_loop()
try:
    loop.run_until_complete(main())
except KeyboardInterrupt:
    print("shutting down")
finally:
    loop.run_until_complete(loop.shutdown_asyncgens())
    loop.close()