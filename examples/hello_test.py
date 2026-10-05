import os
import pathlib
import subprocess
import sys

binary = pathlib.Path(sys.argv[1])
loader = sys.argv[2]
assert binary.read_bytes().startswith(b"MZ")
prefix = (["/bin/sh"] if os.name != "nt" else []) if loader == "-" else [str(pathlib.Path(loader).resolve())]
result = subprocess.run(prefix + [str(binary.resolve())], capture_output=True, check=True)
assert result.stdout == b"hello from Cosmopolitan\n"
