#!/usr/bin/python3

import os
import locale
from datetime import datetime
from dotenv import load_dotenv
from pytz import timezone

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")

dt = datetime.now(tz=timezone("Europe/Madrid"))
locale.setlocale(locale.LC_ALL, "es_ES.utf8")
with open(dt.strftime(f"{ORG_DIRECTORY}/journal/%Y-%m-%d.org"), "w") as journal:
    print(dt.strftime("* %A, %d de %B de %Y"), file=journal)
