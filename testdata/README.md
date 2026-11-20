# Archivos de prueba

- `step/`: ejemplos de Open CASCADE (pequeños, con su licencia).
- **Corpus local, no se sube a git:** una carpeta local (1,4 GB) contiene archivos reales del autor
  (SolidWorks, Inventor, NX, Fusion, AutoCAD). Se usa solo desde disco, nunca se copia al repositorio.

Pruebas de carga masiva (desde `app/`):

```bash
source ../tools/env.sh
dart run tool/bench_load.dart "<carpeta-corpus>" step,stp 200   # STEP
dart run tool/bench_load.dart "<carpeta-corpus>" 3mf 100        # 3MF
dart run tool/bench_load.dart "<carpeta-corpus>" stl,obj 120    # STL y OBJ
```

Capturas automáticas en el simulador de iPhone: `tools/shot_ios.sh <archivo> <salida.png>`.

## Modelos de muestra de las capturas (no están en el repositorio)

| Archivo | Origen | Licencia |
|---|---|---|
| `3dbenchy_3DBenchy.stl` y los G-code `*_3dbenchy.gcode` (laminados con PrusaSlicer/OrcaSlicer a partir de ese modelo) | 3DBenchy, CreativeTools (3dbenchy.com) | CC0 |
| Cesium Milk Truck (glTF) | Cesium, [glTF-Sample-Models](https://github.com/KhronosGroup/glTF-Sample-Models) | CC BY 4.0 |
| `autzen-classified.laz` (nube de puntos) | Hobu/PDAL, [PDAL/data](https://github.com/PDAL/data) (CC BY 4.0 declarado por Hobu en la lista PDAL, ago. 2021) | CC BY 4.0 |

Los créditos de estos tres figuran en la ficha de Play. Los modelos propios (`reductor.step`, `testdata/gcode/fresado_ejemplo.nc`) se usan en las capturas de STEP y CNC.
