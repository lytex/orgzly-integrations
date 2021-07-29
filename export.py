import asyncio
import os
import subprocess
import sys
from pathlib import Path

from asyncinotify import Inotify, Mask
from dotenv import load_dotenv

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")
os.chdir(ORG_DIRECTORY)


async def main():
    # Context manager to close the inotify handle after use
    with Inotify() as inotify:
        # Adding the watch can also be done outside of the context manager.
        # __enter__ doesn't actually do anything except return self.
        # This returns an asyncinotify.inotify.Watch instance
        inotify.add_watch(ORG_DIRECTORY, Mask.CLOSE_WRITE | Mask.MOVE | Mask.DELETE | Mask.CREATE)
        # Iterate events forever, yielding them one at a time
        last_event_name = ""
        async for event in inotify:
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
