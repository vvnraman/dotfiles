import logging
import subprocess
from dataclasses import dataclass
from pathlib import Path

from dotfiles.util import L


@dataclass(frozen=True)
class Command:
    name: str
    args: list[str]

    def __str__(self) -> str:
        return f"{self.name} \t= {' '.join(self.args)}"


@dataclass(frozen=True)
class ProcessResult:
    returncode: int
    stdout: str
    stderr: str

    @classmethod
    def from_returncode(cls, returncode: int) -> "ProcessResult":
        return cls(returncode=returncode, stdout="", stderr="")


class RunOutputError(RuntimeError):
    def __init__(self, command_args: list[str], result: ProcessResult):
        self.command_args = command_args
        self.result = result
        stderr = result.stderr.strip()
        message = (
            f"Command failed with rc={result.returncode}: {' '.join(command_args)}"
        ) + (f" | stderr: {stderr}" if stderr else "")
        super().__init__(message)


def run_capture(command_args: list[str]) -> ProcessResult:
    proc = subprocess.run(
        command_args,
        capture_output=True,
        text=True,
        check=False,
    )
    return ProcessResult(
        returncode=proc.returncode,
        stdout=proc.stdout,
        stderr=proc.stderr,
    )


def run_output(command_args: list[str]) -> str:
    result = run_capture(command_args)
    if result.returncode != 0:
        raise RunOutputError(command_args, result)
    return result.stdout.strip()


def run_only(
    command_args: list[str],
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> None:
    proc = subprocess.run(
        command_args,
        capture_output=False,
        text=True,
        check=False,
        cwd=cwd,
        env=env,
    )
    if proc.returncode != 0:
        raise RunOutputError(
            command_args,
            ProcessResult.from_returncode(proc.returncode),
        )


def run_live(cmd: Command, dry_run: bool) -> None:
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
        if rc == 0:
            logging.info(f"{L.C} {cmd.name} finished with rc={rc}")
        else:
            logging.warning(f"{L.E} {cmd.name} finished with rc={rc}")
        if rc != 0:
            raise RunOutputError(cmd.args, ProcessResult.from_returncode(rc))
