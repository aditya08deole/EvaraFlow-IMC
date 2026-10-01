import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/image_record.dart';
import '../models/device.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class ImageGalleryModal extends StatefulWidget {
  final Device device;
  final List<ImageRecord> images;
  final ImageRecord? initialSelectedImage;

  const ImageGalleryModal({
    super.key,
    required this.device,
    required this.images,
    this.initialSelectedImage,
  });

  @override
  State<ImageGalleryModal> createState() => _ImageGalleryModalState();
}

class _ImageGalleryModalState extends State<ImageGalleryModal> {
  ImageRecord? _activeLightboxImage;
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedImage != null) {
      _activeLightboxImage = widget.initialSelectedImage;
      _activeImageIndex = widget.images.indexOf(widget.initialSelectedImage!);
    }
  }

  void _openLightbox(ImageRecord img, int index) {
    setState(() {
      _activeLightboxImage = img;
      _activeImageIndex = index;
    });
  }

  void _closeLightbox() {
    setState(() {
      _activeLightboxImage = null;
    });
  }

  void _nextImage() {
    if (_activeImageIndex < widget.images.length - 1) {
      setState(() {
        _activeImageIndex++;
        _activeLightboxImage = widget.images[_activeImageIndex];
      });
    }
  }

  void _previousImage() {
    if (_activeImageIndex > 0) {
      setState(() {
        _activeImageIndex--;
        _activeLightboxImage = widget.images[_activeImageIndex];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 900,
        height: 650,
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          child: Column(
            children: [
              // Modal Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: AppColors.driveBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Image Gallery - ${widget.device.name} (${widget.device.deviceId})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(
                              AppShapes.radiusXs,
                            ),
                          ),
                          child: Text(
                            '${widget.images.length} Photos (Google Drive)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.driveBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Modal Body: Grid view or Lightbox
              Expanded(
                child: _activeLightboxImage != null
                    ? _buildLightboxView(dateFormat)
                    : _buildGridView(dateFormat),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(DateFormat dateFormat) {
    if (widget.images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No images found for this device.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ensure files in Google Drive follow key pattern: ${widget.device.driveMatchKey}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.images.length,
      itemBuilder: (context, index) {
        final img = widget.images[index];
        return GestureDetector(
          onTap: () => _openLightbox(img, index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppShapes.radiusXs),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              // 1px inside the outer radius so the clip nests under the border.
              borderRadius: BorderRadius.circular(AppShapes.radiusXs - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(img.storageUrl, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Text(
                        img.capturedAt != null
                            ? dateFormat.format(img.capturedAt!)
                            : img.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLightboxView(DateFormat dateFormat) {
    final img = _activeLightboxImage!;

    return Stack(
      children: [
        Column(
          children: [
            // Top Toolbar inside Lightbox
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _closeLightbox,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to Gallery Grid'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${_activeImageIndex + 1} of ${widget.images.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Photo View
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(img.storageUrl, fit: BoxFit.contain),
                ),
              ),
            ),

            // Image Details Bar
            Container(
              padding: const EdgeInsets.all(14),
              color: AppColors.surfaceSecondary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File: ${img.fileName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Captured: ${img.capturedAt != null ? dateFormat.format(img.capturedAt!) : "N/A"}  |  Synced: ${dateFormat.format(img.receivedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Open in Drive'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.driveBlue,
                      side: const BorderSide(color: AppColors.driveBlue),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Navigation Arrows
        if (_activeImageIndex > 0)
          Positioned(
            left: 10,
            top: 250,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _previousImage,
              ),
            ),
          ),

        if (_activeImageIndex < widget.images.length - 1)
          Positioned(
            right: 10,
            top: 250,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _nextImage,
              ),
            ),
          ),
      ],
    );
  }
}
