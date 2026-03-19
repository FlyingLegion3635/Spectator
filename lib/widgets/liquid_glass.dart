import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:spectator/theme/appearance.dart';

class GlassSpec {
  const GlassSpec({
    required this.fill,
    required this.border,
    required this.blur,
    required this.shadow,
  });

  final Color fill;
  final Color border;
  final double blur;
  final List<BoxShadow> shadow;

  factory GlassSpec.fromTheme(BuildContext context, {double blur = 24}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassSpec(
      fill: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.58),
      border: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08),
      blur: blur,
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.margin,
    this.blur,
    this.enabled,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? blur;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final useGlass = enabled ?? isApplePlatform;
    if (!useGlass) {
      return Container(
        margin: margin,
        padding: padding,
        child: child,
      );
    }

    final spec = GlassSpec.fromTheme(context, blur: blur ?? 24);

    return Container(
      margin: margin,
      decoration: BoxDecoration(boxShadow: spec.shadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: spec.blur,
            sigmaY: spec.blur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: spec.fill,
              border: Border.all(color: spec.border),
              borderRadius: borderRadius,
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassListTile extends StatelessWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.dense,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      dense: dense,
      contentPadding: contentPadding,
    );

    if (!isApplePlatform) {
      return tile;
    }

    return GlassSurface(
      borderRadius: borderRadius,
      padding: EdgeInsets.zero,
      child: tile,
    );
  }
}

class GlassCheckboxListTile extends StatelessWidget {
  const GlassCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
    this.dense,
    this.controlAffinity = ListTileControlAffinity.trailing,
    this.activeColor,
    this.checkColor,
    this.side,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final ListTileControlAffinity controlAffinity;
  final Color? activeColor;
  final Color? checkColor;
  final BorderSide? side;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isApplePlatform) {
      return CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        contentPadding: contentPadding,
        dense: dense,
        controlAffinity: controlAffinity,
        activeColor: activeColor,
        checkColor: checkColor,
        side: side,
      );
    }

    final checkbox = Checkbox.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      checkColor: checkColor,
      side: side,
    );

    return GlassListTile(
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      dense: dense,
      leading: controlAffinity == ListTileControlAffinity.leading
          ? checkbox
          : null,
      trailing: controlAffinity == ListTileControlAffinity.leading
          ? null
          : checkbox,
      borderRadius: borderRadius,
    );
  }
}

class GlassSwitchListTile extends StatelessWidget {
  const GlassSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
    this.dense,
    this.activeColor,
    this.activeThumbColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final Color? activeColor;
  final Color? activeThumbColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isApplePlatform) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        contentPadding: contentPadding,
        dense: dense,
        activeColor: activeThumbColor ?? activeColor,
        activeTrackColor: activeTrackColor,
        inactiveThumbColor: inactiveThumbColor,
        inactiveTrackColor: inactiveTrackColor,
      );
    }

    final toggle = Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: activeThumbColor ?? activeColor,
      activeTrackColor: activeTrackColor,
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
    );

    return GlassListTile(
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      dense: dense,
      trailing: toggle,
      borderRadius: borderRadius,
    );
  }
}

class GlassSegmentedControl<T extends Object> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.labelBuilder,
    this.height = 50,
    this.borderRadius = const BorderRadius.all(Radius.circular(25)),
  });

  final T? value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final String Function(T option) labelBuilder;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isApplePlatform) {
      return _MaterialSegmentedControl<T>(
        value: value,
        options: options,
        onChanged: onChanged,
        labelBuilder: labelBuilder,
        height: height,
        borderRadius: borderRadius,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumbColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.82);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF636366);

    return GlassSurface(
      borderRadius: borderRadius,
      padding: const EdgeInsets.all(4),
      blur: 22,
      child: SizedBox(
        height: height,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          thumbColor: thumbColor,
          backgroundColor: Colors.transparent,
          onValueChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          children: {
            for (final option in options)
              option: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  labelBuilder(option),
                  style: TextStyle(
                    color: value == option ? textColor : mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}

class _MaterialSegmentedControl<T extends Object> extends StatelessWidget {
  const _MaterialSegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.labelBuilder,
    required this.height,
    required this.borderRadius,
  });

  final T? value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final String Function(T option) labelBuilder;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: borderRadius,
          border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: options.map((option) {
            final isSelected = value == option;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(borderRadius.topLeft.x),
                  ),
                  child: Center(
                    child: Text(
                      labelBuilder(option),
                      style: TextStyle(
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class GlassMenuItem<T> {
  const GlassMenuItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class GlassMenuButton<T> extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = const Icon(Icons.more_vert),
    this.tooltip,
  });

  final List<GlassMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (!isApplePlatform) {
      return PopupMenuButton<T>(
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (context) => items
            .map(
              (item) => PopupMenuItem<T>(
                value: item.value,
                child: Text(item.label),
              ),
            )
            .toList(),
        icon: icon,
      );
    }

    return IconButton(
      tooltip: tooltip,
      icon: icon,
      onPressed: () async {
        final selected = await _showGlassMenu(
          context: context,
          items: items,
        );
        if (selected != null) {
          onSelected(selected);
        }
      },
    );
  }
}

Future<T?> _showGlassMenu<T>({
  required BuildContext context,
  required List<GlassMenuItem<T>> items,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final buttonBox = context.findRenderObject() as RenderBox;
  final buttonRect = buttonBox.localToGlobal(Offset.zero, ancestor: overlay) &
      buttonBox.size;

  final media = MediaQuery.of(context);
  final menuWidth = 200.0;
  final menuHeight = (items.length * 44).clamp(120, 260).toDouble();

  final left = (buttonRect.right - menuWidth)
      .clamp(12.0, media.size.width - 12.0 - menuWidth)
      .toDouble();
  final top = (buttonRect.bottom + 8)
      .clamp(12.0, media.size.height - 12.0 - menuHeight)
      .toDouble();

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'Dismiss',
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    pageBuilder: (context, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: Material(
                type: MaterialType.transparency,
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  blur: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      return InkWell(
                        onTap: () => Navigator.pop(context, item.value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              if (item.icon != null) ...[
                                Icon(item.icon, size: 18),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
