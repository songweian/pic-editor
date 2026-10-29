import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.ensureSemantics();
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
  runApp(const PicEditorApp());
}
