import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudinary folders used to organize uploads.
enum CloudinaryFolder { profile, groups, other }

/// Configuration holder for Cloudinary (no secret stored here!).
class CloudinaryConfig {
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'cloud-roomie', // Your cloud name from credentials
  );

  /// Unsigned upload preset configured in Cloudinary dashboard.
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'roomie_unsigned', // Create this preset in dashboard
  );

  /// Base API endpoint.
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  CloudinaryService._internal();
  factory CloudinaryService() => _instance;

  /// Test Cloudinary connection and configuration
  void testConnection() {
    debugPrint('=== CLOUDINARY CONNECTION TEST ===');
    debugPrint('Cloud Name: ${CloudinaryConfig.cloudName}');
    debugPrint('Upload Preset: ${CloudinaryConfig.uploadPreset}');
    debugPrint('Upload URL: ${CloudinaryConfig.uploadUrl}');
    debugPrint('===============================');
  }

  /// Upload from a File (mobile / desktop). Returns secure URL or null.
  Future<String?> uploadFile({
    required File file,
    CloudinaryFolder folder = CloudinaryFolder.other,
    String? publicId,
    Map<String, String>? context,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return uploadBytes(
        bytes: bytes,
        fileName: file.path.split(Platform.pathSeparator).last,
        folder: folder,
        publicId: publicId,
        context: context,
      );
    } catch (e) {
      debugPrint('Cloudinary uploadFile error: $e');
      return null;
    }
  }

  /// Upload from raw bytes (useful for web XFile.readAsBytes()).
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    CloudinaryFolder folder = CloudinaryFolder.other,
    String? publicId,
    Map<String, String>? context,
  }) async {
    try {
      debugPrint('Cloudinary: Starting upload to ${CloudinaryConfig.uploadUrl}');
      debugPrint('Cloudinary: Using cloud name: ${CloudinaryConfig.cloudName}');
      debugPrint('Cloudinary: Using upload preset: ${CloudinaryConfig.uploadPreset}');
      
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      final folderName = _folderName(folder);
      if (folderName.isNotEmpty) {
        request.fields['folder'] = folderName;
      }
      if (publicId != null) {
        request.fields['public_id'] = publicId;
      }
      if (context != null && context.isNotEmpty) {
        // context must be key=value|key2=value2
        request.fields['context'] = context.entries
            .map((e) => '${e.key}=${e.value}')
            .join('|');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        debugPrint('Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
            'Cloudinary upload failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary uploadBytes error: $e');
      return null;
    }
  }

  String _folderName(CloudinaryFolder folder) {
    switch (folder) {
      case CloudinaryFolder.profile:
        return 'roomie/profile';
      case CloudinaryFolder.groups:
        return 'roomie/groups';
      case CloudinaryFolder.other:
        return 'roomie/other';
    }
  }
}
