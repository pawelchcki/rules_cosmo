import pathlib
import subprocess
import sys

binary, loader = map(pathlib.Path, sys.argv[1:])
assert binary.read_bytes().startswith(b"MZ")
result = subprocess.run([str(loader.resolve()), str(binary.resolve())], capture_output=True, check=True)
assert result.stdout == b"hello from Cosmopolitan\n"
