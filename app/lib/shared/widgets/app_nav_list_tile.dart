import 'package:flutter/material.dart';
import 'app_icon_3d.dart';

/// ListTile navigasi dengan ikon 3D — konsisten di Admin, Gudang, dll.
class AppNavListTile extends StatelessWidget {
  const AppNavListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accentKey,
    this.accent,
    this.trailing = const Icon(Icons.chevron_right),
    this.wrapCard = true,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? accentKey;
  final Color? accent;
  final Widget? trailing;
  final bool wrapCard;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      dense: dense,
      leading: AppIcon3D.list(
        icon: icon,
        accentKey: accentKey ?? title,
        accent: accent,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );

    if (!wrapCard) return tile;
    return Card(child: tile);
  }
}
