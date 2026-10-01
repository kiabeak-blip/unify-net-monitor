// lib/models/device.dart

enum DeviceStatus { online, offline, checking, unknown }

class PortInfo {
  final int port;
  final String serviceName;
  final bool isOpen;

  PortInfo({required this.port, required this.serviceName, required this.isOpen});

  Map<String, dynamic> toJson() => {
        'port': port,
        'serviceName': serviceName,
        'isOpen': isOpen,
      };

  factory PortInfo.fromJson(Map<String, dynamic> json) => PortInfo(
        port: json['port'],
        serviceName: json['serviceName'],
        isOpen: json['isOpen'],
      );
}

class Device {
  final String id;
  String name;
  String ip;
  DeviceStatus status;
  double? latencyMs;
  List<PortInfo> ports;
  DateTime? lastSeen;
  DateTime? lastChecked;
  bool isManuallyAdded;
  List<double> latencyHistory; // last 10 readings
  String? macAddress;
  String? hostname;
  String? manufacturer;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    this.status = DeviceStatus.unknown,
    this.latencyMs,
    this.ports = const [],
    this.lastSeen,
    this.lastChecked,
    this.isManuallyAdded = false,
    List<double>? latencyHistory,
    this.macAddress,
    this.hostname,
    this.manufacturer,
  }) : latencyHistory = latencyHistory ?? [];

  bool get isOnline => status == DeviceStatus.online;

  String get statusLabel {
    switch (status) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.checking:
        return 'Checking...';
      case DeviceStatus.unknown:
        return 'Unknown';
    }
  }

  String get latencyLabel {
    if (latencyMs == null) return '—';
    if (latencyMs! < 1) return '<1 ms';
    return '${latencyMs!.toStringAsFixed(1)} ms';
  }

  String get latencyQuality {
    if (latencyMs == null) return 'unknown';
    if (latencyMs! < 10) return 'excellent';
    if (latencyMs! < 50) return 'good';
    if (latencyMs! < 150) return 'fair';
    return 'poor';
  }

  int get openPortsCount => ports.where((p) => p.isOpen).length;

  Device copyWith({
    String? name,
    String? ip,
    DeviceStatus? status,
    double? latencyMs,
    List<PortInfo>? ports,
    DateTime? lastSeen,
    DateTime? lastChecked,
    bool? isManuallyAdded,
    List<double>? latencyHistory,
    String? macAddress,
    String? hostname,
    String? manufacturer,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      status: status ?? this.status,
      latencyMs: latencyMs ?? this.latencyMs,
      ports: ports ?? this.ports,
      lastSeen: lastSeen ?? this.lastSeen,
      lastChecked: lastChecked ?? this.lastChecked,
      isManuallyAdded: isManuallyAdded ?? this.isManuallyAdded,
      latencyHistory: latencyHistory ?? this.latencyHistory,
      macAddress: macAddress ?? this.macAddress,
      hostname: hostname ?? this.hostname,
      manufacturer: manufacturer ?? this.manufacturer,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'status': status.index,
        'latencyMs': latencyMs,
        'ports': ports.map((p) => p.toJson()).toList(),
        'lastSeen': lastSeen?.toIso8601String(),
        'lastChecked': lastChecked?.toIso8601String(),
        'isManuallyAdded': isManuallyAdded,
        'latencyHistory': latencyHistory,
        'macAddress': macAddress,
        'hostname': hostname,
        'manufacturer': manufacturer,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'],
        name: json['name'],
        ip: json['ip'],
        status: DeviceStatus.values[json['status'] ?? 3],
        latencyMs: json['latencyMs']?.toDouble(),
        ports: (json['ports'] as List<dynamic>?)
                ?.map((p) => PortInfo.fromJson(p))
                .toList() ??
            [],
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'])
            : null,
        lastChecked: json['lastChecked'] != null
            ? DateTime.parse(json['lastChecked'])
            : null,
        isManuallyAdded: json['isManuallyAdded'] ?? false,
        latencyHistory:
            (json['latencyHistory'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble()).toList() ?? [],
        macAddress: json['macAddress'],
        hostname: json['hostname'],
        manufacturer: json['manufacturer'],
      );
}
