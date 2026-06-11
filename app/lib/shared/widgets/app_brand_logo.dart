import 'package:flutter/material.dart';
import '../../app/assets/app_assets.dart';
import '../../app/theme/app_colors.dart';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    required this.asset,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double? height;
  final double? width;
  final BoxFit fit;

  const AppBrandLogo.login({
    super.key,
    this.height = 120,
    this.width,
    this.fit = BoxFit.contain,
  }) : asset = AppAssets.logoLogin;

  const AppBrandLogo.dalam({
    super.key,
    this.height = 32,
    this.width,
    this.fit = BoxFit.contain,
  }) : asset = AppAssets.logoDalam;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(
        Icons.local_pharmacy,
        size: height ?? 32,
        color: AppColors.primary,
      ),
    );
  }
}
