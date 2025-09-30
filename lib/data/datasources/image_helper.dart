import 'package:flutter/material.dart';

class ImageHelper {
  // Display a network image (Cloudinary) with graceful fallback.
  static Widget networkImage(
    String? url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (url == null || url.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(Icons.image_outlined, color: Colors.grey[400]),
          );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) {
        print('Network image error: $error');
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: Icon(Icons.broken_image, color: Colors.grey[400]),
            );
      },
      // Optional: you could add frameBuilder for fade-in effect
    );
  }

}
