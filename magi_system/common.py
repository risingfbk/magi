import os
import time
from typing import Iterable


def follow(file: str) -> Iterable[str]:
    # seek the end of the file
    logfile = open(file, "r")
    logfile.seek(0, os.SEEK_END)

    # start infinite loop
    while True:
        # read last line of file
        line = logfile.readline()  # sleep if file hasn't been updated
        if not line:
            time.sleep(0.1)
            continue

        yield line
