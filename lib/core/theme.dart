import 'package:flutter/material.dart';

/// NightTalker's visual identity: a dark, moonlit instrument you trust while
/// unconscious — it keeps watch so the room can stay quiet. One cool accent
/// (moonlight) for presence and activity; one warm accent (signal) reserved
/// solely for the moment sound actually crosses the detection threshold, so
/// it reads as the one thing that "happened" in an otherwise still room.
abstract final class AppColors {
  static const ink = Color(0xFF0B1220); // base background
  static const surface = Color(0xFF121B2E); // cards, panels
  static const surfaceRaised = Color(0xFF1B2740); // dialogs, active rows
  static const hairline = Color(0xFF26324A); // dividers, borders, quiet
  static const moonlight = Color(0xFF8FCBFF); // primary accent — presence
  static const text = Color(0xFFE7EEF7); // primary text
  static const textMuted = Color(0xFF8CA0BE); // secondary text, labels
  static const signal = Color(0xFFFF8A65); // sound-detected accent — only
}

const _displayFont = 'Space Grotesk';
const _bodyFont = 'IBM Plex Sans';

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.moonlight, brightness: Brightness.dark).copyWith(
    surface: AppColors.surface,
    primary: AppColors.moonlight,
    onPrimary: AppColors.ink,
    secondary: AppColors.signal,
    onSurface: AppColors.text,
    error: AppColors.signal,
    onError: AppColors.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.ink,
    fontFamily: _bodyFont,
  );

  // Body face (IBM Plex Sans, via ThemeData.fontFamily above) everywhere by
  // default; the display face (Space Grotesk) is used with restraint — only
  // screen titles and the big status word ("Idle" / "Listening…" /
  // "Recording…") get it, so it stays a deliberate accent, not the whole
  // page's voice.
  final textTheme = base.textTheme
      .apply(displayColor: AppColors.text, bodyColor: AppColors.text)
      .copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: _displayFont,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: AppColors.text,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: _displayFont,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: AppColors.text),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: const IconThemeData(color: AppColors.text),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.moonlight,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: AppColors.hairline,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(200, 56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: _displayFont, fontWeight: FontWeight.w600, fontSize: 16),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.moonlight,
        side: const BorderSide(color: AppColors.hairline),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.moonlight)),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.moonlight)),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.moonlight,
      inactiveTrackColor: AppColors.hairline,
      thumbColor: AppColors.moonlight,
      overlayColor: AppColors.moonlight.withValues(alpha: 0.15),
      valueIndicatorColor: AppColors.surfaceRaised,
      valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(color: AppColors.text),
      trackHeight: 3,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.moonlight, textColor: AppColors.text),
    iconTheme: const IconThemeData(color: AppColors.moonlight),
    dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.moonlight),
  );
}
