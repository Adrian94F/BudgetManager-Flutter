import 'package:flutter/material.dart';

/// The app's Material 3 theme. [scheme] is a dynamic colour scheme when the
/// user enabled it on Android 12+; otherwise the indigo seed is used.
ThemeData buildTheme(Brightness brightness, {ColorScheme? scheme}) {
  final colorScheme = scheme ?? ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
  );
}
