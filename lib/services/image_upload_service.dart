// ignore_for_file: depend_on_referenced_packages
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';

class ImageUploadService {
  static ImageUploadService? _instance;
  final Dio _dio = Dio();

  // Hardcoded Cloudinary credentials (used if Firestore fetch fails)
  static const String _fallbackCloudName = 'djyy3g7aa';
  static const String _fallbackApiKey = '758348471298734';
  static const String _fallbackApiSecret = 'ZWN1jray-sG0lGNbT35vVvfQLmc';
  static const String _fallbackUploadPreset = 'devlinkmedia';

  String? _cloudName;
  String? _apiKey;
  String? _apiSecret;
  String? _uploadPreset;

  static ImageUploadService get instance {
    _instance ??= ImageUploadService._();
    return _instance!;
  }

  ImageUploadService._();


  void _useFallbackCredentials() {
    _cloudName = _fallbackCloudName;
    _apiKey = _fallbackApiKey;
    _apiSecret = _fallbackApiSecret;
    _uploadPreset = _fallbackUploadPreset;
  }

  Future<String> uploadImage(File imageFile) async {
    try {
      if (_cloudName == null ||
          _apiKey == null ||
          _apiSecret == null ||
          _uploadPreset == null) {
        _useFallbackCredentials(); // Use hardcoded credentials directly
      }

      final String uploadUrl =
          'https://api.cloudinary.com/v1_1/${_cloudName!.trim()}/image/upload';

      List<int> imageBytes = await imageFile.readAsBytes();

      // Get the original file extension
      String fileExtension = imageFile.path.split('.').last.toLowerCase();
      String filename = 'image.$fileExtension';

      // Ensure we have a valid image format
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)) {
        fileExtension = 'png'; // Default to PNG for transparency support
        filename = 'image.png';
      }

      final Map<String, dynamic> body = {
        'file': MultipartFile.fromBytes(imageBytes, filename: filename),
        'upload_preset': _uploadPreset,
      };
      // Only include api_key if available; unsigned presets don't require it
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        body['api_key'] = _apiKey;
      }
      final formData = FormData.fromMap(body);

      final response = await _dio.post(uploadUrl, data: formData);
      log(response.statusCode.toString());
      log(response.data.toString());

      if (response.statusCode == 200) {
        return response.data['secure_url'];
      } else {
        final message = response.data is Map && response.data['error'] != null
            ? response.data['error']['message']
            : response.data.toString();
        throw Exception('Failed to upload image: $message');
      }
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<String> uploadImageFromUrl(String imageUrl) async {
    try {
      if (_cloudName == null ||
          _apiKey == null ||
          _apiSecret == null ||
          _uploadPreset == null) {
        _useFallbackCredentials(); // Use hardcoded credentials directly
      }

      final String uploadUrl =
          'https://api.cloudinary.com/v1_1/${_cloudName!.trim()}/image/upload';

      final Map<String, dynamic> body = {
        'file': imageUrl,
        'upload_preset': _uploadPreset,
      };
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        body['api_key'] = _apiKey;
      }
      final formData = FormData.fromMap(body);

      final response = await _dio.post(uploadUrl, data: formData);
      if (response.statusCode == 200) {
        return response.data['secure_url'];
      } else {
        final message = response.data is Map && response.data['error'] != null
            ? response.data['error']['message']
            : response.data.toString();
        throw Exception('Failed to upload image from URL: $message');
      }
    } catch (e) {
      throw Exception('Failed to upload image from URL: $e');
    }
  }
}
