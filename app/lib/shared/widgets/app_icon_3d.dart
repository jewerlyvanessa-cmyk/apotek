import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Palet gradien ikon — variasi warna dalam nuansa apotek.
abstract final class AppIconAccents {
  static const palette = <Color>[
    Color(0xFF0D9488),
    Color(0xFF0891B2),
    Color(0xFF15803D),
    Color(0xFF0369A1),
    Color(0xFF0F766E),
    Color(0xFFCA8A04),
    Color(0xFF7C3AED),
    Color(0xFFBE185D),
  ];

  static Color forKey(String key, {Color? override}) {
    if (override != null) return override;
    if (key.isEmpty) return AppColors.primary;
    return palette[key.hashCode.abs() % palette.length];
  }

  static Color darken(Color c) => Color.lerp(c, Colors.black, 0.22)!;

  static Color lighten(Color c) => Color.lerp(c, Colors.white, 0.28)!;
}

/// Ikon gradien 3D — dipakai di menu cepat, list navigasi, dan avatar.
class AppIcon3D extends StatelessWidget {
  const AppIcon3D({
    super.key,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.accent,
    this.radius,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color accent;
  final double? radius;

  /// Menu cepat dashboard (besar).
  factory AppIcon3D.menu({
    required IconData icon,
    String accentKey = '',
    Color? accent,
    double radius = 12,
  }) {
    final key = accentKey.isNotEmpty ? accentKey : icon.codePoint.toString();
    return AppIcon3D(
      icon: icon,
      size: 52,
      iconSize: 26,
      accent: AppIconAccents.forKey(key, override: accent),
      radius: radius,
    );
  }

  /// ListTile / kartu navigasi.
  factory AppIcon3D.list({
    required IconData icon,
    String accentKey = '',
    Color? accent,
  }) {
    final key = accentKey.isNotEmpty ? accentKey : icon.codePoint.toString();
    return AppIcon3D(
      icon: icon,
      size: 40,
      iconSize: 20,
      accent: AppIconAccents.forKey(key, override: accent),
      radius: 10,
    );
  }

  /// Avatar profil (bulat).
  factory AppIcon3D.avatar({
    required IconData icon,
    String accentKey = '',
    Color? accent,
  }) {
    final key = accentKey.isNotEmpty ? accentKey : icon.codePoint.toString();
    return AppIcon3D(
      icon: icon,
      size: 48,
      iconSize: 24,
      accent: AppIconAccents.forKey(key, override: accent ?? AppColors.primary),
      radius: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? 12.0;
    final deep = AppIconAccents.darken(accent);
    final light = AppIconAccents.lighten(accent);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, accent, deep],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: deep.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.45,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.28,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: deep.withValues(alpha: 0.65),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
