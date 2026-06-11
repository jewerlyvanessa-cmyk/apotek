import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../widgets/app_icon_3d.dart';

class QuickMenuItem {
  const QuickMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accent;
}

/// Mobile: 3 kolom. Web/desktop: tile lebih kecil, coba muat satu baris.
class QuickMenuGrid extends StatelessWidget {
  const QuickMenuGrid({super.key, required this.items});

  static const _mobileBreakpoint = 600.0;
  static const _desktopTileWidth = 112.0;

  final List<QuickMenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < _mobileBreakpoint;

        if (isMobile) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.92,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _tile(context, items[index], mobile: true),
          );
        }

        const spacing = AppSpacing.md;
        final maxCols = (width / _desktopTileWidth).floor().clamp(3, 8);
        final crossAxisCount =
            items.length <= maxCols ? items.length : maxCols;
        final gridWidth = crossAxisCount * _desktopTileWidth +
            (crossAxisCount - 1) * spacing;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: gridWidth.clamp(0, width),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 0.95,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _tile(context, items[index], mobile: false),
            ),
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, QuickMenuItem item, {required bool mobile}) {
    return QuickMenuTile(
      icon: item.icon,
      title: item.title,
      onTap: item.onTap,
      accent: item.accent,
      iconBox: mobile ? 52 : 46,
      iconSize: mobile ? 26 : 22,
      labelStyle: mobile
          ? Theme.of(context).textTheme.labelMedium
          : Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12),
      compact: mobile,
      dense: !mobile,
    );
  }
}

class QuickMenuTile extends StatefulWidget {
  const QuickMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent,
    this.iconBox = 48,
    this.iconSize = 26,
    this.labelStyle,
    this.compact = true,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accent;
  final double iconBox;
  final double iconSize;
  final TextStyle? labelStyle;
  final bool compact;
  final bool dense;

  @override
  State<QuickMenuTile> createState() => _QuickMenuTileState();
}

class _QuickMenuTileState extends State<QuickMenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.dense ? 12.0 : (widget.compact ? 14.0 : 16.0);
    final gap = AppSpacing.sm;
    final accent = AppIconAccents.forKey(widget.title, override: widget.accent);

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: _pressed ? 4 : 10,
              offset: Offset(0, _pressed ? 2 : 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: widget.dense ? AppSpacing.sm : AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon3D(
                    icon: widget.icon,
                    size: widget.iconBox,
                    iconSize: widget.iconSize,
                    accent: accent,
                    radius: radius - 2,
                  ),
                  SizedBox(height: gap),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (widget.labelStyle ??
                            Theme.of(context).textTheme.labelMedium)
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: AppColors.textPrimary,
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
