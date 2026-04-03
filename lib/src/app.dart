import 'package:flutter/material.dart';

import 'services/platform_api.dart';
import 'services/platform_api_factory.dart';
import 'ui/auth_gate_page.dart';
import 'ui/platform_shell.dart';

class DeltaCompanionApp extends StatelessWidget {
  const DeltaCompanionApp({super.key, this.api, this.skipAuthGate = false});

  final PlatformApi? api;
  final bool skipAuthGate;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0071E3);
    const backgroundColor = Color(0xFFF5F5F7);
    const surfaceColor = Colors.white;
    const surfaceTint = Color(0xFFFDFDFD);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          surface: surfaceColor,
        ).copyWith(
          primary: primaryColor,
          secondary: const Color(0xFF5E5CE6),
          tertiary: const Color(0xFF34C759),
          surface: surfaceColor,
          surfaceContainerHighest: surfaceTint,
        );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF111111),
        shape: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE9E9EE),
        thickness: 0.5,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE6E6EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryColor, width: 1.2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: Color(0xFFD8D8DE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0x1A0071E3),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        useIndicator: true,
        indicatorColor: const Color(0x1A0071E3),
        selectedIconTheme: const IconThemeData(color: primaryColor),
        selectedLabelTextStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF6B7280)),
        unselectedLabelTextStyle: const TextStyle(color: Color(0xFF6B7280)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF3F4F6),
        selectedColor: const Color(0x1A0071E3),
        labelStyle: const TextStyle(
          color: Color(0xFF111111),
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    final currentApi = api ?? buildPlatformApi();

    return MaterialApp(
      title: '三角洲行动陪玩拼单平台',
      theme: theme,
      home: skipAuthGate
          ? PlatformShell(api: currentApi)
          : AuthGatePage(api: currentApi),
      debugShowCheckedModeBanner: false,
    );
  }
}
