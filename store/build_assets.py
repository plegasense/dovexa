"""Genera capturas, gráfico de funciones e imágenes de la ficha de Play para un idioma.
Uso: python3 build_assets.py <código> …   (lee textos/<código>.json y shots/<código>/<escena>.png)"""
import json, os, sys
import compose

SCENES = ["step", "fdm", "cnc", "stl", "cloud", "dxf"]
NAMES = ["01-step", "02-print3d", "03-cnc", "04-stl", "05-clouds", "06-dxf"]


def strings(code):
    p = f"textos/{code}.json"
    return json.load(open(p))


def build(code):
    st = strings(code)
    compose.use_language(code)
    out = f"play/{code}/phone"
    os.makedirs(out, exist_ok=True)
    for i, (sc, nm) in enumerate(zip(SCENES, NAMES)):
        s = st["slides"][i]
        compose.slide(f"{out}/{nm}.png", f"shots/{code}/{sc}.png", s["tag"], s["title"], s["sub"])
    fr = st["free"]
    compose.free_slide(f"{out}/07-free.png", fr["tagline"], [tuple(x) for x in fr["items"]], tuple(fr["foot"]))


if __name__ == "__main__":
    for c in sys.argv[1:]:
        build(c)
