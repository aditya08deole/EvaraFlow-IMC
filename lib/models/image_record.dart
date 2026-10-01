class ImageRecord {
  final String id;
  final String? deviceId; // null if unassigned
  final String driveFileId;
  final String fileName;
  final DateTime? capturedAt;
  final DateTime receivedAt;
  final String storageUrl;
  final String thumbnailUrl;
  final String syncStatus;

  const ImageRecord({
    required this.id,
    this.deviceId,
    required this.driveFileId,
    required this.fileName,
    this.capturedAt,
    required this.receivedAt,
    required this.storageUrl,
    required this.thumbnailUrl,
    this.syncStatus = 'synced',
  });

  bool get isUnassigned => deviceId == null;

  factory ImageRecord.fromJson(Map<String, dynamic> json) {
    return ImageRecord(
      id: json['id'] as String,
      deviceId: json['device_id'] as String?,
      driveFileId: json['drive_file_id'] as String,
      fileName: json['file_name'] as String,
      capturedAt: json['captured_at'] != null
          ? DateTime.parse(json['captured_at'])
          : null,
      receivedAt: DateTime.parse(json['received_at']),
      storageUrl: json['storage_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      syncStatus: json['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'drive_file_id': driveFileId,
      'file_name': fileName,
      'captured_at': capturedAt?.toIso8601String(),
      'received_at': receivedAt.toIso8601String(),
      'storage_url': storageUrl,
      'thumbnail_url': thumbnailUrl,
      'sync_status': syncStatus,
    };
  }
}
