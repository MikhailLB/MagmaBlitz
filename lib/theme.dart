import 'package:flutter/material.dart';

class MagmaColors {
  static const Color deepRock = Color(0xFF1A0E0A);
  static const Color rock = Color(0xFF2B1A12);
  static const Color rockLight = Color(0xFF3D2418);
  static const Color lava = Color(0xFFFF5A1F);
  static const Color lavaBright = Color(0xFFFF8A2B);
  static const Color ember = Color(0xFFFFC042);
  static const Color ash = Color(0xFFE8D9CF);

  static const LinearGradient panel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3D2418), Color(0xFF1A0E0A)],
  );

  static const LinearGradient lavaButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A2B), Color(0xFFFF5A1F)],
  );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: MagmaColors.deepRock,
    colorScheme: base.colorScheme.copyWith(
      primary: MagmaColors.lava,
      secondary: MagmaColors.ember,
      surface: MagmaColors.rock,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: MagmaColors.ash,
      displayColor: MagmaColors.ash,
    ),
  );
}
