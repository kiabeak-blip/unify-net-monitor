// lib/services/network_scanner.dart
import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/device.dart';

// OUI prefix → manufacturer (first 3 MAC octets, uppercase, colon-separated)
const Map<String, String> _ouiDatabase = {
  '00:50:56': 'VMware', '00:0C:29': 'VMware', '00:05:69': 'VMware',
  '00:1C:42': 'Parallels',
  'B8:27:EB': 'Raspberry Pi', 'DC:A6:32': 'Raspberry Pi',
  'E4:5F:01': 'Raspberry Pi', '28:CD:C1': 'Raspberry Pi',
  'D8:3A:DD': 'Raspberry Pi', 'BC:24:11': 'Raspberry Pi',
  '00:1A:11': 'Google', 'F4:F5:D8': 'Google', '54:60:09': 'Google',
  '00:1B:63': 'Apple', '00:16:CB': 'Apple', '58:55:CA': 'Apple',
  'AC:DE:48': 'Apple', 'F0:18:98': 'Apple', 'A4:C3:61': 'Apple',
  '00:25:00': 'Apple', 'E8:8D:28': 'Apple', '78:31:C1': 'Apple',
  '3C:22:FB': 'Apple', '60:F8:1D': 'Apple', '7C:D1:C3': 'Apple',
  'F4:0F:24': 'Samsung', '00:12:47': 'Samsung', '8C:77:12': 'Samsung',
  '18:67:B0': 'Samsung', '2C:AE:2B': 'Samsung',
  '50:32:37': 'Huawei', '54:89:98': 'Huawei', '00:18:82': 'Huawei',
  '28:6E:D4': 'Huawei', '70:72:CF': 'Huawei',
  '00:E0:4C': 'Realtek',
  'D4:3D:7E': 'Intel', '94:65:9C': 'Intel', '00:21:6A': 'Intel',
  'B4:96:91': 'Intel', '8C:8D:28': 'Intel',
  '00:1C:C0': 'Cisco', '00:17:59': 'Cisco', '00:0F:24': 'Cisco',
  '58:97:BD': 'Cisco', 'EC:1D:8B': 'Cisco',
  'E8:9F:80': 'TP-Link', '50:C7:BF': 'TP-Link', 'AC:84:C6': 'TP-Link',
  'C0:25:E9': 'TP-Link', '14:CC:20': 'TP-Link', 'B0:95:75': 'TP-Link',
  '00:23:69': 'Netgear', 'C0:FF:D4': 'Netgear', '28:C6:8E': 'Netgear',
  '00:26:F2': 'Netgear', 'A0:40:A0': 'Netgear',
  'C8:D7:19': 'D-Link', '00:1B:11': 'D-Link', '14:D6:4D': 'D-Link',
  '1C:7E:E5': 'D-Link',
  '20:CF:30': 'Nintendo', '00:17:AB': 'Nintendo', '98:B6:E9': 'Nintendo',
  '8C:56:C5': 'Microsoft', '00:15:5D': 'Microsoft', '00:0D:3A': 'Microsoft',
  '00:50:F2': 'Microsoft', '28:18:78': 'Microsoft',
  '3C:D9:2B': 'HP', '00:1B:78': 'HP', '1C:98:EC': 'HP',
  'F0:92:1C': 'Dell', '00:14:22': 'Dell', 'B8:CA:3A': 'Dell',
  '00:21:9B': 'Dell', '14:FE:B5': 'Dell',
  'FC:15:B4': 'ASUS', '2C:56:DC': 'ASUS', '10:02:B5': 'ASUS',
  '00:1A:92': 'ASUS', '00:1D:92': 'ASUS', 'AC:22:0B': 'ASUS',
  '00:26:5A': 'Belkin', '94:44:52': 'Belkin', '30:46:9A': 'Belkin',
  'CC:32:E5': 'Xiaomi', '00:9E:C8': 'Xiaomi', '28:6C:07': 'Xiaomi',
  'F8:A2:D6': 'Xiaomi', '64:09:80': 'Xiaomi',
  '50:64:2B': 'LG', 'C8:08:E9': 'LG', '00:E0:91': 'LG',
  'A0:39:F7': 'Sony', '00:1A:80': 'Sony', '54:42:49': 'Sony',
  '00:1C:F0': 'Amazon', '74:75:48': 'Amazon', 'FC:65:DE': 'Amazon',
  'A0:02:DC': 'Amazon', '44:65:0D': 'Amazon', '34:D2:70': 'Amazon',
  '00:04:20': 'Linksys', '00:06:25': 'Linksys', '00:0F:66': 'Linksys',
};

class NetworkScanner {
  static const List<int> commonPorts = [
    22,   // SSH
    23,   // Telnet
    25,   // SMTP
    53,   // DNS
    80,   // HTTP
    443,  // HTTPS
    445,  // SMB
    3389, // RDP
    8080, // HTTP Alt
    8443, // HTTPS Alt
  ];

