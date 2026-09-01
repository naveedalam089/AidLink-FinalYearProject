import 'dart:convert';

import 'package:flutter/material.dart';

/// Avatar widget that handles both network URLs and Base64 data URIs.
/// NetworkImage fails silently on mobile for data: URIs so we decode manually.
class UserAvatar extends StatelessWidget {
  final String photoUrl;
  final double radius;
  final Color backgroundColor;
  final Widget? fallbackChild;

  const UserAvatar({
    Key? key,
    required this.photoUrl,
    this.radius = 20,
    this.backgroundColor = const Color(0xFF2E7D32),
    this.fallbackChild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child:
            fallbackChild ??
            Icon(Icons.person, color: Colors.white, size: radius),
      );
    }

    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Str = photoUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          child:
              fallbackChild ??
              Icon(Icons.person, color: Colors.white, size: radius),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: NetworkImage(photoUrl),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
}
