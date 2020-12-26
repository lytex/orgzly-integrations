#!/usr/bin/python3

import locale
import os
from datetime import datetime

from dotenv import load_dotenv

load_dotenv()

ORG_DIRECTORY = os.getenv("ORG_DIRECTORY")

dt = datetime.now()
locale.setlocale(locale.LC_ALL, "es_ES.utf8")
with open(dt.strftime(f"{ORG_DIRECTORY}/journal/%Y-%m-%d.org")) as journal:
    print(dt.strftime("%A, %d de %B de %Y"), file=journal)
