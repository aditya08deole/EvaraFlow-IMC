class Reading {
  final String deviceId;
  final DateTime deviceTs;
  final DateTime receivedAt;
  final double flowLpm;
  final double? totalL;
  final String sensorStatus;
  final String? firmwareVersion;

  const Reading({
    required this.deviceId,
    required this.deviceTs,
    required this.receivedAt,
    required this.flowLpm,
    this.totalL,
    this.sensorStatus = 'ok',
    this.firmwareVersion,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      deviceId: json['device_id'] as String,
      deviceTs: DateTime.parse(json['ts'] ?? json['device_ts']),
      receivedAt: json['received_at'] != null
          ? DateTime.parse(json['received_at'])
          : DateTime.now(),
      flowLpm: (json['flow_lpm'] as num).toDouble(),
      totalL: json['total_l'] != null
          ? (json['total_l'] as num).toDouble()
          : null,
      sensorStatus: json['status'] as String? ?? 'ok',
      firmwareVersion: json['fw'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'ts': deviceTs.toIso8601String(),
      'received_at': receivedAt.toIso8601String(),
      'flow_lpm': flowLpm,
      'total_l': totalL,
      'status': sensorStatus,
      'fw': firmwareVersion,
    };
  }
}
