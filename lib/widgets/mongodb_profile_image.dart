import 'package:flutter/material.dart';
import 'package:roomie/services/firestore_service.dart';
import 'package:roomie/services/image_helper.dart';
import 'package:roomie/services/profile_image_notifier.dart';

class MongoDBProfileImage extends StatefulWidget {
  final String? imageId;
  final double radius;
  final Widget? placeholder;

  const MongoDBProfileImage({
    super.key,
    this.imageId,
    this.radius = 60,
    this.placeholder,
  });

  @override
  MongoDBProfileImageState createState() => MongoDBProfileImageState();
}

class MongoDBProfileImageState extends State<MongoDBProfileImage> {
  final FirestoreService _firestoreService = FirestoreService();
  final ProfileImageNotifier _profileImageNotifier = ProfileImageNotifier();
  String? _base64Image;
  bool _isLoading = true;
  bool _hasError = false;
  String? _lastLoadedImageId;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void dispose() {
    _profileImageNotifier.removeListener(_onProfileImageChanged);
    super.dispose();
  }

  void _onProfileImageChanged() {
    // If the global image ID changed, reload this widget's image
    final globalImageId = _profileImageNotifier.currentImageId;
    print(
      'Global profile image changed to: $globalImageId, current widget imageId: ${widget.imageId}',
    );

    // Always refresh when global state changes, regardless of current widget imageId
    // This ensures we always show the latest image
    if (globalImageId != null && globalImageId != _lastLoadedImageId) {
      print('Refreshing profile image widget due to global change...');
      _loadImage(forceRefresh: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();

    // Listen to global profile image changes
    _profileImageNotifier.addListener(_onProfileImageChanged);
  }

  @override
  void didUpdateWidget(MongoDBProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      print(
        'Profile image widget: imageId changed from ${oldWidget.imageId} to ${widget.imageId}',
      );
      _loadImage(forceRefresh: true);
    }
  }

  // Public method to force refresh the image
  void refresh() {
    _loadImage(forceRefresh: true);
  }

  Future<void> _loadImage({bool forceRefresh = false}) async {
    // Determine which image ID to use: global state takes priority over widget property
    final globalImageId = _profileImageNotifier.currentImageId;
    final imageIdToLoad = globalImageId ?? widget.imageId;

    if (imageIdToLoad == null || imageIdToLoad.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _base64Image = null;
        _lastLoadedImageId = null;
        _retryCount = 0;
      });
      return;
    }

    // Skip loading if same image and not forcing refresh
    if (!forceRefresh &&
        _lastLoadedImageId == imageIdToLoad &&
        _base64Image != null) {
      return;
    }

    // Reset retry count for new image or forced refresh
    if (forceRefresh || _lastLoadedImageId != imageIdToLoad) {
      _retryCount = 0;
    }

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print(
        'Loading profile image for ID: $imageIdToLoad (attempt ${_retryCount + 1}) [Global: $globalImageId, Widget: ${widget.imageId}]',
      );
      final base64Data = await _firestoreService.getProfileImage(imageIdToLoad);

      setState(() {
        _base64Image = base64Data;
        _isLoading = false;
        _hasError = base64Data == null;
        _lastLoadedImageId = imageIdToLoad;
        _retryCount = 0; // Reset on success
      });

      if (base64Data != null) {
        print('Profile image loaded successfully (${base64Data.length} chars)');
      } else {
        print('No profile image data found for ID: $imageIdToLoad');
      }
    } catch (e) {
      print('Error loading profile image (attempt ${_retryCount + 1}): $e');

      // Retry logic
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print('Retrying image load in ${_retryCount * 2} seconds...');

        setState(() {
          _isLoading = true;
          _hasError = false;
        });

        // Wait before retry with exponential backoff
        await Future.delayed(Duration(seconds: _retryCount * 2));

        // Retry loading
        if (mounted) {
          _loadImage(forceRefresh: true);
        }
      } else {
        // Max retries reached
        final globalImageId = _profileImageNotifier.currentImageId;
        final imageIdToLoad = globalImageId ?? widget.imageId;
        print('Max retries reached for image ID: $imageIdToLoad');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _base64Image = null;
          _lastLoadedImageId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: const Color(0xFFF1F2F4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF677583),
            ),
            if (_retryCount > 0)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Retry $_retryCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_hasError || _base64Image == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: const Color(0xFFF1F2F4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.placeholder ??
                Icon(
                  Icons.person,
                  size: widget.radius,
                  color: const Color(0xFF677583),
                ),
            if (_retryCount >= _maxRetries)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error, size: 8, color: Colors.white),
                ),
              ),
          ],
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: ImageHelper.displayBase64Image(
          _base64Image,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          placeholder: CircleAvatar(
            radius: widget.radius,
            backgroundColor: const Color(0xFFF1F2F4),
            child:
                widget.placeholder ??
                Icon(
                  Icons.person,
                  size: widget.radius,
                  color: const Color(0xFF677583),
                ),
          ),
        ),
      ),
    );
  }
}
