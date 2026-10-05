"""Fix copied ELFs and package a fat APE without changing action inputs."""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

fixup, apelink, linux_x86, linux_arm, mac_source, output, *images = sys.argv[1:]
with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR", ".")) as directory:
    copies = []
    for index, image in enumerate(images):
        copy = str(pathlib.Path(directory) / f"image{index}.elf")
        shutil.copyfile(image, copy)
        subprocess.run([fixup, copy], check=True)
        copies.append(copy)
    subprocess.run([apelink, "-s", "-G", "-V", "13", "-l", linux_x86, "-l", linux_arm, "-M", mac_source, "-o", output, *copies], check=True)
