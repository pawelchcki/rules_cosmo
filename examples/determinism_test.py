"""Different output names force independent link actions; every byte must match."""
import hashlib
import pathlib
import sys

first, second = [pathlib.Path(p).read_bytes() for p in sys.argv[1:]]
assert first == second, "independent Cosmopolitan builds differ"
print("APE SHA-256:", hashlib.sha256(first).hexdigest())
