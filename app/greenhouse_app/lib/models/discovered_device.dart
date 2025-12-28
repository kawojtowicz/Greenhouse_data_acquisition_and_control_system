class DiscoveredDevice {
  final String deviceId;
  final bool assigned;

  DiscoveredDevice({required this.deviceId, this.assigned = false});

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      deviceId: json['device_id'] ?? '',
      assigned: json['assigned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'device_id': deviceId, 'assigned': assigned};
  }
}
