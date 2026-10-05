import 'package:flutter/material.dart';

import '../utils/app_icons.dart';

class AssetImageAvatar extends StatelessWidget {
  final String? imageUrl;
  final String seed;

  const AssetImageAvatar({
    super.key,
    required this.imageUrl,
    required this.seed,
  });

  String get _resolvedImageUrl {
    final storedImage = imageUrl?.trim();
    if (storedImage != null && storedImage.isNotEmpty) return storedImage;

    final imageSeed = seed.trim().isEmpty ? 'asset' : seed.trim();
    return Uri.https('api.dicebear.com', '/7.x/shapes/png', {
      'seed': imageSeed,
    }).toString();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        _resolvedImageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF836EF9).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const AppIcon(
            AppIcons.bolt,
            color: Color(0xFF836EF9),
            size: 20,
          ),
        ),
      ),
    );
  }
}
