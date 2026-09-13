import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Decodes a base64 `data:image/...;base64,` string into bytes (or null).
Uint8List? stockPhotoBytes(dynamic photo) {
  if (photo is String && photo.isNotEmpty) {
    final i = photo.indexOf(',');
    if (i >= 0) {
      try {
        return base64Decode(photo.substring(i + 1));
      } catch (_) {}
    }
  }
  return null;
}

/// Circular photo thumbnail — used wherever a photo rides along with a
/// heading or order.
Widget stockCirclePhoto(
  Uint8List? bytes, {
  required IconData fallbackIcon,
  Color fallbackColor = const Color(0xFF8B5CF6),
  double radius = 16,
  VoidCallback? onTap,
}) {
  final child = bytes != null
      ? ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        )
      : Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fallbackColor.withOpacity(0.15),
            border: Border.all(color: fallbackColor.withOpacity(0.35)),
          ),
          child: Icon(fallbackIcon, size: radius, color: fallbackColor),
        );

  if (onTap == null) return child;
  return GestureDetector(onTap: onTap, child: child);
}
