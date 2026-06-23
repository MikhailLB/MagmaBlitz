import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';
import 'services/progress_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The loading screen may be shown in either orientation.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await ProgressService.instance.init();
  runApp(const MagmaBlitzApp());
}

class MagmaBlitzApp extends StatelessWidget {
  const MagmaBlitzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magma Blitz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LoadingScreen(),
    );
  }
}

/// Locks the app to vertical orientation for actual gameplay.
Future<void> lockPortrait() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
