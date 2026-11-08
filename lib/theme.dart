import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SafeCircle design tokens
// ---------------------------------------------------------------------------

const Color navy = Color(0xFF172C48);
const Color navyDark = Color(0xFF0E1D33);
const Color navyLight = Color(0xFF284C7A);
const Color coral = Color(0xFFE45459);
const Color coralDark = Color(0xFFC93E44);
const Color background = Color(0xFFF4F6FA);
const Color borderColor = Color(0xFFE3E7EE);
const Color ink = Color(0xFF1B2A41);
const Color muted = Color(0xFF64748B);
const Color success = Color(0xFF1F9D6B);
const Color successSoft = Color(0xFFE5F6EE);
const Color coralSoft = Color(0xFFFDECEC);
const Color blueSoft = Color(0xFFE6EEFB);
const Color amberSoft = Color(0xFFFFF4DB);
const Color amber = Color(0xFFB7791F);

/// Width (in logical pixels) at which the layout switches from the
/// mobile bottom-navigation layout to the desktop sidebar layout.
const double desktopBreakpoint = 860;

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: navy,
        brightness: Brightness.light,
      ).copyWith(
        primary: navy,
        onPrimary: Colors.white,
        secondary: coral,
        onSecondary: Colors.white,
        error: coralDark,
        surface: Colors.white,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.standard,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFB8C0CC),
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: navy,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: navy,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: blueSoft,
      height: 66,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderColor, space: 1),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: borderColor),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// Consistent, professional text-field look used by every form in the app.
InputDecoration fieldDecoration({
  required String label,
  IconData? icon,
  String? hint,
  String? helper,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(borderColor),
    enabledBorder: border(borderColor),
    focusedBorder: border(navy, 1.6),
    errorBorder: border(coralDark),
    focusedErrorBorder: border(coralDark, 1.6),
  );
}
