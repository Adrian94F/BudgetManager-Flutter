import 'package:flutter/material.dart';

/// Colours Material 3 has no role for: the "saved" green of a closed month
/// with money left, in both brightnesses.
class BudgetColors extends ThemeExtension<BudgetColors> {
  const BudgetColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  static const light = BudgetColors(
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFC8E6C9),
    onSuccessContainer: Color(0xFF1B5E20),
  );

  static const dark = BudgetColors(
    success: Color(0xFF81C784),
    successContainer: Color(0xFF1B5E20),
    onSuccessContainer: Color(0xFFC8E6C9),
  );

  static BudgetColors of(BuildContext context) =>
      Theme.of(context).extension<BudgetColors>() ??
      (Theme.of(context).brightness == Brightness.light ? light : dark);

  @override
  BudgetColors copyWith({Color? success, Color? successContainer, Color? onSuccessContainer}) => BudgetColors(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      );

  @override
  BudgetColors lerp(ThemeExtension<BudgetColors>? other, double t) {
    if (other is! BudgetColors) return this;
    return BudgetColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
    );
  }
}

/// The app's Material 3 theme, seeded with the wallpaper colour when the user
/// enabled dynamic colour on Android 12+ and with indigo otherwise.
ThemeData buildTheme(Brightness brightness, {Color? seedColor}) {
  final colorScheme = ColorScheme.fromSeed(seedColor: seedColor ?? Colors.indigo, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    extensions: [brightness == Brightness.light ? BudgetColors.light : BudgetColors.dark],
    // The 2024 Material 3 look for progress indicators and sliders (rounded
    // track with a gap and a stop indicator). The flag is Flutter's official
    // opt-in and is marked deprecated only because it will become the default.
    // ignore: deprecated_member_use
    progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
    // ignore: deprecated_member_use
    sliderTheme: const SliderThemeData(year2023: false),
    // Predictive back on Android 14+: the page peeks out as the gesture
    // starts, with the manifest's enableOnBackInvokedCallback.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}
