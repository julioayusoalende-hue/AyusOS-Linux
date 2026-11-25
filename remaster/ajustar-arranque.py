#!/usr/bin/env python3
"""Adapta el menú de arranque de Debian Live a AyusOS."""

from pathlib import Path
import re
import sys

PARAMETERS = (
    "locales=es_ES.UTF-8 "
    "keyboard-layouts=es "
    "timezone=Europe/Madrid "
    "hostname=ayusos"
)


def adjust(filename: str) -> None:
    path = Path(filename)
    original = path.read_bytes()
    lines = original.splitlines(keepends=True)
    is_grub = "grub" in path.parts
    is_isolinux = "isolinux" in path.parts
    changed = False
    result: list[bytes] = []

    for index, line in enumerate(lines):
        stripped = line.lstrip()
        is_grub_live = is_grub and re.match(rb"linux\s", stripped) and b"/live/" in line
        is_isolinux_live = is_isolinux and stripped.startswith(b"append ") and b"boot=live" in line
        if (is_grub_live or is_isolinux_live) and b"locales=es_ES.UTF-8" not in line:
            ending = b"\r\n" if line.endswith(b"\r\n") else b"\n" if line.endswith(b"\n") else b""
            body = line[: -len(ending)] if ending else line
            line = body + b" " + PARAMETERS.encode("ascii") + ending
            changed = True

        if path.name == "grub.cfg":
            line = line.replace(
                b"Live system (amd64 fail-safe mode)",
                b"AyusOS Linux (Live, modo seguro)",
            ).replace(b"Live system (amd64)", b"AyusOS Linux (Live)")
        elif path.name == "live.cfg":
            line = line.replace(
                b"Live system (amd64 fail-safe mode)",
                b"AyusOS Linux (Live, modo seguro)",
            ).replace(b"^Live system (amd64)", b"^AyusOS Linux (Live)")
        elif path.name == "menu.cfg" and stripped.startswith(b"menu title Boot menu"):
            line = b"menu title AyusOS Linux\n"
        elif path.name == "theme.txt":
            line = line.replace(
                b'title-text: "Live Boot Menu with GRUB"',
                b'title-text: "AyusOS Linux"',
            )

        if line != lines[index]:
            changed = True
        result.append(line)

    if changed:
        path.write_bytes(b"".join(result))
        print(f"Arranque ajustado: {path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Uso: ajustar-arranque.py ARCHIVO [ARCHIVO ...]")
    for filename in sys.argv[1:]:
        adjust(filename)
