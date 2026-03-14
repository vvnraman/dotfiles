import logging
import subprocess

from dotfiles.util import L


class Command:
    def __init__(self, name: str, args: list[str]):
        self.name: str = name
        self.args: list[str] = args

    def __str__(self) -> str:
        return self.name + " \t= " + " ".join(self.args)


def run_live(cmd: Command, dry_run: bool):
    logging.info(f"{L.B} Running {cmd}")

    if dry_run:
        return

    with subprocess.Popen(
        cmd.args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1
    ) as proc:
        if proc.stdout is None:
            raise RuntimeError(f"Failed to capture stdout for command '{cmd.name}'")

        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            if line:
                logging.info(line.rstrip("\n"))

        _ = proc.wait(timeout=5)

        rc = proc.returncode
        if 0 == rc:
            logging.info(f"{L.C} {cmd.name} finished with rc={rc}")
        else:
            logging.warning(f"{L.E} {cmd.name} finished with rc={rc}")
        if 0 != rc:
            raise subprocess.CalledProcessError(rc, cmd.name)
