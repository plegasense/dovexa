import 'dart:convert' show latin1;
import 'dart:io';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

import '../l10n/l10n.dart';
import 'iso_run.dart';
import '../model/brep.dart';
import '../model/document.dart';
import '../model/lines.dart';
import '../model/mesh.dart';
import '../model/pointcloud.dart';
import '../model/scene.dart';
import 'bgcode_loader.dart';
import 'cad_loader.dart';
import 'gltf_loader.dart';
import 'mesh_data_extra.dart';
import 'ply_loader.dart';
import 'e57_loader.dart';
import 'las_loader.dart';
import 'laz_glue.dart';
import 'pointcloud_loader.dart';
import 'hpgl_parser.dart';
import 'svg_loader.dart';
import 'vrml_loader.dart';
import 'dxf_loader.dart';
import 'gcode_loader.dart';
import 'mesh_data.dart';
import 'obj_loader.dart';
import 'stl_loader.dart';
import '../model/mesh_info.dart';
import '../model/threemf.dart';
import 'texture_prep.dart';
import 'zip_lite.dart';
import 'threemf_loader.dart';

/// Formatos que Dovexa sabe abrir hoy.
const kSupportedExtensions = {
  'zip',
  'stl',
  'obj',
  '3mf',
  'ply',
  'gltf',
  'glb',
  'wrl',
  'wrz',
  'x3d',
  'x3dv',
  'step',
  'stp',
  'stpz',
  'iges',
  'igs',
  'brep',
  'dxf',
  'svg',
  'plt',
  'hpgl',
  'hgl',
  'hpg',
  'xyz',
  'pts',
  'pcd',
  'las',
  'laz',
  'e57',
  'gcode',
  'gco',
  'gc',
  'nc',
  'ngc',
  'tap',
  'cnc',
  'bgcode',
};

const kHpglExtensions = {'plt', 'hpgl', 'hgl', 'hpg', 'hp'};

const kGcodeExtensions = {'gcode', 'gco', 'gc', 'nc', 'ngc', 'tap', 'cnc'};

/// Formatos propietarios que se reconocen pero no se pueden abrir: se explica cómo exportarlos.
const kProprietary = {
  'sldprt': 'SolidWorks',
  'sldasm': 'SolidWorks',
  'slddrw': 'SolidWorks',
  'ipt': 'Autodesk Inventor',
  'iam': 'Autodesk Inventor',
  'idw': 'Autodesk Inventor',
  'prt': 'Siemens NX / PTC Creo',
  'catpart': 'CATIA',
  'catproduct': 'CATIA',
  'par': 'Solid Edge',
  'f3d': 'Autodesk Fusion',
  'dwg': 'AutoCAD',
};

class UnsupportedFormat implements Exception {
  UnsupportedFormat(this.extension, this.software);
  final String extension;
  final String? software;
  @override
  String toString() => extension.isEmpty
      ? tr('No se reconoce el formato de este archivo.')
      : extension == 'dwg'
      ? '${tr('Los archivos .dwg son formato nativo de AutoCAD y todavía no se pueden abrir.')} '
            '${tr('Guárdalo como DXF (Guardar como → DXF) y ábrelo aquí.')}'
      : software == null
      ? tr('Formato .{e} no soportado todavía.', {'e': extension})
      : '${tr('Los archivos .{e} son formato nativo de {s} y no se pueden abrir directamente.', {'e': extension, 's': software})} '
            '${tr('Expórtalo a STEP (.step) desde {s} y ábrelo aquí.', {'s': software})}';
}

/// Carpeta (en la caché de la app) donde el usuario deja las texturas y materiales que
/// faltan junto a un modelo; los lectores la miran además de la carpeta del archivo.
String extraFilesDir(String modelPath) {
  var h = 5381;
  for (final c in modelPath.codeUnits) {
    h = ((h << 5) + h + c) & 0x7FFFFFFF;
  }
  return '${extraBase ?? Directory.systemTemp.path}/dovexa_extra/$h';
}

/// Carpeta base de los archivos añadidos (la fija `main`).
String? extraBase;

List<String> _extra(String modelPath) {
  final d = extraFilesDir(modelPath);
  return Directory(d).existsSync() ? [d] : const [];
}

