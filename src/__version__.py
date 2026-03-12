import os
from pathlib import Path

# Единый источник версии и ветки: файл version в корне проекта
# Формат файла:
#   version: 0.4.44
#   branch:  main
_version_file = Path(__file__).parent.parent / "version"

try:
    _lines = _version_file.read_text().splitlines()
    # Ищем строку вида "version: X.Y.Z"
    _ver_line = next((l for l in _lines if l.strip().startswith("version:")), None)
    if _ver_line:
        __version__ = '0.1.6'
    else:
        # Поддержка старого plain-формата: первая непустая строка без ключа
        _first = next(
            (l.strip() for l in _lines if l.strip() and ":" not in l.split()[0]),
            "",
        )
        __version__ = '0.1.6'
except FileNotFoundError:
    __version__ = '0.1.6'
