// lib/services/device_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import 'network_scanner.dart';
import 'notification_service.dart';

class DeviceManager extends ChangeNotifier {
  List<Device> _devices = [];
  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 254;
  String? _localIP;
  String? _subnet;
  String? _gateway;
  Timer? _autoRefreshTimer;
  // Auto-refresh is off by default on Windows (user scans manually)
  bool _autoRefreshEnabled = !Platform.isWindows;
  int _autoRefreshInterval = 30; // seconds

  List<Device> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  int get scanProgress => _scanProgress;
  int get scanTotal => _scanTotal;
  String? get localIP => _localIP;
  String? get subnet => _subnet;
  String? get gateway => _gateway;
  bool get autoRefreshEnabled => _autoRefreshEnabled;
  int get autoRefreshInterval => _autoRefreshInterval;

  int get onlineCount => _devices.where((d) => d.isOnline).length;
  int get offlineCount => _devices.where((d) => d.status == DeviceStatus.offline).length;
  int get totalCount => _devices.length;

  DeviceManager() {
    _init();
  }

  Future<void> _init() async {
    await _loadDevices();
    await _fetchNetworkInfo();
    _startAutoRefresh();
    notifyListeners();
  }

  Future<void> _fetchNetworkInfo() async {
    _localIP = await NetworkScanner.getLocalIP();
    _subnet = await NetworkScanner.getSubnet();
    _gateway = await NetworkScanner.getDefaultGateway();
    notifyListeners();
  }

  // ─── Persistence ───────────────────────────────────────────────
  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('devices');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _devices = list.map((d) => Device.fromJson(d)).toList();
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_devices.map((d) => d.toJson()).toList());
    await prefs.setString('devices', raw);
  }

  // ─── Auto Refresh ───────────────────────────────────────────────
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!_autoRefreshEnabled) return;
    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: _autoRefreshInterval),
      (_) => refreshAllDevices(),
    );
  }

  void setAutoRefresh(bool enabled, {int? intervalSeconds}) {
    _autoRefreshEnabled = enabled;
    if (intervalSeconds != null) _autoRefreshInterval = intervalSeconds;
    _startAutoRefresh();
    notifyListeners();
  }

  // ─── Network Scan ───────────────────────────────────────────────
  Future<void> scanNetwork() async {
    if (_isScanning) return;
    _isScanning = true;
    _scanProgress = 0;
    _scanTotal = 254;
    notifyListeners();

    final subnet = _subnet ?? await NetworkScanner.getSubnet();
    if (subnet == null) {
      _isScanning = false;
      notifyListeners();
      return;
    }

    final discovered = <String>{};

    await for (final device in NetworkScanner.scanSubnet(
      subnet: subnet,
      onProgress: (scanned, total) {
        _scanProgress = scanned;
        _scanTotal = total;
        notifyListeners();
      },
    )) {
      discovered.add(device.ip);
      _upsertDevice(device);
      notifyListeners();
    }

    // Mark previously seen auto-discovered devices as offline if not found
    for (int i = 0; i < _devices.length; i++) {
      if (!_devices[i].isManuallyAdded &&
          !discovered.contains(_devices[i].ip)) {
        final wasOnline = _devices[i].isOnline;
        _devices[i] = _devices[i].copyWith(status: DeviceStatus.offline);
        if (wasOnline) {
          await NotificationService.notifyDeviceDown(_devices[i]);
        }
      }
    }

    _isScanning = false;
    notifyListeners();
    await _saveDevices();
    await NotificationService.notifyScanComplete(
        _devices.length, onlineCount);
  }

  void _upsertDevice(Device newDevice) {
    final idx = _devices.indexWhere((d) => d.ip == newDevice.ip);
    if (idx >= 0) {
      final existing = _devices[idx];
      final wasOffline = !existing.isOnline &&
          existing.status != DeviceStatus.unknown;
      _devices[idx] = existing.copyWith(
        status: newDevice.status,
        latencyMs: newDevice.latencyMs,
        lastSeen: newDevice.lastSeen,
        lastChecked: newDevice.lastChecked,
        latencyHistory: newDevice.latencyHistory,
        macAddress: newDevice.macAddress ?? existing.macAddress,
        hostname: newDevice.hostname ?? existing.hostname,
        manufacturer: newDevice.manufacturer ?? existing.manufacturer,
      );
      if (wasOffline && newDevice.isOnline) {
        NotificationService.notifyDeviceUp(_devices[idx]);
      }
    } else {
      _devices.add(newDevice);
    }
  }

  // ─── Manual Device Management ────────────────────────────────────
  Future<void> addManualDevice(String name, String ip) async {
    final device = Device(
      id: ip,
      name: name,
      ip: ip,
      status: DeviceStatus.unknown,
      isManuallyAdded: true,
    );
    _devices.add(device);
    notifyListeners();
    await _saveDevices();
    // Immediately check the device
    await checkSingleDevice(ip);
  }

  Future<void> removeDevice(String ip) async {
    _devices.removeWhere((d) => d.ip == ip);
    notifyListeners();
    await _saveDevices();
  }

  Future<void> renameDevice(String ip, String newName) async {
    final idx = _devices.indexWhere((d) => d.ip == ip);
    if (idx >= 0) {
      _devices[idx] = _devices[idx].copyWith(name: newName);
      notifyListeners();
      await _saveDevices();
    }
  }

  // ─── Refresh ────────────────────────────────────────────────────
  Future<void> refreshAllDevices() async {
    if (_isScanning) return;
    for (int i = 0; i < _devices.length; i++) {
      _devices[i] = _devices[i].copyWith(status: DeviceStatus.checking);
    }
    notifyListeners();

    for (int i = 0; i < _devices.length; i++) {
      final wasOnline = _devices[i].isOnline;
      final updated = await NetworkScanner.checkDevice(_devices[i]);
      final nowOnline = updated.isOnline;

      if (wasOnline && !nowOnline) {
        await NotificationService.notifyDeviceDown(updated);
      } else if (!wasOnline && nowOnline) {
        await NotificationService.notifyDeviceUp(updated);
      }
      _devices[i] = updated;
      notifyListeners();
    }
    await _saveDevices();
  }

  Future<void> checkSingleDevice(String ip) async {
    final idx = _devices.indexWhere((d) => d.ip == ip);
    if (idx < 0) return;
    _devices[idx] = _devices[idx].copyWith(status: DeviceStatus.checking);
    notifyListeners();

    final updated = await NetworkScanner.checkDevice(_devices[idx]);
    _devices[idx] = updated;
    notifyListeners();
    await _saveDevices();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