Future<Scene> loadScene(String path) async {
  final name = path.split('/').last;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  final SceneData data;
  switch (ext) {
    case 'stl':
      final mesh = await loadStl(path);
      final part = Part(id: 0, name: name, mesh: mesh);
      final root = SceneNode(name: name, part: part);
      return Scene(name: name, root: root, parts: [part]);
    case 'obj':
      final extra = _extra(path);
      final r = await isoRun(() => parseObj(path, extraDirs: extra));
      if (r is! SceneData) throw const FormatException('nube');
      data = r;
    case '3mf':
      data = await isoRun(() => parse3mf(path));
    case 'step' || 'stp' || 'iges' || 'igs' || 'brep':
      final cacheDir = cadCacheDir;
      data = await isoRun(() => parseCad(path, cacheDir: cacheDir));
    default:
      throw UnsupportedFormat(ext, kProprietary[ext]);
  }
  return _sceneFrom(data);
}

CadBrep? _cad(CadData? c) =>
    c == null ? null : CadBrep(c.handle, c.unit, c.origin, c.schema, c.pmi);

Scene _sceneFrom(SceneData d) {
  if (d.placed.isEmpty && d.nodes.isEmpty)
    throw Exception(tr('El archivo no contiene geometría'));
  final parts = <Part>[
    for (var i = 0; i < d.meshes.length; i++)
      Part(
        id: i,
        name: d.meshes[i].name,
        mesh: d.meshes[i].toMesh(),
        color: d.meshes[i].color,
        brep: d.cad?.parts[i].toBrep(),
        material: d.meshes[i].material == null
            ? null
            : d.materials[d.meshes[i].material!],
      ),
  ];
  final root = SceneNode(name: d.name);
  if (d.nodes.isNotEmpty) {
    // Jerarquía de ensamblaje (STEP/IGES): el padre siempre aparece antes que sus hijos.
    final built = <SceneNode>[];
    for (final n in d.nodes) {
      final node = SceneNode(
        name: n.name,
        part: n.part >= 0 ? parts[n.part] : null,
        transform: vm.Matrix4.fromList(n.matrix),
        tag: n.tag,
      );
      built.add(node);
      (n.parent >= 0 ? built[n.parent] : root).children.add(node);
    }
    final scene = Scene(
      name: d.name,
      root: root,
      parts: parts,
      cad: _cad(d.cad),
      textures: d.textures,
    );
    if (d.extra is ThreeMfProject) threeMfOf[scene] = d.extra as ThreeMfProject;
    if (d.extra is MeshFileInfo) meshInfoOf[scene] = d.extra as MeshFileInfo;
    return scene;
  }
  for (final p in d.placed) {
    root.children.add(
      SceneNode(
        name: p.name,
        part: parts[p.meshIndex],
        transform: vm.Matrix4.fromList(p.matrix),
      ),
    );
  }
  final scene = Scene(name: d.name, root: root, parts: parts, textures: d.textures);
  if (d.extra is MeshFileInfo) meshInfoOf[scene] = d.extra as MeshFileInfo;
  return scene;
}

/// Formato real de un archivo por su contenido (para cuando la extensión falta o miente).
/// Devuelve la extensión canónica y las que se consideran equivalentes, o null si no está claro.
(String, Set<String>)? _sniff(String path) {
  final Uint8List b;
  try {
    final f = File(path).openSync();
    try {
      b = f.readSync(4096);
    } finally {
      f.closeSync();
    }
  } catch (_) {
    return null;
  }
  if (b.length < 8) return null;
  final head = latin1.decode(b).replaceAll('\r', '');
  final low = head.toLowerCase();
  if (head.startsWith('glTF')) return ('glb', {'glb', 'gltf'});
  if (head.startsWith('LASF')) return ('las', {'las', 'laz'});
  if (head.startsWith('GCDE')) return ('bgcode', {'bgcode'});
  if (head.contains('ASTM-E57')) return ('e57', {'e57'});
  if (low.trimLeft().startsWith('ply\n')) return ('ply', {'ply'});
  if (head.contains('ISO-10303-21')) return ('step', {'step', 'stp', 'stpz'});
  if (head.startsWith('#VRML') || head.startsWith('#X3D')) return ('wrl', {'wrl', 'x3d', 'x3dv', 'wrz'});
  if (low.contains('<svg')) return ('svg', {'svg'});
  if (RegExp(r'^\s*0\s*\n\s*SECTION\s*\n').hasMatch(head)) return ('dxf', {'dxf'});
  if (low.trimLeft().startsWith('solid') && low.contains('facet')) return ('stl', {'stl'});
  // STL binario: 80 bytes de cabecera, un contador y 50 bytes por triángulo.
  try {
    final len = File(path).lengthSync();
    if (len > 84 && (len - 84) % 50 == 0) {
      final n = ByteData.sublistView(b, 80, 84).getUint32(0, Endian.little);
      if (n > 0 && n == (len - 84) ~/ 50) return ('stl', {'stl'});
    }
  } catch (_) {}
  return null;
}

