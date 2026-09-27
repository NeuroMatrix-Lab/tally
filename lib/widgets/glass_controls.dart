import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_theme.dart';

/// 主按钮：主题蓝强调的圆角玻璃按钮。
class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final button = GlassButton.custom(
      onTap: onPressed ?? () {},
      enabled: enabled,
      height: height,
      style: GlassButtonStyle.prominent,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 16),
      settings: LiquidGlassSettings(
        glassColor: AppColors.blue.withValues(alpha: 0.88),
        thickness: 18,
        refractiveIndex: 1.12,
        lightIntensity: 0.55,
      ),
      glowColor: AppColors.blue.withValues(alpha: 0.35),
      child: content,
    );

    return expanded ? SizedBox(height: height, child: button) : button;
  }
}

/// 次按钮：中性圆角玻璃，描边感更轻。
class GlassSecondaryButton extends StatelessWidget {
  const GlassSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.height = 44,
    this.width,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double height;
  final double? width;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = danger
        ? AppColors.red
        : (isDark ? Colors.white : AppColors.textPrimary);
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    // 保证按钮有足够横向空间，文字不被裁切
    final resolvedWidth = width ?? (expanded ? null : label.length * 16.0 + 36.0);

    final button = GlassButton.custom(
      onTap: onPressed ?? () {},
      enabled: onPressed != null,
      height: height,
      width: resolvedWidth,
      style: GlassButtonStyle.filled,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 16),
      settings: LiquidGlassSettings(
        glassColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.55),
        thickness: 16,
        refractiveIndex: 1.1,
        lightIntensity: 0.5,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: content,
      ),
    );

    return expanded ? SizedBox(height: height, child: button) : button;
  }
}

/// 文本型操作（对话框确认/取消等）。
class GlassTextAction extends StatelessWidget {
  const GlassTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.blue;
    return GlassButton.custom(
      onTap: onPressed ?? () {},
      enabled: onPressed != null,
      height: 40,
      width: 72,
      style: GlassButtonStyle.transparent,
      useOwnLayer: true,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 玻璃输入框：兼容常见 TextField 参数。
class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textStyle,
    this.height,
    this.searchStyle = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final double? height;
  final bool searchStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = hintText ?? labelText ?? '';
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.textSecondary;
    final resolvedPrefix =
        prefixIcon != null ? IconTheme(data: IconThemeData(color: iconColor, size: 20), child: prefixIcon!) : null;
    final resolvedSuffix =
        suffixIcon != null ? IconTheme(data: IconThemeData(color: iconColor, size: 20), child: suffixIcon!) : null;

    final settings = LiquidGlassSettings(
      glassColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.62),
      thickness: 16,
      refractiveIndex: 1.1,
      lightIntensity: 0.5,
    );

    if (searchStyle) {
      return GlassTextField.search(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        prefixIcon: resolvedPrefix,
        suffixIcon: resolvedSuffix,
        onSuffixTap: onSuffixTap,
        enabled: enabled,
        readOnly: readOnly,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        textStyle: textStyle ??
            TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
            ),
        placeholderStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
        ),
        shape: const LiquidRoundedRectangle(borderRadius: 16),
        settings: settings,
        useOwnLayer: true,
      );
    }

    return GlassTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      prefixIcon: resolvedPrefix,
      suffixIcon: resolvedSuffix,
      onSuffixTap: onSuffixTap,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines ?? 1,
      minLines: minLines,
      maxLength: maxLength,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      height: height ?? 52,
      textStyle: textStyle ??
          TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 15,
          ),
      placeholderStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
      ),
      shape: const LiquidRoundedRectangle(borderRadius: 16),
      settings: settings,
      useOwnLayer: true,
    );
  }
}

/// 统一高度/圆角的玻璃选择条（账本、日期、人员等）。
class GlassSelector extends StatelessWidget {
  const GlassSelector({
    super.key,
    this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.placeholder = false,
    this.trailing = const Icon(Icons.arrow_drop_down),
    this.height = 52,
  });

  final String? label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  final bool placeholder;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = LiquidGlassSettings(
      glassColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.62),
      thickness: 16,
      refractiveIndex: 1.1,
      lightIntensity: 0.5,
    );

    return GlassButton.custom(
      onTap: onTap,
      height: height,
      style: GlassButtonStyle.filled,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 16),
      settings: settings,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: placeholder
                          ? AppColors.textSecondary
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                IconTheme(
                  data: IconThemeData(
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 输入框右侧的紧凑选择钮（打开已有选项列表）。
class GlassPickButton extends StatelessWidget {
  const GlassPickButton({
    super.key,
    required this.onTap,
    this.icon = Icons.list_alt,
    this.tooltip,
    this.size = 52,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = LiquidGlassSettings(
      glassColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.62),
      thickness: 16,
      refractiveIndex: 1.1,
      lightIntensity: 0.5,
    );

    final button = GlassButton.custom(
      onTap: onTap,
      width: size,
      height: size,
      style: GlassButtonStyle.filled,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 16),
      settings: settings,
      child: Icon(
        icon,
        size: 22,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 悬浮主操作（原 FAB）。
class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GlassButton(
      icon: Icon(icon, color: Colors.white),
      iconColor: Colors.white,
      onTap: onPressed,
      label: tooltip ?? '',
      width: 56,
      height: 56,
      useOwnLayer: true,
      style: GlassButtonStyle.prominent,
      shape: const LiquidOval(),
      settings: LiquidGlassSettings(
        glassColor: AppColors.blue.withValues(alpha: 0.9),
        thickness: 20,
        refractiveIndex: 1.12,
        lightIntensity: 0.6,
      ),
      glowColor: AppColors.blue.withValues(alpha: 0.4),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 分类筛选胶囊：选中主题蓝底白字，未选中浅玻璃黑字。
class GlassFilterChip extends StatelessWidget {
  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected ? Colors.white : (isDark ? Colors.white : Colors.black);

    return GlassButton.custom(
      onTap: () => onSelected(!selected),
      height: 36,
      style: selected ? GlassButtonStyle.prominent : GlassButtonStyle.filled,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 18),
      settings: LiquidGlassSettings(
        glassColor: selected
            ? AppColors.blue.withValues(alpha: 0.92)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.55)),
        thickness: 16,
        refractiveIndex: 1.1,
        lightIntensity: 0.5,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
