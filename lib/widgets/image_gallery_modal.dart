import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/image_record.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class ImageGalleryModal extends StatefulWidget {
  final Device device;
  final ImageRecord? initialSelectedImage;
  final ValueChanged<ImageRecord> onImageBroken;

  const ImageGalleryModal({
    super.key,
    required this.device,
    this.initialSelectedImage,
    required this.onImageBroken,
  });

  @override
  State<ImageGalleryModal> createState() => _ImageGalleryModalState();
}

class _ImageGalleryModalState extends State<ImageGalleryModal> {
  ImageRecord? _activeLightboxImage;

  @override
  void initState() {
    super.initState();
    _activeLightboxImage = widget.initialSelectedImage;
  }

  void _openLightbox(ImageRecord img) {
    setState(() => _activeLightboxImage = img);
  }

  void _closeLightbox() {
    setState(() => _activeLightboxImage = null);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    // Read live from the provider on every build instead of a frozen list
    // passed in once at dialog-open time. A plain constructor parameter
    // would freeze at whatever the live Firestore stream had delivered
    // the instant this dialog opened — missing anything that arrives
    // after (the stream still catching up, a backfill still running) —
    // with no way to show it without closing and reopening the dialog.
    final images = context.watch<DeviceProvider>().deviceImages;

    // Derived fresh every build from the live list + whichever image is
    // currently open, rather than cached in a field — a cached index
    // would point at the wrong photo (or crash) the moment the live list
    // reorders or changes length underneath it.
    final activeIndex = _activeLightboxImage == null
        ? -1
        : images.indexOf(_activeLightboxImage!);

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
                            '${images.length} Photos',
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
                child: _activeLightboxImage != null && activeIndex != -1
                    ? _buildLightboxView(dateFormat, images, activeIndex)
                    : _buildGridView(dateFormat, images),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(DateFormat dateFormat, List<ImageRecord> images) {
    if (images.isEmpty) {
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
              'Ensure photo files follow the naming pattern: ${widget.device.driveMatchKey}',
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
      itemCount: images.length,
      itemBuilder: (context, index) {
        final img = images[index];
        return GestureDetector(
          onTap: () => _openLightbox(img),
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
                  Image.network(
                    img.storageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Could mean deleted from Drive, or just as easily a
                      // transient throttle from lh3.googleusercontent.com
                      // (unofficial hotlinking, not a supported API) —
                      // those look identical here, so this never deletes
                      // on its own. The small button lets an administrator
                      // confirm removal only after actually checking Drive.
                      return Container(
                        color: AppColors.glassSurface,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                            tooltip: 'Image unavailable — remove if the original photo was deleted',
                            onPressed: () => widget.onImageBroken(img),
                          ),
                        ),
                      );
                    },
                  ),
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

  Widget _buildLightboxView(
    DateFormat dateFormat,
    List<ImageRecord> images,
    int activeIndex,
  ) {
    final img = images[activeIndex];

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
                    '${activeIndex + 1} of ${images.length}',
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
                  child: Image.network(
                    img.storageUrl,
                    fit: BoxFit.contain,
                    // See the grid cell's errorBuilder above — never
                    // auto-deletes, since a load failure here can't be
                    // told apart from a transient lh3.googleusercontent.com
                    // throttle.
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textMuted,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Image unavailable',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            TextButton(
                              onPressed: () => widget.onImageBroken(img),
                              child: const Text('Remove if the original photo was deleted'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Image Details Bar
            Container(
              padding: const EdgeInsets.all(14),
              color: AppColors.surfaceSecondary,
              child: Column(
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
            ),
          ],
        ),

        // Navigation Arrows
        if (activeIndex > 0)
          Positioned(
            left: 10,
            top: 250,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => _openLightbox(images[activeIndex - 1]),
              ),
            ),
          ),

        if (activeIndex < images.length - 1)
          Positioned(
            right: 10,
            top: 250,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => _openLightbox(images[activeIndex + 1]),
              ),
            ),
          ),
      ],
    );
  }
}
