import 'package:flutter/material.dart';

/// Sleep Up renk paleti — tasarım ekranlarıyla birebir.
class SU {
  static const bg = Color(0xFF0D0F1C);
  static const bgDeep = Color(0xFF07080F);
  static const surface = Color(0xFF171A2E);
  static const surfaceHi = Color(0xFF22263F);
  static const line = Color(0xFF2E3352);
  static const text = Color(0xFFEEF0FA);
  static const muted = Color(0xFFA2A7C4);
  static const amber = Color(0xFFF4B860);
  static const onAmber = Color(0xFF1A1406);
  static const lavender = Color(0xFF9C9BFF);
  static const mint = Color(0xFF8EE3C8);
  static const dim = Color(0xFF4A4F78);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: SU.amber,
      onPrimary: SU.onAmber,
      secondary: SU.lavender,
      surface: SU.surface,
      onSurface: SU.text,
    ),
    scaffoldBackgroundColor: SU.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: SU.text, displayColor: SU.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: SU.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: SU.text),
    ),
    cardTheme: CardThemeData(
      color: SU.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SU.amber,
        foregroundColor: SU.onAmber,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SU.text,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: SU.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? SU.onAmber : SU.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? SU.amber : SU.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SU.bg,
      indicatorColor: SU.surfaceHi,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, color: SU.muted)),
    ),
    dividerColor: SU.surfaceHi,
  );
}
