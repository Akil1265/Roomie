import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageHelper {
  // Display Base64 image as a widget
  static Widget displayBase64Image(
    String? base64String, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    if (base64String == null || base64String.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          );
    }

    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true, // Prevents flicker during updates
        errorBuilder: (context, error, stackTrace) {
          print('Error in Image.memory: $error');
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.grey[400],
                ),
              );
        },
      );
    } catch (e) {
      print('Error decoding Base64 image: $e');
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
          );
    }
  }

  // Get circular avatar from Base64 image
  static Widget circularAvatarFromBase64(
    String? base64String, {
    double radius = 20,
    Widget? placeholder,
  }) {
    if (base64String == null || base64String.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child:
            placeholder ??
            Icon(Icons.person, size: radius, color: Colors.grey[400]),
      );
    }

    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(imageBytes),
        onBackgroundImageError: (exception, stackTrace) {
          print('Error loading avatar image: $exception');
        },
      );
    } catch (e) {
      print('Error decoding Base64 avatar: $e');
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child:
            placeholder ??
            Icon(Icons.person, size: radius, color: Colors.grey[400]),
      );
    }
  }

  // Convert image size for display (compress if too large)
  static String? compressBase64ForDisplay(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return base64String;
    }

    // If image is larger than 1MB (approximately 1.3M chars in base64),
    // we might want to show a placeholder instead
    if (base64String.length > 1300000) {
      print(
        'Base64 image is very large (${base64String.length} chars), consider compression',
      );
    }

    return base64String;
  }

  // Validate if string is valid Base64
  static bool isValidBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return false;
    }

    try {
      base64Decode(base64String);
      return true;
    } catch (e) {
      return false;
    }
  }
}
