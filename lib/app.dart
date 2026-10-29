import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/editor/editor_page.dart';
import 'state/editor_controller.dart';

class PicEditorApp extends StatelessWidget {
  const PicEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorController(),
      child: MaterialApp(
        title: '纸张排版',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const EditorPage(),
      ),
    );
  }
}

ThemeData _buildTheme() {
  const seed = Color(0xFFD4B48A);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF1C1E22),
    background: const Color(0xFF121417),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF121417),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1C1E22),
      foregroundColor: Color(0xFFE8EAED),
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: Colors.white12,
    sliderTheme: const SliderThemeData(trackHeight: 3),
  );
}