/// Enlace con el nombre del archivo y la extensión corregida, para que los lectores lo reconozcan.
String _alias(String path, String ext) {
  var h = 5381;
  for (final c in path.codeUnits) {
    h = ((h << 5) + h + c) & 0x7FFFFFFF;
  }
  final base = path.split('/').last;
  final stem = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
  final dir = Directory('${extraBase ?? Directory.systemTemp.path}/dovexa_alias/$h')
    ..createSync(recursive: true);
  final link = Link('${dir.path}/$stem.$ext');
  if (link.existsSync()) link.deleteSync();
  link.createSync(path);
  return link.path;
}

/// Abre cualquier archivo soportado y devuelve el documento adecuado.
Future<Document> loadDocument(String path, {int? gcodePlate}) async {
  final name0 = path.split('/').last;
  final ext0 = name0.contains('.') ? name0.split('.').last.toLowerCase() : '';
  if (ext0 != 'zip' && !name0.toLowerCase().endsWith('.gcode.3mf')) {
    final s = _sniff(path);
    if (s != null && !s.$2.contains(ext0)) {
      return loadDocument(_alias(path, s.$1), gcodePlate: gcodePlate);
    }
  }
  final name = path.split('/').last;
  final lower = name.toLowerCase();
  final ext = name.contains('.') ? lower.split('.').last : '';

  // ---- Archivos comprimidos con un modelo y sus texturas (Sketchfab, fotogrametría…)
  if (ext == 'zip') {
    final main = await isoRun(() => extractModelZip(path, extraBase ?? Directory.systemTemp.path));
    return loadDocument(main, gcodePlate: gcodePlate);
  }

  // ---- Dibujos 2D
  if (ext == 'dxf' || ext == 'svg' || kHpglExtensions.contains(ext)) {
    final data = ext == 'dxf'
        ? await loadDxf(path)
        : (ext == 'svg' ? await loadSvg(path) : await loadHpgl(path));
    final (lines, texts) = data.build();
    return DrawingDocument(
      data.name,
      lines,
      texts,
      data.insUnits,
      data.truncated,
    )..info = data.info;
  }

  // ---- Trayectorias
  if (gcodePlate != null) {
    return ToolpathDocument(
      (await loadGcode3mf(path, plate: gcodePlate)).build(),
    );
  }
  if (lower.endsWith('.gcode.3mf'))
    return ToolpathDocument((await loadGcode3mf(path)).build());
  if (ext == 'bgcode')
    return ToolpathDocument((await loadBgcode(path)).build());
  if (kGcodeExtensions.contains(ext))
    return ToolpathDocument((await loadGcode(path)).build());

  // ---- Nubes de puntos
  if (ext == 'xyz' || ext == 'pts')
    return _cloud(await isoRun(() => parseXyz(path)));
  if (ext == 'pcd') return _cloud(await isoRun(() => parsePcd(path)));
  if (ext == 'las' || ext == 'laz') {
    final comp = () {
      final f = File(path).openSync();
      try {
        return readLasHeader(f).compressed;
      } catch (_) {
        return ext == 'laz';
      } finally {
        f.closeSync();
      }
    }();
    if (comp) return _cloud(await isoRun(() => parseLaz(path)));
    final sw = Stopwatch()..start();
    final d = await isoRun(() => parseLas(path));
    final t1 = sw.elapsedMilliseconds;
    final doc = _cloud(d);
    // ignore: avoid_print
    if (const String.fromEnvironment('DOVEXA_CAD').isNotEmpty) print('CLOUD lectura $t1 ms · modelo ${sw.elapsedMilliseconds - t1} ms');
    return doc;
  }
  if (ext == 'e57') return _cloud(await isoRun(() => parseE57(path)));
  if (ext == 'ply') {
    final r = await isoRun(() => parsePly(path));
    return r is PointData ? _cloud(r) : await _model(_sceneFrom(r as SceneData));
  }

  // ---- Modelos 3D
  if (ext == 'obj') {
    final extra = _extra(path);
    final r = await isoRun(() => parseObj(path, extraDirs: extra));
    return r is PointData ? _cloud(r) : await _model(_sceneFrom(r as SceneData));
  }
  if (ext == 'gltf' || ext == 'glb')
    {
      final extra = _extra(path);
      return _model(
        _sceneFrom(await isoRun(() => parseGltf(path, extraDirs: extra))),
      );
    }
  if (ext == 'wrl' || ext == 'wrz' || ext == 'x3d' || ext == 'x3dv') {
    final extra = _extra(path);
    return _model(_sceneFrom(await isoRun(() => parseVrml(path, extraDirs: extra))));
  }
  if (ext == 'stpz' ||
      lower.endsWith('.stp.gz') ||
      lower.endsWith('.step.gz')) {
    // El temporal conserva el nombre del archivo para que el título del documento sea el suyo.
    final stem = name.replaceFirst(RegExp(r'\.(stpz|stp\.gz|step\.gz)$', caseSensitive: false), '');
    final tmpDir = '${Directory.systemTemp.path}/dovexa_stpz/${DateTime.now().microsecondsSinceEpoch}';
    final data = await isoRun(() {
      Directory(tmpDir).createSync(recursive: true);
      final tmp = File('$tmpDir/$stem.step');
      List<int> raw;
      try {
        raw = gzip.decode(File(path).readAsBytesSync());
      } on FormatException {
        throw FormatException(tr('El archivo está dañado o no es del formato que indica su extensión.'));
      }
      tmp.writeAsBytesSync(raw);
      try {
        return parseCad(tmp.path);
      } finally {
        Directory(tmpDir).deleteSync(recursive: true);
      }
    });
    return ModelDocument(_sceneFrom(data));
  }
  return _model(await loadScene(path));
}

