#!/usr/bin/env python3
"""Setzt mehrere Bilder zu einem Kontaktbogen zusammen (zur Sichtprüfung vor dem Hochladen).

Aufruf: python3 Store/tools/kontaktbogen.py <ziel.png> <spalten> <zellenbreite> <bild> [<bild> ...]
Die Beschriftung jeder Zelle ist der Pfad ab dem vorletzten Ordner. Rendert mit Chrome ohne Fenster.
"""
import html
import pathlib
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def main() -> int:
    out, columns, cell = pathlib.Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
    images = [pathlib.Path(p).resolve() for p in sys.argv[4:]]
    sizes = []
    for image in images:
        info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(image)],
                              capture_output=True, text=True, check=True).stdout.split()
        sizes.append((int(info[info.index("pixelWidth:") + 1]), int(info[info.index("pixelHeight:") + 1])))
    row_heights = []
    for start in range(0, len(images), columns):
        row_heights.append(max(cell * h // w for w, h in sizes[start:start + columns]) + 34)
    width, height = columns * (cell + 12) + 12, sum(row_heights) + 12
    cells = "".join(
        f'<figure><img src="{image.as_uri()}" width="{cell}"><figcaption>{html.escape("/".join(image.parts[-3:]))}</figcaption></figure>'
        for image in images)
    page = (f'<!doctype html><meta charset="utf-8"><style>body{{margin:12px 0 0 12px;background:#333;'
            f'font:13px -apple-system,sans-serif;color:#fff;display:grid;grid-template-columns:repeat({columns},{cell}px);'
            f'gap:0 12px}}figure{{margin:0 0 6px 0}}img{{display:block}}figcaption{{height:28px;line-height:28px;'
            f'white-space:nowrap;overflow:hidden}}</style>{cells}')
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as handle:
        handle.write(page)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={width},{height}", "--allow-file-access-from-files", "--virtual-time-budget=4000",
                    "--no-first-run", f"--screenshot={out}", pathlib.Path(handle.name).as_uri()],
                   check=True, timeout=240, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pathlib.Path(handle.name).unlink()
    print(out, width, height)
    return 0


if __name__ == "__main__":
    sys.exit(main())
