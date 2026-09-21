import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pages/home_page.dart';
import 'pages/recycle_bin_page.dart';
import 'theme/app_theme.dart';
import 'window/immersive_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await setupDesktopWindow();
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const MyApp());

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = Platform.isWindows
            ? const TextScaler.linear(1.0)
            : media.textScaler;
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
            child: child!,
          ),
        );
      },
      home: const HomePage(),
      routes: {
        '/recycle_bin': (context) {
          final home = HomePage.state;
          return RecycleBinPage(
            deletedRecords: home?.deletedRecords ?? const [],
            onRestore: (record) => home?.restoreFromRecycleBin(record),
            onClose: () => Navigator.pop(context),
          );
        },
      },
    );
  }
}
