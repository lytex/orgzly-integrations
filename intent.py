import shlex
import subprocess
from urllib.parse import unquote

from fastapi import FastAPI

app = FastAPI()
app.state.cached_resolutions = []


@app.get("/lecturenotes")
def read_root(cmd):

    cmd = unquote(cmd)
    cmd = shlex.quote(cmd)  # Escape all shell characters to avoid shell injection
    cmd = cmd[1:-1]  # Remove final and end quote
    cmd = "am start -a android.intent.action.VIEW -d lecturenotes://" + cmd

    subprocess.check_output(cmd, shell=True)
