import 'package:flutter/material.dart';

/// Tally 统一配色（深灰蓝 Dracula 风）
class AppColors {
  AppColors._();

  // 背景
  static const Color bgPrimary = Color(0xFF1E1E2E); // 主背景
  static const Color bgSecondary = Color(0xFF282A36); // 次背景 / 卡片
  static const Color bgSelection = Color(0xFF3B3F51); // 选区 / 描边
  static const Color bgLineNumber = Color(0xFF252734); // 更暗底
  static const Color bgHighlight = Color(0xFF44475A); // 高亮背景
  static const Color bgCurrentLine = Color(0xFF2C2F42); // 当前行/选中项

  // 前景
  static const Color textPrimary = Color(0xFFE0E0E0); // 主文字
  static const Color textSecondary = Color(0xFF6C7086); // 次文字
  static const Color textMuted = Color(0xFF6272A4); // 注释/弱化
  static const Color textVariable = Color(0xFFF8F8F2); // 高亮正文

  // 语义 / 语法映射
  static const Color blue = Color(0xFF2B7DE9); // 主色：关键字/焦点
  static const Color orange = Color(0xFFFF7A3D); // 警告 / 字符串
  static const Color purple = Color(0xFFBD93F9); // 数字/常量
  static const Color green = Color(0xFF50FA7B); // 成功 / 类型
  static const Color red = Color(0xFFFF5555); // 错误
  static const Color pink = Color(0xFFFF79C6); // 操作符/强调

  static const Color focusBorder = blue;
  static const Color success = green;
  static const Color warning = orange;
  static const Color error = red;
  static const Color outlineLight = Color(0xFF7A7F92);

  static ColorScheme get darkScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: blue,
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: bgHighlight,
        onPrimaryContainer: textPrimary,
        secondary: pink,
        onSecondary: Color(0xFF1E1E2E),
        secondaryContainer: bgSelection,
        onSecondaryContainer: textPrimary,
        tertiary: purple,
        onTertiary: Color(0xFF1E1E2E),
        tertiaryContainer: bgHighlight,
        onTertiaryContainer: textPrimary,
        error: error,
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFF5A2A2A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: bgPrimary,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        surfaceContainerLowest: bgLineNumber,
        surfaceContainerLow: bgPrimary,
        surfaceContainer: bgSecondary,
        surfaceContainerHigh: bgCurrentLine,
        surfaceContainerHighest: bgSelection,
        outline: textSecondary,
        outlineVariant: bgSelection,
        shadow: Color(0xFF000000),
        scrim: Color(0x99000000),
        inverseSurface: textPrimary,
        onInverseSurface: bgPrimary,
        inversePrimary: blue,
        surfaceTint: blue,
      );

  /// 浅色：保留品牌蓝与语义色，背景改为同系浅灰
  static ColorScheme get lightScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: blue,
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFD6E4FF),
        onPrimaryContainer: Color(0xFF0B1C33),
        secondary: pink,
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFD6EC),
        onSecondaryContainer: Color(0xFF3A1028),
        tertiary: purple,
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFE8D8FF),
        onTertiaryContainer: Color(0xFF2A1840),
        error: error,
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: Color(0xFFF4F5F8),
        onSurface: Color(0xFF2A2D3A),
        onSurfaceVariant: Color(0xFF5C6072),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF4F5F8),
        surfaceContainer: Color(0xFFEAECF2),
        surfaceContainerHigh: Color(0xFFE0E3EC),
        surfaceContainerHighest: Color(0xFFD5D9E4),
        outline: Color(0xFF7A7F92),
        outlineVariant: Color(0xFFD5D9E4),
        shadow: Color(0xFF000000),
        scrim: Color(0x66000000),
        inverseSurface: Color(0xFF2A2D3A),
        onInverseSurface: Color(0xFFF4F5F8),
        inversePrimary: Color(0xFF9EC0FF),
        surfaceTint: blue,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppColors.darkScheme);
  static ThemeData get light => _build(AppColors.lightScheme);

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.bgSelection : AppColors.outlineLight;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      cardColor: scheme.surfaceContainer,
      dividerColor: borderColor,
      focusColor: AppColors.blue.withValues(alpha: 0.28),
      highlightColor: isDark ? AppColors.bgHighlight : AppColors.blue.withValues(alpha: 0.12),
      splashColor: AppColors.blue.withValues(alpha: 0.18),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.bgLineNumber : scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.focusBorder, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.blue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.blue;
          return scheme.onSurfaceVariant;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.blue;
          return isDark ? AppColors.bgSelection : scheme.surfaceContainerHighest;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.bgHighlight : const Color(0xFF2A2D3A),
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        actionTextColor: AppColors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: AppColors.bgHighlight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.blue);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: AppColors.blue, fontSize: 12);
          }
          return TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedTileColor: AppColors.bgCurrentLine,
        selectedColor: AppColors.blue,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.blue,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: AppColors.blue,
        dividerColor: borderColor,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: AppColors.bgSelection,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.bgLineNumber : scheme.surfaceContainerHigh,
        selectedColor: AppColors.bgSelection,
        labelStyle: TextStyle(color: scheme.onSurface),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: scheme.surfaceContainer,
        collapsedBackgroundColor: scheme.surfaceContainer,
        iconColor: scheme.onSurface,
        collapsedIconColor: scheme.onSurfaceVariant,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: scheme.onSurface, fontSize: 16),
        bodyMedium: TextStyle(color: scheme.onSurface, fontSize: 14),
        bodySmall: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        titleLarge: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: scheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        labelSmall: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
      ),
    );
  }
}
