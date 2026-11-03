# Dovexa

Visor CAD/CAM para Android (el código de iOS y macOS se mantiene para uso propio). Gratuito, sin anuncios, sin cuenta, offline.
Abre STEP, IGES, DXF, STL, 3MF, OBJ, glTF, PLY, G-code (FDM y CNC), SVG, HPGL, VRML/X3D y nubes de puntos; ensamblajes con árbol de piezas, medición, secciones y varios modos de vista.

- Licencia: GPL-3.0 (`LICENSE`, avisos de terceros en `NOTICE.md`). Autor: Plegasense.
- Google Play: paquete `app.datum.datum` (no se puede cambiar; «Datum» fue el nombre anterior).
- Interfaz en 21 idiomas.

## Carpetas
| Carpeta | Contenido |
|---|---|
| `app/` | App Flutter: `lib/` (código), `lib/l10n/` (idiomas), `assets/licenses/` (licencias que muestra la app), `test/` (pruebas), `tool/` (bancos de prueba y sondas por formato), `hook/` (compila Draco y LASzip). |
| `core/` | Núcleo C++ que envuelve Open CASCADE (lectura de STEP/IGES/BREP). |
| `third_party/` | Draco y LASzip (código incluido). Open CASCADE compilado queda en `third_party/_install/` (fuera de git). |
| `tools/` | Scripts: entorno (`env.sh`), compilar el AAB, compilar Open CASCADE, capturas, comprobación de idiomas. |
| `store/` | Ficha de Google Play: textos, capturas, gráficos y política de privacidad. Ver `store/ficha_play.md`. |
| `branding/` | Logo, icono y tipografías. `build_logo.py` regenera todo. |
| `testdata/` | Archivos de prueba pequeños y con licencia. Ver `testdata/README.md`. |

## Tareas habituales
```bash
source tools/env.sh                      # entorno (Flutter del proyecto, Java, Android SDK)
python3 tools/l10n_check.py              # idiomas: debe decir «0 problemas»
cd app && flutter test                   # pruebas
./tools/build_release_android.command    # AAB firmado en releases/android/
```

## Código fuente de terceros
- **Open CASCADE Technology 8.0.1** (LGPL-2.1 con la excepción de OCCT), sin modificar. Código fuente: https://github.com/Open-Cascade-SAS/OCCT/tree/V8_0_1. Se compila con `tools/build_occt_android.sh` (y `_ios`, `_macos`); Dovexa lo enlaza de forma estática y su código completo está en este repositorio, por lo que se puede volver a enlazar con otra versión de la librería.
- **Draco** y **LASzip** (Apache-2.0): código incluido en `third_party/`.
- Cada versión publicada en Google Play corresponde a una etiqueta de este repositorio (p. ej. `v1.0.10`).