  static const Map<int, String> portNames = {
    22: 'SSH',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    80: 'HTTP',
    443: 'HTTPS',
    445: 'SMB',
    3389: 'RDP',
    8080: 'HTTP Alt',
    8443: 'HTTPS Alt',
  };

  /// Get the local subnet (e.g. "192.168.1")
  static Future<String?> getSubnet() async {
    final ip = await getLocalIP();
    if (ip == null) return null;
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.${parts[2]}';
    return null;
  }

  static Future<String?> getLocalIP() async {
    // Try network_info_plus first (WiFi)
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty && _isPrivateIP(ip)) return ip;
    } catch (_) {}

    // Fallback: scan all network interfaces (catches Ethernet on Windows)
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        // Skip loopback and virtual adapters
        final name = iface.name.toLowerCase();
        if (name.contains('loopback') || name.contains('vmware') ||
            name.contains('virtualbox') || name.contains('vethernet') ||
            name.contains('wsl')) continue;
        for (final addr in iface.addresses) {
          if (_isPrivateIP(addr.address)) return addr.address;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Get the default gateway IP from Windows route table
  static Future<String?> getDefaultGateway() async {
    try {
      final result = await Process.run(
        'powershell', ['-Command',
          '(Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).NextHop'],
        stdoutEncoding: const SystemEncoding(),
      );
      final gw = result.stdout.toString().trim();
      if (gw.isNotEmpty && _isPrivateIP(gw)) return gw;
    } catch (_) {}
    // Fallback: parse ipconfig
    try {
      final result = await Process.run('ipconfig', [],
          stdoutEncoding: const SystemEncoding());
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.toLowerCase().contains('default gateway')) {
          final match = RegExp(r'(\d+\.\d+\.\d+\.\d+)').firstMatch(line);
          if (match != null) return match.group(1);
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _isPrivateIP(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    final parts = ip.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }

  /// Ping a single IP — returns latency in ms or null if unreachable.
  /// On Windows uses ICMP ping for accuracy; falls back to TCP probes.
  static Future<double?> pingDevice(String ip,
      {Duration timeout = const Duration(milliseconds: 600)}) async {
    // Windows: use system ping (ICMP) — most accurate & fast
    if (Platform.isWindows) {
      try {
        final ms = timeout.inMilliseconds.clamp(100, 2000);
        final sw = Stopwatch()..start();
        final result = await Process.run(
            'ping', ['-n', '1', '-w', '$ms', ip],
            stdoutEncoding: const SystemEncoding())
            .timeout(Duration(milliseconds: ms + 300));
        sw.stop();
        final out = result.stdout.toString();
        if (out.contains('TTL=') || out.contains('ttl=')) {
          // Extract actual RTT from ping output
          final rttMatch = RegExp(r'[<\d]+ms').firstMatch(out);
          if (rttMatch != null) {
            final rttStr = rttMatch.group(0)!.replaceAll(RegExp(r'[<ms]'), '');
            return double.tryParse(rttStr) ?? sw.elapsedMilliseconds.toDouble();
          }
          return sw.elapsedMilliseconds.toDouble();
        }
        return null;
      } catch (_) {}
    }

    // Non-Windows or ICMP failed: try TCP ports in parallel
    final ports = [80, 443, 22, 445, 3389, 8080, 23, 135];
    final completer = Completer<double?>();
    int pending = ports.length;

    for (final port in ports) {
      () async {
        try {
          final sw = Stopwatch()..start();
          final socket = await Socket.connect(ip, port, timeout: timeout);
          sw.stop();
          socket.destroy();
          if (!completer.isCompleted) completer.complete(sw.elapsedMicroseconds / 1000.0);
        } catch (_) {
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }
      }();
    }

    return completer.future.timeout(
        Duration(milliseconds: timeout.inMilliseconds + 100),
        onTimeout: () => null);
  }

  /// Scan common ports on an IP
  static Future<List<PortInfo>> scanPorts(String ip) async {
    final results = <PortInfo>[];
    final futures = commonPorts.map((port) async {
      bool isOpen = false;
      try {
        final socket = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 600));
        socket.destroy();
        isOpen = true;
      } catch (_) {
        isOpen = false;
      }
      return PortInfo(
        port: port,
        serviceName: portNames[port] ?? 'Unknown',
        isOpen: isOpen,
      );
    });

    final portResults = await Future.wait(futures);
    results.addAll(portResults);
    return results;
  }

  /// Full check on a single device (ping + ports + identity)
  static Future<Device> checkDevice(Device device) async {
    final latency = await pingDevice(device.ip);
    final ports = await scanPorts(device.ip);
    final now = DateTime.now();

    final history = List<double>.from(device.latencyHistory);
    if (latency != null) {
      history.add(latency);
      if (history.length > 10) history.removeAt(0);
    }

    // Refresh identity info when online; keep existing values when offline
    String? mac = device.macAddress;
    String? hostname = device.hostname;
    String? manufacturer = device.manufacturer;
    if (latency != null) {
      final identity = await fetchIdentityInfo(device.ip);
      mac = identity.mac ?? mac;
      hostname = identity.hostname ?? hostname;
      manufacturer = identity.manufacturer ?? manufacturer;
    }

    return device.copyWith(
      status: latency != null ? DeviceStatus.online : DeviceStatus.offline,
      latencyMs: latency,
      ports: ports,
      lastSeen: latency != null ? now : device.lastSeen,
      lastChecked: now,
      latencyHistory: history,
      macAddress: mac,
      hostname: hostname,
      manufacturer: manufacturer,
    );
  }

  /// Scan the entire subnet — yields devices as found
  static Stream<Device> scanSubnet({
    String? subnet,
    int startHost = 1,
    int endHost = 254,
    void Function(int scanned, int total)? onProgress,
  }) async* {
    final sub = subnet ?? await getSubnet();
    if (sub == null) return;

    final total = endHost - startHost + 1;
    int scanned = 0;

    // Scan in batches — keep to 24 to avoid exhausting process handles
    const batchSize = 24;
    for (int i = startHost; i <= endHost; i += batchSize) {
      final batchEnd = (i + batchSize - 1).clamp(startHost, endHost);
      final batch = List.generate(
          batchEnd - i + 1, (idx) => '${sub}.${i + idx}');

      final futures = batch.map((ip) async {
        final latency = await pingDevice(ip,
            timeout: const Duration(milliseconds: 500));
        scanned++;
        onProgress?.call(scanned, total);
        if (latency != null) {
          final identity = await fetchIdentityInfo(ip);
          final manufacturer = identity.manufacturer;
          return Device(
            id: ip,
            name: manufacturer != null
                ? '$manufacturer (${ip.split('.').last})'
                : _guessDeviceName(ip),
            ip: ip,
            status: DeviceStatus.online,
            latencyMs: latency,
            lastSeen: DateTime.now(),
            lastChecked: DateTime.now(),
            latencyHistory: [latency],
            macAddress: identity.mac,
            hostname: identity.hostname,
            manufacturer: manufacturer,
          );
        }
        return null;
      });

      final results = await Future.wait(futures);
      for (final device in results) {
        if (device != null) yield device;
      }
    }
  }

  static String _guessDeviceName(String ip) {
    final lastOctet = ip.split('.').last;
    // Common router/gateway IPs
    if (lastOctet == '1' || lastOctet == '254') return 'Gateway/Router';
    return 'Device $lastOctet';
  }

  /// Get MAC address via ARP cache (desktop only — Android/iOS restrict MAC access)
  static Future<String?> getMacAddress(String ip) async {
    if (Platform.isAndroid || Platform.isIOS) return null;
    try {
      final result = Platform.isWindows
          ? await Process.run('arp', ['-a', ip],
              stdoutEncoding: const SystemEncoding())
          : await Process.run('arp', ['-n', ip],
              stdoutEncoding: const SystemEncoding());
      final output = result.stdout as String;
      final macRegex = RegExp(r'([0-9a-fA-F]{2}[-:]){5}[0-9a-fA-F]{2}');
      final match = macRegex.firstMatch(output);
      if (match == null) return null;
      return match.group(0)!.replaceAll('-', ':').toUpperCase();
    } catch (_) {
      return null;
    }
  }

  /// Reverse DNS lookup for hostname
  static Future<String?> getHostname(String ip) async {
    try {
      final addr = InternetAddress(ip);
      final reversed = await addr.reverse().timeout(const Duration(seconds: 2));
      final host = reversed.host;
      // Skip if reverse lookup just returned the IP again
      if (host == ip) return null;
      return host;
    } catch (_) {
      return null;
    }
  }

  /// OUI manufacturer lookup from first 3 MAC octets
  static String? lookupManufacturer(String? mac) {
    if (mac == null || mac.length < 8) return null;
    final oui = mac.substring(0, 8).toUpperCase();
    return _ouiDatabase[oui];
  }

  /// Fetch MAC, hostname, and manufacturer for a device (best-effort)
  static Future<({String? mac, String? hostname, String? manufacturer})>
      fetchIdentityInfo(String ip) async {
    final results = await Future.wait([
      getMacAddress(ip),
      getHostname(ip),
    ]);
    final mac = results[0];
    final hostname = results[1];
    final manufacturer = lookupManufacturer(mac);
    return (mac: mac, hostname: hostname, manufacturer: manufacturer);
  }
}
