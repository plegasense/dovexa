import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:path_provider/path_provider.dart';

import 'io/cad_loader.dart' show cadCacheDir;
import 'io/loader.dart' show extraBase;
import 'l10n/l10n.dart';
import 'model/unit_system.dart';
import 'render/edl.dart';
import 'ui/theme.dart';
import 'ui/licenses.dart';
import 'ui/viewer_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loc = PlatformDispatcher.instance.locale;
  L.setFromLanguageCode(
    loc.languageCode,
    scriptCode: loc.scriptCode,
    countryCode: loc.countryCode,
  );
  L.countryCode = PlatformDispatcher.instance.locale.countryCode;
  try {
    await Units.load().timeout(const Duration(seconds: 2));
  } catch (_) {}
  try {
    cadCacheDir = '${(await getApplicationCacheDirectory()).path}/dovexa_cad';
    extraBase = (await getApplicationSupportDirectory()).path; // no en la caché: Android la vacía
  } catch (_) {}
  EdlFx.load();
  registerNativeLicenses();
  runApp(const DovexaApp());
}

class DovexaApp extends StatefulWidget {
  const DovexaApp({super.key});

  @override
  State<DovexaApp> createState() => _DovexaAppState();
}

class _DovexaAppState extends State<DovexaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    L.choice.addListener(_rebuildAll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    L.choice.removeListener(_rebuildAll);
    super.dispose();
  }

  /// En «Automático», un cambio de idioma o región del sistema con la app abierta se aplica al momento.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (L.choice.value != 'auto') return;
    L.apply('auto');
    L.countryCode = PlatformDispatcher.instance.locale.countryCode;
    _rebuildAll();
  }

  /// Los textos se traducen al construir, así que al cambiar de idioma se reconstruye todo el árbol.
  void _rebuildAll() {
    if (mounted) setState(() {}); // MaterialApp: textos propios de Material en el idioma nuevo
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dovexa',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: DT.theme(),
      // Textos de Material (accesibilidad, diálogos) en el idioma de la app.
      locale: L.lang == 'tw'
          ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
          : Locale(L.lang),
      supportedLocales: [
        const Locale('en'),
        const Locale('es'),
        for (final c in L.supported) if (c != 'zh') Locale(c),
        const Locale('zh'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const ViewerPage(),
    );
  }
}
