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
  BudgetColors copyWith(
          {Color? success,
          Color? successContainer,
          Color? onSuccessContainer}) =>
      BudgetColors(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      );

  @override
  BudgetColors lerp(ThemeExtension<BudgetColors>? other, double t) {
    if (other is! BudgetColors) return this;
    return BudgetColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
    );
  }
}

/// The burndown's status colours, fixed hex values shared with the iOS app
/// and the web so the same month reads the same everywhere, whatever the
/// accent or dynamic colour: red when the balance is below zero, amber when
/// the current month is under its savings target, green when a closed (or
/// future) month kept money. The current month on track uses the app's own
/// primary colour, which is not part of this palette. The plan and target
/// lines are a neutral [reference] gray in both brightnesses.
class BurndownPalette {
  const BurndownPalette._({
    required this.overBudget,
    required this.belowTarget,
    required this.saved,
  });

  /// Latest balance below zero, in any month.
  final Color overBudget;

  /// The current month's balance under the planned savings target.
  final Color belowTarget;

  /// A closed or future month that did not go below zero.
  final Color saved;

  /// The dashed plan (ideal) line and the savings target line.
  static const reference = Color(0xFF9CA3AF);

  static const light = BurndownPalette._(
    overBudget: Color(0xFFE11D48),
    belowTarget: Color(0xFFD97706),
    saved: Color(0xFF059669),
  );

  static const dark = BurndownPalette._(
    overBudget: Color(0xFFFB7185),
    belowTarget: Color(0xFFFBBF24),
    saved: Color(0xFF34D399),
  );

  static BurndownPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? light : dark;
}

/// Button shape that tightens while pressed, as Material 3 Expressive
/// buttons do; `Material` animates the change.
WidgetStateProperty<OutlinedBorder?> _pressableShape(double radius) =>
    WidgetStateProperty.resolveWith((states) => RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(
              states.contains(WidgetState.pressed) ? radius * 0.6 : radius),
        ));

const _cardShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)));
const _sheetShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)));
const _dialogShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(28)));

/// The app's Material 3 theme, seeded with the wallpaper colour when the user
/// enabled dynamic colour on Android 12+ and with indigo otherwise. Surfaces
/// use superellipse ("squircle") corners.
ThemeData buildTheme(Brightness brightness, {Color? seedColor}) {
  final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? Colors.indigo, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    extensions: [
      brightness == Brightness.light ? BudgetColors.light : BudgetColors.dark
    ],
    cardTheme: const CardThemeData(shape: _cardShape),
    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(shape: _cardShape),
    bottomSheetTheme: const BottomSheetThemeData(shape: _sheetShape),
    dialogTheme: const DialogThemeData(shape: _dialogShape),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    filledButtonTheme:
        FilledButtonThemeData(style: ButtonStyle(shape: _pressableShape(20))),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: ButtonStyle(shape: _pressableShape(20))),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: ButtonStyle(shape: _pressableShape(20))),
    textButtonTheme:
        TextButtonThemeData(style: ButtonStyle(shape: _pressableShape(20))),
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
