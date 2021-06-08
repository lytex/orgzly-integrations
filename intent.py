import datetime
import shlex
import subprocess

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI()
app.state.cached_resolutions = []


@app.get("/{command}")
def read_root(request: Request):

    command = request.path_params.get("command")
    command = shlex.quote(command)  # Escape all shell characters to avoid shell injection
    command = "am " + command

    subprocess.check_output(command, shell=True)

