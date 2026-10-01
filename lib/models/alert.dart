enum AlertType { deviceOffline, noFlow, highFlow }

enum AlertStatus { newAlert, acknowledged, resolved }

class AlertItem {
  final String id;
  final String deviceId;
  final String deviceName;
  final AlertType type;
  final String severity; // info, warning, critical
  final AlertStatus status;
  final String description;
  final DateTime openedAt;
  final String? acknowledgedBy;
  final DateTime? resolvedAt;

  const AlertItem({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.type,
    required this.severity,
    required this.status,
    required this.description,
    required this.openedAt,
    this.acknowledgedBy,
    this.resolvedAt,
  });

  String get typeLabel {
    switch (type) {
      case AlertType.deviceOffline:
        return 'Device Offline';
      case AlertType.noFlow:
        return 'No Flow (Unexpected)';
      case AlertType.highFlow:
        return 'High Flow Exceeded';
    }
  }

  AlertItem copyWith({
    AlertStatus? status,
    String? acknowledgedBy,
    DateTime? resolvedAt,
  }) {
    return AlertItem(
      id: id,
      deviceId: deviceId,
      deviceName: deviceName,
      type: type,
      severity: severity,
      status: status ?? this.status,
      description: description,
      openedAt: openedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