/// Documento de modelo con sus texturas ya decodificadas.
Future<ModelDocument> _model(Scene s) async {
  if (s.textures.isNotEmpty) await prepareTextures(s.textures);
  return ModelDocument(s);
}

PointCloudDocument _cloud(PointData d) {
  final set = LineSet(vertices: d.verts, bounds: Bounds(d.min, d.max));
  final i = d.intensity, c = d.cls, r = d.ret, n = d.nret;
  return PointCloudDocument(
    PointCloud(
      name: d.name,
      points: set,
      hasColor: d.hasColor,
      attrs: (i != null || c != null || r != null) ? CloudAttrs(intensity: i, cls: c, ret: r, nret: n) : null,
      info: d.info,
      origin: d.origin,
    ),
  );
}

/// Extrae un ZIP con un modelo y sus archivos en una carpeta de la caché y devuelve la ruta
/// del modelo principal (glTF, GLB, OBJ, PLY, STL o 3MF).
String extractModelZip(String zipPath, String base) {
  final zip = ZipLite.open(zipPath);
  try {
    var h = 5381;
    for (final c in zipPath.codeUnits) {
      h = ((h << 5) + h + c) & 0x7FFFFFFF;
    }
    final dir = Directory('$base/dovexa_zip/$h')..createSync(recursive: true);
    String? main;
    var total = 0;
    const rank = {'glb': 0, 'gltf': 1, 'obj': 2, 'ply': 3, '3mf': 4, 'stl': 5, 'step': 6, 'stp': 6};
    var best = 99;
    for (final e in zip.entries.values) {
      final name = e.name.replaceAll('\\', '/');
      if (name.startsWith('/') || name.split('/').contains('..') || name.contains('__MACOSX')) continue;
      total += e.usize;
      if (total > 1500 * 1024 * 1024) {
        throw FormatException(tr('El ZIP descomprimido es demasiado grande (más de 1,5 GB)'));
      }
      final out = File('${dir.path}/$name')..parent.createSync(recursive: true);
      final sink = out.openSync(mode: FileMode.write);
      try {
        zip.stream(e.name, sink.writeFromSync);
      } finally {
        sink.closeSync();
      }
      final x = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final r = rank[x];
      if (r != null && r < best) {
        best = r;
        main = out.path;
      }
    }
    if (main == null) throw FormatException(tr('El ZIP no contiene ningún modelo que Dovexa sepa abrir'));
    return main;
  } finally {
    zip.close();
  }
}
