import 'package:flutter/material.dart';
import 'package:nabu_explain/core/theme/app_theme.dart';

class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BoxShadow? shadow;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient ?? NabuColors.gradientMulti,
          borderRadius: radius,
          boxShadow: [
            shadow ??
                BoxShadow(
                  color: (gradient?.colors.first ?? NabuColors.violetElectric)
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? tintColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.onTap,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = tintColor ?? (isDark ? Colors.white10 : Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: isDark ? 0.08 : 0.65),
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          border: Border.all(
            color: tint.withValues(alpha: isDark ? 0.15 : 0.4),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

class NabuButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient? gradient;
  final double? height;

  const NabuButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.gradient,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient ?? NabuColors.gradientMulti,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (gradient?.colors.first ?? NabuColors.violetElectric)
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? NabuColors.violetElectric;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)]) : null,
          color: selected ? null : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.transparent : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}