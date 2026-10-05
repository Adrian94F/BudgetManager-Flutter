import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';

/// The wallpaper-derived primary colour on Android 12+, or null where the
/// system offers none. The theme builds its own Material 3 scheme from it,
/// so the rest of the app depends on Flutter's ColorScheme only.
Future<Color?> loadDynamicSeedColor() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return null;
    return Color(palette.primary.get(40));
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
