import shlex
import subprocess
from urllib.parse import unquote


from fastapi import FastAPI

app = FastAPI()
app.state.cached_resolutions = []


@app.get("/am")
def read_root(cmd):

    cmd = unquote(cmd)
    cmd = shlex.quote(cmd)  # Escape all shell characters to avoid shell injection
    cmd = "am " + cmd

    subprocess.check_output(cmd, shell=True)
