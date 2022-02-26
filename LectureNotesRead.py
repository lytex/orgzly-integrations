from time import sleep

from orgparse import loads

from LectureNotesIndex import *


def get_full_parent(node, max_level):
    def aux(node):
        if node.level <= max_level:
            return
        if node.heading.startswith("page") and node.heading.endswith(".png"):
            node = node.get_parent()
        else:
            yield node
            node = node.get_parent()
        yield from aux(node)

    return aux(node)


if __name__ == "__main__":

    load_dotenv()

    LECTURE_NOTES_DIRECTORY = os.getenv("LECTURE_NOTES_DIRECTORY")
    LECTURE_NOTES_ORG_FILE_INDEX = os.getenv("LECTURE_NOTES_ORG_FILE_INDEX")
    LECTURE_NOTES_PREFIX = os.getenv("LECTURE_NOTES_PREFIX")
    os.chdir(LECTURE_NOTES_DIRECTORY)

    adquire_lock_waiting()
    with open(LECTURE_NOTES_ORG_FILE_INDEX, "r") as f:
        info = loads(f.read())

    sleep(1)
    release_lock()
    tree = list(build_index(LECTURE_NOTES_DIRECTORY, 0, False))

    # paths = list(map(lambda x: f"{x[0]}/{x[1]}".replace(LECTURE_NOTES_DIRECTORY, ""), tree))
    # paths = list(map(lambda x: x[1:] if x.startswith("/") else x, paths))
    # idx = paths.index(relative) # later if needed
    for node in info[1:]:
        file = node.heading
        if file.startswith("text") and file.endswith(".txt") and file != "text.txt":
            body = node.body
            relative = "/".join(reversed(list(map(lambda x: x.heading, get_full_parent(node, 0)))))
            try:

                adquire_lock_waiting()
                with open(relative, "x"):
                    logging.info(f"{relative} does not exist, creating file...")

                sleep(1)
                release_lock()
            except FileExistsError:
                pass

            adquire_lock_waiting()
            with open(relative, "r+") as f:
                f.seek(0)
                contents = f.read()
                if contents != body:
                    logging.info(f"{relative} has changed! Writing new contents to file...")
                    f.seek(0)
                    f.write(body)
                    f.truncate()

            sleep(1)
            release_lock()
