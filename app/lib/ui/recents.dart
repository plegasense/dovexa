import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../io/loader.dart' show extraFilesDir;

/// Archivos abiertos recientemente (se guardan en el propio dispositivo).
class RecentFile {
  RecentFile(this.path, this.name, this.openedAt);
  final String path;
  final String name;
  final DateTime openedAt;

  String get ext =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
}

class RecentsStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/recientes.json');
  }

  static Future<List<RecentFile>> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return [
        for (final e in list)
          if (File(e['path'] as String).existsSync())
            RecentFile(
              e['path'] as String,
              e['name'] as String,
              DateTime.parse(e['at'] as String),
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Los archivos del selector o de «Abrir con» viven en la caché y Android la vacía:
  /// para que Recientes siga funcionando se guarda una copia propia (hasta 50 MB).
  static Future<String> _keep(String path, String name, int size) async {
    final cache = (await getTemporaryDirectory()).path;
    if (!path.startsWith(cache) || size > 50 * 1024 * 1024) return path;
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/recientes/$size');
    dir.createSync(recursive: true);
    final dst = '${dir.path}/$name';
    File(path).copySync(dst);
    // Los archivos que el usuario añadió al modelo (texturas, .bin) siguen al archivo a su copia propia.
    try {
      final from = Directory(extraFilesDir(path));
      if (from.existsSync()) {
        final to = Directory(extraFilesDir(dst))..createSync(recursive: true);
        for (final f in from.listSync().whereType<File>()) {
          f.copySync('${to.path}/${f.path.split('/').last}');
        }
      }
    } catch (_) {}
    return dst;
  }

  static Future<void> add(String path) async {
    try {
      final all = await load();
      final name = path.split('/').last;
      final size = File(path).lengthSync();
      final kept = await _keep(path, name, size);
      // El selector copia cada archivo a una ruta nueva: se compara por nombre y tamaño.
      final gone = all.where(
        (r) => r.path == kept || (r.name == name && File(r.path).lengthSync() == size),
      ).toList();
      all.removeWhere(gone.contains);
      all.insert(0, RecentFile(kept, name, DateTime.now()));
      final shown = all.take(12).toList();
      // Se borran las copias propias que ya no figuran en la lista.
      final base = '${(await getApplicationSupportDirectory()).path}/recientes/';
      for (final r in [...gone, ...all.skip(12)]) {
        if (r.path.startsWith(base) && !shown.any((s) => s.path == r.path)) {
          try {
            File(r.path).deleteSync();
          } catch (_) {}
        }
      }
      final f = await _file();
      await f.writeAsString(
        jsonEncode([
          for (final r in shown)
            {
              'path': r.path,
              'name': r.name,
              'at': r.openedAt.toIso8601String(),
            },
        ]),
      );
    } catch (_) {
      // Sin historial no pasa nada.
    }
  }
}
