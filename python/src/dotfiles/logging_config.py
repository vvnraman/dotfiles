import logging
import logging.config
import os
from datetime import datetime
from pathlib import Path

_configured = False


def _today_log_path() -> Path:
    tmp_root = Path(os.getenv("TMPDIR", "/tmp")).expanduser()
    tmp_root.mkdir(parents=True, exist_ok=True)
    date_name = datetime.now().strftime("%Y_%m_%d")
    return tmp_root / f"dotfile_{date_name}.log"


def _logging_config(log_path: Path) -> dict[str, object]:
    return {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "stream": {
                "format": "%(levelname)s %(filename)s:%(lineno)d %(message)s",
            },
            "file": {
                "format": "%(asctime)s %(levelname)s %(filename)s:%(lineno)d %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
        },
        "handlers": {
            "stream": {
                "class": "logging.StreamHandler",
                "level": "INFO",
                "formatter": "stream",
                "stream": "ext://sys.stdout",
            },
            "file": {
                "class": "logging.FileHandler",
                "level": "INFO",
                "formatter": "file",
                "filename": str(log_path),
                "encoding": "utf-8",
            },
        },
        "root": {
            "handlers": ["stream", "file"],
            "level": "INFO",
        },
    }


def configure_logging() -> None:
    global _configured
    if _configured:
        return

    logging.config.dictConfig(_logging_config(log_path=_today_log_path()))
    _configured = True
