// lib/services/network_scanner.dart
import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/device.dart';

// OUI prefix â†’ manufacturer (first 3 MAC octets, uppercase, colon-separated)
const Map<String, String> _ouiDatabase = {
  // Amazon
  '74:75:48': 'Amazon', 'FC:65:DE': 'Amazon', 'A0:02:DC': 'Amazon', '44:65:0D': 'Amazon',
  '34:D2:70': 'Amazon', '00:BB:3A': 'Amazon', '10:AE:60': 'Amazon', '18:74:2E': 'Amazon',
  '28:EF:01': 'Amazon', '40:B4:CD': 'Amazon', '50:DC:E7': 'Amazon', '68:37:E9': 'Amazon',
  '74:29:AF': 'Amazon', '84:D6:D0': 'Amazon', 'A4:08:01': 'Amazon', 'B4:7C:9C': 'Amazon',
  'D0:33:11': 'Amazon', 'FC:A1:83': 'Amazon',
  // Apple
  '00:1B:63': 'Apple', '00:16:CB': 'Apple', '58:55:CA': 'Apple', 'AC:DE:48': 'Apple',
  'F0:18:98': 'Apple', 'A4:C3:61': 'Apple', '00:25:00': 'Apple', 'E8:8D:28': 'Apple',
  '78:31:C1': 'Apple', '3C:22:FB': 'Apple', '60:F8:1D': 'Apple', '7C:D1:C3': 'Apple',
  'F8:1E:DF': 'Apple', 'AC:87:A3': 'Apple', '8C:85:90': 'Apple', '70:CD:60': 'Apple',
  'BC:52:B7': 'Apple', 'F4:31:C3': 'Apple', 'A8:51:AB': 'Apple', '98:01:A7': 'Apple',
  '18:AF:61': 'Apple', '40:CB:C0': 'Apple', 'D0:E1:40': 'Apple', 'C8:2A:14': 'Apple',
  '00:23:12': 'Apple', '00:26:B0': 'Apple', '10:93:E9': 'Apple', '14:10:9F': 'Apple',
  '34:15:9E': 'Apple', '38:0F:4A': 'Apple', '44:2A:60': 'Apple', '50:EA:D6': 'Apple',
  '54:26:96': 'Apple', '68:96:7B': 'Apple', '74:E2:F5': 'Apple', '84:38:35': 'Apple',
  '90:72:40': 'Apple', 'A0:ED:CD': 'Apple', 'B8:8D:12': 'Apple', 'C8:69:CD': 'Apple',
  // Aruba
  '00:0B:86': 'Aruba', '94:B4:0F': 'Aruba', 'D8:C7:C8': 'Aruba', '00:1A:1E': 'Aruba',
  '24:DE:C6': 'Aruba', '40:E3:D6': 'Aruba', '6C:F3:7F': 'Aruba', '84:D4:7E': 'Aruba',
  '9C:1C:12': 'Aruba', 'AC:A3:1E': 'Aruba', 'B4:5D:50': 'Aruba', 'C4:01:7C': 'Aruba',
  'CC:E8:AC': 'Aruba', 'F0:5C:19': 'Aruba',
  // ASUS
  '2C:56:DC': 'ASUS', '10:02:B5': 'ASUS', '00:1A:92': 'ASUS', '00:1D:92': 'ASUS',
  'AC:22:0B': 'ASUS', '00:0C:6E': 'ASUS', '00:0E:A6': 'ASUS', '00:11:D8': 'ASUS',
  '00:13:D4': 'ASUS', '00:15:F2': 'ASUS', '00:17:31': 'ASUS', '00:1B:FC': 'ASUS',
  '00:1E:8C': 'ASUS', '00:22:15': 'ASUS', '00:23:54': 'ASUS', '00:24:8C': 'ASUS',
  '00:26:18': 'ASUS', '08:60:6E': 'ASUS', '0C:9D:92': 'ASUS', '10:7B:EF': 'ASUS',
  '14:DA:E9': 'ASUS', '18:31:BF': 'ASUS', '20:CF:30': 'ASUS', '2C:4D:54': 'ASUS',
  '30:5A:3A': 'ASUS', '38:D5:47': 'ASUS', '3C:97:0E': 'ASUS', '40:16:7E': 'ASUS',
  '40:B0:FA': 'ASUS', '44:8A:5B': 'ASUS', '4C:ED:FB': 'ASUS', '50:46:5D': 'ASUS',
  '58:11:22': 'ASUS', '5C:FF:35': 'ASUS', '60:45:CB': 'ASUS', '60:A4:4C': 'ASUS',
  '6C:FD:B9': 'ASUS', '70:4D:7B': 'ASUS', '74:D0:2B': 'ASUS', '7C:10:C9': 'ASUS',
  '80:1F:02': 'ASUS', '84:A9:C4': 'ASUS', '8C:FD:F0': 'ASUS', '90:E6:BA': 'ASUS',
  '9C:5C:8E': 'ASUS', 'A0:36:BC': 'ASUS', 'AC:9E:17': 'ASUS', 'B0:6E:BF': 'ASUS',
  'B4:2E:99': 'ASUS', 'B8:EE:65': 'ASUS', 'BC:AE:C5': 'ASUS', 'C8:60:00': 'ASUS',
  'D4:5D:64': 'ASUS', 'D8:50:E6': 'ASUS', 'E0:CB:4E': 'ASUS', 'F0:79:59': 'ASUS',
  'F4:6D:04': 'ASUS', 'FC:AA:14': 'ASUS',
  // Belkin
  '94:44:52': 'Belkin', '00:30:BD': 'Belkin', '00:11:50': 'Belkin', '00:17:3F': 'Belkin',
  '00:1C:DF': 'Belkin', 'EC:1A:59': 'Belkin',
  // Brother
  '00:80:77': 'Brother', 'E4:B3:18': 'Brother',
  // Canon
  '00:80:91': 'Canon', '04:72:95': 'Canon', '04:DA:D2': 'Canon', '08:00:46': 'Canon',
  '00:00:85': 'Canon', '00:1E:8F': 'Canon',
  // Cisco
  '00:1C:C0': 'Cisco', '00:17:59': 'Cisco', '00:0F:24': 'Cisco', '58:97:BD': 'Cisco',
  'EC:1D:8B': 'Cisco', '00:00:0C': 'Cisco', '00:01:42': 'Cisco', '00:01:43': 'Cisco',
  '00:01:63': 'Cisco', '00:01:64': 'Cisco', '00:01:96': 'Cisco', '00:01:97': 'Cisco',
  '00:02:16': 'Cisco', '00:02:17': 'Cisco', '00:02:3D': 'Cisco', '00:02:4A': 'Cisco',
  '00:02:4B': 'Cisco', '00:02:7D': 'Cisco', '00:02:7E': 'Cisco', '00:02:B9': 'Cisco',
  '00:03:6B': 'Cisco', '00:03:E3': 'Cisco', '00:03:FD': 'Cisco', '00:04:27': 'Cisco',
  '00:04:4D': 'Cisco', '00:04:6D': 'Cisco', '00:04:C0': 'Cisco', '00:05:DC': 'Cisco',
  '00:06:7C': 'Cisco', '00:06:D7': 'Cisco', '00:07:0D': 'Cisco', '00:07:4F': 'Cisco',
  '00:07:50': 'Cisco', '00:07:EB': 'Cisco', '00:07:EC': 'Cisco', '00:08:20': 'Cisco',
  '00:08:21': 'Cisco', '00:08:E3': 'Cisco', '00:09:11': 'Cisco', '00:09:12': 'Cisco',
  '00:09:43': 'Cisco', '00:09:44': 'Cisco', '00:09:7B': 'Cisco', '00:09:B7': 'Cisco',
  '00:0A:41': 'Cisco', '00:0A:42': 'Cisco', '00:0A:8A': 'Cisco', '00:0A:B8': 'Cisco',
  '00:0B:45': 'Cisco', '00:0B:46': 'Cisco', '00:0B:5F': 'Cisco', '00:0B:60': 'Cisco',
  '00:0C:CE': 'Cisco', '00:0C:CF': 'Cisco', '00:0D:28': 'Cisco', '00:0D:29': 'Cisco',
  '00:0D:65': 'Cisco', '00:0D:BC': 'Cisco', '00:0D:EC': 'Cisco', '00:0E:08': 'Cisco',
  '00:0E:38': 'Cisco', '00:0E:83': 'Cisco', '00:0E:84': 'Cisco', '00:0E:D7': 'Cisco',
  '00:0F:23': 'Cisco', '00:0F:35': 'Cisco', '00:0F:90': 'Cisco', '00:0F:F7': 'Cisco',
  '00:10:07': 'Cisco', '00:10:0B': 'Cisco', '00:10:11': 'Cisco', '00:10:14': 'Cisco',
  '00:10:1F': 'Cisco', '00:10:29': 'Cisco', '00:10:2F': 'Cisco', '00:10:54': 'Cisco',
  '00:10:7B': 'Cisco', '00:10:79': 'Cisco', '00:10:A6': 'Cisco', '00:10:F6': 'Cisco',
  '00:11:20': 'Cisco', '00:11:21': 'Cisco', '00:11:5C': 'Cisco', '00:11:92': 'Cisco',
  '00:11:93': 'Cisco', '00:11:BB': 'Cisco', '00:12:00': 'Cisco', '00:12:01': 'Cisco',
  '00:12:43': 'Cisco', '00:12:44': 'Cisco', '00:12:79': 'Cisco', '00:12:7F': 'Cisco',
  '00:12:D9': 'Cisco', '00:13:1A': 'Cisco', '00:13:5F': 'Cisco', '00:13:60': 'Cisco',
  '00:13:7F': 'Cisco', '00:13:80': 'Cisco', '00:13:C3': 'Cisco', '00:14:1B': 'Cisco',
  '00:14:1C': 'Cisco', '00:14:69': 'Cisco', '00:14:6A': 'Cisco', '00:14:A9': 'Cisco',
  '00:14:F1': 'Cisco', '00:14:F2': 'Cisco', '00:15:2B': 'Cisco', '00:15:2C': 'Cisco',
  '00:15:62': 'Cisco', '00:15:63': 'Cisco', '00:15:C6': 'Cisco', '00:15:C7': 'Cisco',
  '00:15:F9': 'Cisco', '00:16:47': 'Cisco', '00:16:9C': 'Cisco', '00:16:9D': 'Cisco',
  '00:16:C7': 'Cisco', '00:17:0E': 'Cisco', '00:17:94': 'Cisco', '00:17:95': 'Cisco',
  '00:17:DF': 'Cisco', '00:18:18': 'Cisco', '00:18:19': 'Cisco', '00:18:68': 'Cisco',
  '00:18:73': 'Cisco', '00:18:74': 'Cisco', '00:18:B9': 'Cisco', '00:19:06': 'Cisco',
  '00:19:07': 'Cisco', '00:19:2F': 'Cisco', '00:19:30': 'Cisco', '00:19:55': 'Cisco',
  '00:19:56': 'Cisco', '00:19:A9': 'Cisco', '00:1A:2F': 'Cisco', '00:1A:30': 'Cisco',
  '00:1A:6C': 'Cisco', '00:1A:6D': 'Cisco', '00:1A:A1': 'Cisco', '00:1A:A2': 'Cisco',
  '00:1A:E2': 'Cisco', '00:1B:0C': 'Cisco', '00:1B:0D': 'Cisco', '00:1B:2A': 'Cisco',
  '00:1B:54': 'Cisco', '00:1B:8F': 'Cisco', '00:1B:D4': 'Cisco', '00:1C:10': 'Cisco',
  '00:1C:57': 'Cisco', '00:1C:58': 'Cisco', '00:1C:B0': 'Cisco', '00:1D:45': 'Cisco',
  '00:1D:46': 'Cisco', '00:1D:70': 'Cisco', '00:1D:A1': 'Cisco', '00:1D:A2': 'Cisco',
  '00:1D:E5': 'Cisco', '00:1E:13': 'Cisco', '00:1E:14': 'Cisco', '00:1E:49': 'Cisco',
  '00:1E:4A': 'Cisco', '00:1E:6D': 'Cisco', '00:1E:79': 'Cisco', '00:1E:7A': 'Cisco',
  '00:1E:BE': 'Cisco', '00:1E:BD': 'Cisco', '00:1F:26': 'Cisco', '00:1F:27': 'Cisco',
  '00:1F:6C': 'Cisco', '00:1F:6D': 'Cisco', '00:1F:9E': 'Cisco', '00:1F:C9': 'Cisco',
  '00:1F:CA': 'Cisco', '00:20:78': 'Cisco', '00:21:1B': 'Cisco', '00:21:1C': 'Cisco',
  '00:21:55': 'Cisco', '00:21:56': 'Cisco', '00:21:A0': 'Cisco', '00:21:A1': 'Cisco',
  '00:22:0C': 'Cisco', '00:22:0D': 'Cisco', '00:22:55': 'Cisco', '00:22:56': 'Cisco',
  '00:22:90': 'Cisco', '00:22:91': 'Cisco', '00:22:BE': 'Cisco', '00:22:BF': 'Cisco',
  '00:23:02': 'Cisco', '00:23:03': 'Cisco', '00:23:33': 'Cisco', '00:23:34': 'Cisco',
  '00:23:5E': 'Cisco', '00:23:5F': 'Cisco', '00:23:AB': 'Cisco', '00:23:AC': 'Cisco',
  '00:23:BE': 'Cisco', '00:23:BF': 'Cisco', '00:23:EA': 'Cisco', '00:23:EB': 'Cisco',
  '00:24:13': 'Cisco', '00:24:14': 'Cisco', '00:24:50': 'Cisco', '00:24:51': 'Cisco',
  '00:24:97': 'Cisco', '00:24:98': 'Cisco', '00:24:C4': 'Cisco', '00:24:F7': 'Cisco',
  '00:24:F9': 'Cisco', '00:25:45': 'Cisco', '00:25:46': 'Cisco', '00:25:83': 'Cisco',
  '00:25:84': 'Cisco', '00:25:B4': 'Cisco', '00:26:0A': 'Cisco', '00:26:0B': 'Cisco',
  '00:26:52': 'Cisco', '00:26:53': 'Cisco', '00:26:CB': 'Cisco', '00:26:CC': 'Cisco',
  '00:27:0D': 'Cisco', '00:27:0E': 'Cisco', '24:E9:B3': 'Cisco', '2C:54:2D': 'Cisco',
  '3C:08:F6': 'Cisco', '3C:13:CC': 'Cisco', '44:D3:CA': 'Cisco', '48:F8:B3': 'Cisco',
  '4C:4E:35': 'Cisco', '50:3D:E5': 'Cisco', '54:75:D0': 'Cisco', '58:BC:27': 'Cisco',
  '60:45:BD': 'Cisco', '64:00:F1': 'Cisco', '68:86:A7': 'Cisco', '6C:20:56': 'Cisco',
  '70:69:5A': 'Cisco', '74:86:7A': 'Cisco', '78:DA:6E': 'Cisco', '7C:AD:74': 'Cisco',
  '80:E8:6F': 'Cisco', '84:B8:02': 'Cisco', '88:5A:92': 'Cisco', '8C:60:4F': 'Cisco',
  '90:6C:AC': 'Cisco', '94:57:A5': 'Cisco', '98:90:96': 'Cisco', '9C:AF:CA': 'Cisco',
  'A0:E0:AF': 'Cisco', 'A4:4C:11': 'Cisco', 'A4:56:30': 'Cisco', 'A8:9D:21': 'Cisco',
  'AC:74:B1': 'Cisco', 'B0:AA:77': 'Cisco', 'B4:14:89': 'Cisco', 'B4:E9:B0': 'Cisco',
  'BC:16:65': 'Cisco', 'C0:8C:60': 'Cisco', 'C4:72:95': 'Cisco', 'C8:00:84': 'Cisco',
  'CC:46:D6': 'Cisco', 'D0:57:4C': 'Cisco', 'D0:C7:89': 'Cisco', 'D4:8C:B5': 'Cisco',
  'D8:24:BD': 'Cisco', 'DC:A5:F4': 'Cisco', 'E0:5F:B9': 'Cisco', 'E4:C7:22': 'Cisco',
  'E8:BA:70': 'Cisco', 'EC:E1:A9': 'Cisco', 'F0:25:72': 'Cisco', 'F4:AC:D1': 'Cisco',
  'F4:BD:9E': 'Cisco', 'F8:66:F2': 'Cisco', 'FC:FB:FB': 'Cisco',
  // Dahua
  '90:02:A9': 'Dahua', '4C:11:BF': 'Dahua', '08:ED:ED': 'Dahua', '14:1A:AA': 'Dahua',
  '34:0D:33': 'Dahua', '70:6F:E6': 'Dahua', '78:08:71': 'Dahua', 'A4:6B:B6': 'Dahua',
  'B4:A3:82': 'Dahua', 'D2:94:0A': 'Dahua', 'E4:63:DA': 'Dahua',
  // Dell
  'F0:92:1C': 'Dell', '00:14:22': 'Dell', 'B8:CA:3A': 'Dell', '00:21:9B': 'Dell',
  '14:FE:B5': 'Dell', '00:06:5B': 'Dell', '00:08:74': 'Dell', '00:0B:DB': 'Dell',
  '00:0D:56': 'Dell', '00:11:43': 'Dell', '00:12:3F': 'Dell', '00:13:72': 'Dell',
  '00:15:C5': 'Dell', '00:16:F0': 'Dell', '00:18:8B': 'Dell', '00:19:B9': 'Dell',
  '00:1A:A0': 'Dell', '00:1C:23': 'Dell', '00:1D:09': 'Dell', '00:1E:4F': 'Dell',
  '00:1F:C4': 'Dell', '00:21:70': 'Dell', '00:22:19': 'Dell', '00:23:AE': 'Dell',
  '00:24:E8': 'Dell', '00:25:64': 'Dell', '00:26:B9': 'Dell', '00:27:13': 'Dell',
  '14:18:77': 'Dell', '14:B3:1F': 'Dell', '18:03:73': 'Dell', '18:66:DA': 'Dell',
  '1C:40:24': 'Dell', '20:47:47': 'Dell', '24:6E:96': 'Dell', '24:B6:FD': 'Dell',
  '28:F1:0E': 'Dell', '2C:76:8A': 'Dell', '34:17:EB': 'Dell', '34:48:ED': 'Dell',
  '38:63:BB': 'Dell', '3C:2C:30': 'Dell', '44:A8:42': 'Dell', '48:4D:7E': 'Dell',
  '4C:C2:6E': 'Dell', '50:9A:4C': 'Dell', '54:48:10': 'Dell', '58:8A:5A': 'Dell',
  '5C:26:0A': 'Dell', '5C:F9:DD': 'Dell', '60:9C:9F': 'Dell', '6C:2B:59': 'Dell',
  '70:10:6F': 'Dell', '74:86:E2': 'Dell', '78:45:C4': 'Dell', '7C:C3:A1': 'Dell',
  '80:18:44': 'Dell', '84:7B:57': 'Dell', '88:AE:1D': 'Dell', '8C:04:BA': 'Dell',
  '90:B1:1C': 'Dell', '94:18:82': 'Dell', '9C:EB:E8': 'Dell', 'A4:1F:72': 'Dell',
  'A4:BA:DB': 'Dell', 'B0:83:FE': 'Dell', 'B8:AC:6F': 'Dell', 'BC:30:5B': 'Dell',
  'C8:1F:66': 'Dell', 'C8:F9:F9': 'Dell', 'D4:C9:EF': 'Dell', 'D8:9E:F3': 'Dell',
  'DC:A9:71': 'Dell', 'E0:DB:55': 'Dell', 'E4:11:5B': 'Dell', 'E8:B1:FC': 'Dell',
  'EC:F4:BB': 'Dell', 'F0:1F:AF': 'Dell', 'F8:DB:88': 'Dell', 'FC:15:B4': 'Dell',
  // D-Link
  'C8:D7:19': 'D-Link', '00:1B:11': 'D-Link', '14:D6:4D': 'D-Link', '1C:7E:E5': 'D-Link',
  '00:04:76': 'D-Link', '00:05:5D': 'D-Link', '00:0D:88': 'D-Link', '00:11:95': 'D-Link',
  '00:13:46': 'D-Link', '00:15:E9': 'D-Link', '00:17:9A': 'D-Link', '00:19:5B': 'D-Link',
  '00:1C:F0': 'D-Link', '00:1E:58': 'D-Link', '00:21:91': 'D-Link', '00:22:B0': 'D-Link',
  '00:24:01': 'D-Link', '00:26:5A': 'D-Link', '1C:AF:F7': 'D-Link', '28:10:7B': 'D-Link',
  '34:08:04': 'D-Link', '4C:00:82': 'D-Link', '54:B8:0A': 'D-Link', '5C:D9:98': 'D-Link',
  '6C:72:20': 'D-Link', '84:C9:B2': 'D-Link', '90:94:E4': 'D-Link', 'A0:AB:1B': 'D-Link',
  'BC:F6:85': 'D-Link', 'C8:BE:19': 'D-Link', 'CC:B2:55': 'D-Link', 'D8:FE:E3': 'D-Link',
  'E8:CC:18': 'D-Link', 'F0:7D:68': 'D-Link',
  // Epson
  '00:00:48': 'Epson', '00:26:AB': 'Epson',
  // Fortinet
  '00:09:0F': 'Fortinet', '70:4C:A5': 'Fortinet', '08:5B:0E': 'Fortinet', '1C:E8:68': 'Fortinet',
  '28:FD:80': 'Fortinet', '34:4B:50': 'Fortinet', '54:BF:64': 'Fortinet', '58:3F:C3': 'Fortinet',
  '64:00:6A': 'Fortinet',
  // GNS3
  '0C:5E:7E': 'GNS3',
  // GNS3 Virtual
  '50:00:00': 'GNS3 Virtual',
  // Google
  '00:1A:11': 'Google', 'F4:F5:D8': 'Google', '54:60:09': 'Google', '3C:5A:B4': 'Google',
  'F4:F5:E8': 'Google', '94:95:A0': 'Google', 'A4:77:33': 'Google',
  // Hikvision
  'C0:56:E3': 'Hikvision', 'BC:AD:28': 'Hikvision', '44:19:B6': 'Hikvision', '28:57:BE': 'Hikvision',
  '3C:E8:24': 'Hikvision', '54:C4:15': 'Hikvision', '68:CF:FE': 'Hikvision', '8C:E7:48': 'Hikvision',
  'C4:64:13': 'Hikvision', 'C8:70:D5': 'Hikvision', 'D0:14:11': 'Hikvision', 'E0:D0:55': 'Hikvision',
  'EC:71:DB': 'Hikvision',
  // HP
  '3C:D9:2B': 'HP', '00:1B:78': 'HP', '1C:98:EC': 'HP', '00:01:E6': 'HP',
  '00:01:E7': 'HP', '00:02:A5': 'HP', '00:04:EA': 'HP', '00:06:38': 'HP',
  '00:08:02': 'HP', '00:0A:57': 'HP', '00:0B:CD': 'HP', '00:0D:9D': 'HP',
  '00:0E:7F': 'HP', '00:10:83': 'HP', '00:11:0A': 'HP', '00:13:21': 'HP',
  '00:14:38': 'HP', '00:15:60': 'HP', '00:16:35': 'HP', '00:17:08': 'HP',
  '00:18:71': 'HP', '00:19:BB': 'HP', '00:1A:4B': 'HP', '00:1C:C4': 'HP',
  '00:1D:B3': 'HP', '00:1E:0B': 'HP', '00:1F:29': 'HP', '00:21:5A': 'HP',
  '00:22:64': 'HP', '00:23:7D': 'HP', '00:24:81': 'HP', '00:25:B3': 'HP',
  '00:26:55': 'HP', '10:60:4B': 'HP', '14:02:EC': 'HP', '14:58:D0': 'HP',
  '18:A9:05': 'HP', '1C:C1:DE': 'HP', '20:08:9B': 'HP', '24:BE:05': 'HP',
  '28:92:4A': 'HP', '2C:23:3A': 'HP', '2C:27:D7': 'HP', '2C:44:FD': 'HP',
  '30:8D:99': 'HP', '34:64:A9': 'HP', '38:EA:A7': 'HP', '3C:52:82': 'HP',
  '40:B0:34': 'HP', '40:F2:01': 'HP', '44:39:C4': 'HP', '48:0F:CF': 'HP',
  '4C:39:09': 'HP', '50:65:F3': 'HP', '58:20:B1': 'HP', '5C:B9:01': 'HP',
  '60:EB:69': 'HP', '64:51:06': 'HP', '68:B5:99': 'HP', '6C:3B:E5': 'HP',
  '70:5A:0F': 'HP', '74:46:A0': 'HP', '78:48:59': 'HP', '80:C1:6E': 'HP',
  '84:34:97': 'HP', '88:51:FB': 'HP', '8C:DC:D4': 'HP', '90:1B:0E': 'HP',
  '98:4B:E1': 'HP', '9C:8E:99': 'HP', 'A0:B3:CC': 'HP', 'A4:5D:36': 'HP',
  'A8:BD:27': 'HP', 'AC:16:2D': 'HP', 'B0:5A:DA': 'HP', 'B4:99:BA': 'HP',
  'B8:AF:67': 'HP', 'BC:EA:FA': 'HP', 'C0:3F:D5': 'HP', 'C4:34:6B': 'HP',
  'C4:65:16': 'HP', 'C8:CB:9E': 'HP', 'CC:3E:5F': 'HP', 'D0:7E:28': 'HP',
  'D8:D3:85': 'HP', 'DC:4A:3E': 'HP', 'E0:07:1B': 'HP', 'E8:39:35': 'HP',
  'EC:B1:D7': 'HP', 'F4:CE:46': 'HP', 'F8:B1:56': 'HP',
  // HP Printer
  '00:60:B0': 'HP Printer', 'AC:CE:8F': 'HP Printer',
  // Huawei
  '50:32:37': 'Huawei', '54:89:98': 'Huawei', '00:18:82': 'Huawei', '28:6E:D4': 'Huawei',
  '70:72:CF': 'Huawei', '00:E0:FC': 'Huawei', '04:02:1F': 'Huawei', '08:19:A6': 'Huawei',
  '0C:37:DC': 'Huawei', '10:47:80': 'Huawei', '14:9D:09': 'Huawei', '18:C5:8A': 'Huawei',
  '1C:8E:5C': 'Huawei', '20:08:ED': 'Huawei', '20:2B:C1': 'Huawei', '24:DF:6A': 'Huawei',
  '28:31:52': 'Huawei', '2C:9D:1E': 'Huawei', '30:D1:7E': 'Huawei', '34:6B:D3': 'Huawei',
  '38:37:8B': 'Huawei', '3C:47:11': 'Huawei', '40:4D:8E': 'Huawei', '48:00:31': 'Huawei',
  '48:4D:FE': 'Huawei', '4C:1F:CC': 'Huawei', '50:01:D9': 'Huawei', '54:51:1B': 'Huawei',
  '58:25:75': 'Huawei', '5C:C3:07': 'Huawei', '64:16:F0': 'Huawei', '68:A0:F6': 'Huawei',
  '6C:8D:C1': 'Huawei', '70:7B:E8': 'Huawei', '74:A0:63': 'Huawei', '78:1D:BA': 'Huawei',
  '78:F5:FD': 'Huawei', '7C:A2:3E': 'Huawei', '80:38:BC': 'Huawei', '84:5B:12': 'Huawei',
  '88:E3:AB': 'Huawei', '90:17:AC': 'Huawei', '94:04:9C': 'Huawei', '9C:28:EF': 'Huawei',
  'A4:99:47': 'Huawei', 'A8:CA:7B': 'Huawei', 'AC:E2:15': 'Huawei', 'B4:15:13': 'Huawei',
  'B8:08:D7': 'Huawei', 'BC:76:70': 'Huawei', 'C4:07:2F': 'Huawei', 'C8:51:95': 'Huawei',
  'CC:A2:23': 'Huawei', 'D0:65:CA': 'Huawei', 'D4:12:43': 'Huawei', 'D4:6A:A8': 'Huawei',
  'D8:C7:71': 'Huawei', 'DC:D2:FC': 'Huawei', 'E0:19:1D': 'Huawei', 'E4:A8:DF': 'Huawei',
  'E8:CD:2D': 'Huawei', 'EC:23:3D': 'Huawei', 'F0:1D:BC': 'Huawei', 'F4:4C:7F': 'Huawei',
  'F8:3D:FF': 'Huawei', 'FC:48:EF': 'Huawei',
  // Hyper-V
  '00:15:5D': 'Hyper-V',
  // Intel
  'D4:3D:7E': 'Intel', '94:65:9C': 'Intel', '00:21:6A': 'Intel', 'B4:96:91': 'Intel',
  '8C:8D:28': 'Intel', '8C:EC:4B': 'Intel', '00:1B:21': 'Intel', 'A0:36:9F': 'Intel',
  '00:02:B3': 'Intel', '00:03:47': 'Intel', '00:0E:35': 'Intel', '00:12:F0': 'Intel',
  '00:13:02': 'Intel', '00:13:20': 'Intel', '00:13:CE': 'Intel', '00:13:E8': 'Intel',
  '00:15:00': 'Intel', '00:16:76': 'Intel', '00:16:EA': 'Intel', '00:16:EB': 'Intel',
  '00:18:DE': 'Intel', '00:19:D1': 'Intel', '00:19:D2': 'Intel', '00:1B:77': 'Intel',
  '00:1C:BF': 'Intel', '00:1D:E0': 'Intel', '00:1E:64': 'Intel', '00:1E:65': 'Intel',
  '00:1F:3B': 'Intel', '00:1F:3C': 'Intel', '00:21:5C': 'Intel', '00:21:5D': 'Intel',
  '00:22:FB': 'Intel', '00:23:14': 'Intel', '00:24:D7': 'Intel', '00:27:10': 'Intel',
  '24:77:03': 'Intel', '28:D2:44': 'Intel', '34:02:86': 'Intel', '34:13:E8': 'Intel',
  '38:59:F9': 'Intel', '3C:A9:F4': 'Intel', '40:25:C2': 'Intel', '40:A8:F0': 'Intel',
  '44:85:00': 'Intel', '48:45:20': 'Intel', '4C:EB:42': 'Intel', '54:27:1E': 'Intel',
  '54:35:30': 'Intel', '5C:51:4F': 'Intel', '5C:F9:38': 'Intel', '60:67:20': 'Intel',
  '60:6C:66': 'Intel', '60:F6:77': 'Intel', '64:80:99': 'Intel', '68:05:CA': 'Intel',
  '6C:29:95': 'Intel', '6C:88:14': 'Intel', '70:1A:04': 'Intel', '78:92:9C': 'Intel',
  '7C:5C:F8': 'Intel', '80:19:34': 'Intel', '84:3A:4B': 'Intel', '84:EF:18': 'Intel',
  '88:53:2E': 'Intel', '8C:70:5A': 'Intel', '90:48:9A': 'Intel', '90:E2:BA': 'Intel',
  '98:4F:EE': 'Intel', 'A0:88:B4': 'Intel', 'A4:C3:F0': 'Intel', 'A8:6B:AD': 'Intel',
  'AC:72:89': 'Intel', 'B8:03:05': 'Intel', 'BC:77:37': 'Intel', 'C0:CB:38': 'Intel',
  'C4:85:08': 'Intel', 'C8:F7:33': 'Intel', 'CC:3D:82': 'Intel', 'D0:37:45': 'Intel',
  'D0:57:7B': 'Intel', 'D4:25:8B': 'Intel', 'D4:3B:04': 'Intel', 'D4:6D:50': 'Intel',
  'D4:BE:D9': 'Intel', 'D8:D4:3C': 'Intel', 'DC:53:60': 'Intel', 'E0:94:67': 'Intel',
  'E4:70:B8': 'Intel', 'E8:B4:70': 'Intel', 'F0:76:1C': 'Intel', 'F4:8E:38': 'Intel',
  'FC:77:74': 'Intel',
  // Juniper
  '00:05:85': 'Juniper', '00:10:DB': 'Juniper', '00:12:1E': 'Juniper', '00:14:F6': 'Juniper',
  '00:17:CB': 'Juniper', '00:19:E2': 'Juniper', '00:1B:C0': 'Juniper', '00:1F:12': 'Juniper',
  '00:21:59': 'Juniper', '00:22:83': 'Juniper', '00:23:9C': 'Juniper', '00:24:DC': 'Juniper',
  '00:26:88': 'Juniper', '28:C0:DA': 'Juniper', '2C:6B:F5': 'Juniper', '3C:61:04': 'Juniper',
  '40:B4:F0': 'Juniper', '48:0B:B2': 'Juniper', '5C:5E:AB': 'Juniper', '6C:9C:ED': 'Juniper',
  '78:FE:3D': 'Juniper', '84:18:88': 'Juniper', '88:A2:5E': 'Juniper', '9C:8E:CD': 'Juniper',
  'B0:C6:9A': 'Juniper', 'C4:02:89': 'Juniper', 'D4:20:B0': 'Juniper', 'F4:A7:39': 'Juniper',
  // Lenovo
  '00:21:CC': 'Lenovo', '54:EE:75': 'Lenovo', 'F8:16:54': 'Lenovo', '00:09:6B': 'Lenovo',
  '00:0A:E4': 'Lenovo', '08:00:37': 'Lenovo', '0C:8D:DB': 'Lenovo', '18:56:80': 'Lenovo',
  '1C:1B:0D': 'Lenovo', '24:4B:FE': 'Lenovo', '40:01:7A': 'Lenovo', '48:5B:39': 'Lenovo',
  '50:50:27': 'Lenovo', '5C:F3:70': 'Lenovo', '6C:40:08': 'Lenovo', '70:5A:B6': 'Lenovo',
  '74:27:EA': 'Lenovo', '74:4A:A4': 'Lenovo', '78:2B:CB': 'Lenovo', '7C:7A:91': 'Lenovo',
  '80:FA:5B': 'Lenovo', '84:39:BE': 'Lenovo', '98:61:0C': 'Lenovo', '9C:72:B9': 'Lenovo',
  'A0:A4:C5': 'Lenovo', 'AC:B5:7D': 'Lenovo', 'B0:37:AC': 'Lenovo', 'B4:6D:83': 'Lenovo',
  'BC:5F:F4': 'Lenovo', 'C4:BE:84': 'Lenovo', 'C8:5B:76': 'Lenovo', 'CC:F9:54': 'Lenovo',
  'D4:81:D7': 'Lenovo', 'DC:0E:A1': 'Lenovo', 'F0:DE:F1': 'Lenovo',
  // LG
  'C8:08:E9': 'LG', '00:E0:91': 'LG', '00:1C:62': 'LG', '10:68:3F': 'LG',
  '18:46:AC': 'LG', '1C:08:E3': 'LG', '20:16:D8': 'LG', '34:FC:EF': 'LG',
  '38:8C:50': 'LG', '48:25:67': 'LG', '58:D5:6E': 'LG', '60:AB:14': 'LG',
  '64:BC:0C': 'LG', '78:29:ED': 'LG', '90:25:AA': 'LG', 'A4:46:59': 'LG',
  'B4:E6:2A': 'LG', 'BC:B1:F3': 'LG', 'C4:4E:AC': 'LG', 'CC:FA:00': 'LG',
  'D0:13:FD': 'LG',
  // Linksys
  '00:04:20': 'Linksys', '00:06:25': 'Linksys', '00:0F:66': 'Linksys', '00:22:6B': 'Linksys',
  '00:14:BF': 'Linksys', '00:16:B6': 'Linksys', '00:18:39': 'Linksys', '00:1A:70': 'Linksys',
  '00:1D:7E': 'Linksys', '00:1E:E5': 'Linksys', '00:21:29': 'Linksys', '14:35:8B': 'Linksys',
  '20:AA:4B': 'Linksys', '60:33:4B': 'Linksys', 'C0:56:27': 'Linksys', 'C4:41:1E': 'Linksys',
  // Microsoft
  '8C:56:C5': 'Microsoft', '00:0D:3A': 'Microsoft', '00:50:F2': 'Microsoft', '28:18:78': 'Microsoft',
  '00:17:FA': 'Microsoft', '00:1D:D8': 'Microsoft', '7C:1E:52': 'Microsoft', '48:50:73': 'Microsoft',
  '70:66:55': 'Microsoft', '7C:ED:8D': 'Microsoft', '98:5F:D3': 'Microsoft', 'C4:9D:ED': 'Microsoft',
  // Microsoft Virtual
  '00:03:FF': 'Microsoft Virtual',
  // MikroTik
  '00:0C:42': 'MikroTik', '2C:C8:1B': 'MikroTik', '4C:5E:0C': 'MikroTik', '6C:3B:6B': 'MikroTik',
  '74:4D:28': 'MikroTik', '78:9A:18': 'MikroTik', 'B8:69:F4': 'MikroTik', 'CC:2D:E0': 'MikroTik',
  'D4:CA:6D': 'MikroTik', 'DC:2C:6E': 'MikroTik', 'E4:8D:8C': 'MikroTik',
  // Netgear
  '00:23:69': 'Netgear', 'C0:FF:D4': 'Netgear', '28:C6:8E': 'Netgear', '00:26:F2': 'Netgear',
  'A0:40:A0': 'Netgear', '00:09:5B': 'Netgear', '00:0F:B5': 'Netgear', '00:14:6C': 'Netgear',
  '00:18:4D': 'Netgear', '00:1B:2F': 'Netgear', '00:1E:2A': 'Netgear', '00:1F:33': 'Netgear',
  '00:22:3F': 'Netgear', '00:24:B2': 'Netgear', '10:0C:6B': 'Netgear', '20:0C:C8': 'Netgear',
  '20:4E:7F': 'Netgear', '2C:B0:5D': 'Netgear', '30:46:9A': 'Netgear', '44:94:FC': 'Netgear',
  '4C:60:DE': 'Netgear', '84:1B:5E': 'Netgear', '9C:D3:6D': 'Netgear', 'A0:04:60': 'Netgear',
  'B0:39:56': 'Netgear', 'C0:3F:0E': 'Netgear', 'C4:04:15': 'Netgear', 'CC:40:D0': 'Netgear',
  'E0:46:9A': 'Netgear', 'E4:F4:C6': 'Netgear',
  // Nintendo
  '00:17:AB': 'Nintendo', '98:B6:E9': 'Nintendo', '00:09:BF': 'Nintendo', '00:16:56': 'Nintendo',
  '00:1E:A9': 'Nintendo', '00:1F:C5': 'Nintendo', '00:21:47': 'Nintendo', '00:22:4C': 'Nintendo',
  '00:23:CC': 'Nintendo', '00:24:44': 'Nintendo', '00:24:F3': 'Nintendo', '34:AF:2C': 'Nintendo',
  '40:D2:8A': 'Nintendo', '58:BD:A3': 'Nintendo', '78:A2:A0': 'Nintendo', 'A4:C0:E1': 'Nintendo',
  'CC:FB:65': 'Nintendo', 'E0:0C:7F': 'Nintendo', 'E8:4E:CE': 'Nintendo',
  // OnePlus
  '40:45:DA': 'OnePlus', '4C:49:E3': 'OnePlus',
  // OPPO
  '78:39:AD': 'OPPO', 'A4:C3:90': 'OPPO', 'E8:BB:A8': 'OPPO',
  // Palo Alto
  '00:1B:17': 'Palo Alto', '0C:4E:36': 'Palo Alto', '40:2A:0C': 'Palo Alto',
  // Parallels
  '00:1C:42': 'Parallels',
  // QEMU/KVM
  '52:54:00': 'QEMU/KVM',
  // QNAP
  '00:08:9B': 'QNAP', '08:9B:4B': 'QNAP',
  // Raspberry Pi
  'B8:27:EB': 'Raspberry Pi', 'DC:A6:32': 'Raspberry Pi', 'E4:5F:01': 'Raspberry Pi', '28:CD:C1': 'Raspberry Pi',
  'D8:3A:DD': 'Raspberry Pi', 'BC:24:11': 'Raspberry Pi', '2C:CF:67': 'Raspberry Pi',
  // Realtek
  '00:E0:4C': 'Realtek', 'DC:9F:DB': 'Realtek', 'B8:AE:ED': 'Realtek', 'D0:17:C2': 'Realtek',
  '40:B0:76': 'Realtek', '54:04:A6': 'Realtek',
  // Ruckus
  '00:13:92': 'Ruckus', '18:9A:05': 'Ruckus', '2C:E6:CC': 'Ruckus', '34:FC:B9': 'Ruckus',
  '40:99:A0': 'Ruckus', '4C:2C:03': 'Ruckus', '58:93:96': 'Ruckus', '60:D0:2C': 'Ruckus',
  '7C:2E:BD': 'Ruckus', '80:73:67': 'Ruckus', '94:9D:A5': 'Ruckus', 'A8:37:43': 'Ruckus',
  'D4:68:4D': 'Ruckus', 'F4:CF:A2': 'Ruckus',
  // Samsung
  'F4:0F:24': 'Samsung', '00:12:47': 'Samsung', '8C:77:12': 'Samsung', '18:67:B0': 'Samsung',
  '2C:AE:2B': 'Samsung', '90:B7:90': 'Samsung', 'E8:50:8B': 'Samsung', '40:0E:85': 'Samsung',
  'A0:82:1F': 'Samsung', '5C:E8:EB': 'Samsung', '8C:C8:CD': 'Samsung', 'A8:06:00': 'Samsung',
  'CC:07:AB': 'Samsung', 'EC:9B:F3': 'Samsung', 'F4:42:8F': 'Samsung', '00:00:F0': 'Samsung',
  '00:02:78': 'Samsung', '00:07:AB': 'Samsung', '00:09:18': 'Samsung', '00:12:FB': 'Samsung',
  '1C:62:B8': 'Samsung', '20:64:32': 'Samsung', '24:4B:03': 'Samsung', '28:BA:B5': 'Samsung',
  '30:07:4D': 'Samsung', '34:AA:8B': 'Samsung', '38:AA:3C': 'Samsung', '3C:8B:FE': 'Samsung',
  '50:01:BB': 'Samsung', '54:88:0E': 'Samsung', '58:EF:68': 'Samsung', '60:A1:0A': 'Samsung',
  '6C:B7:F4': 'Samsung', '70:F9:27': 'Samsung', '74:45:8A': 'Samsung', '78:1F:DB': 'Samsung',
  '84:25:DB': 'Samsung', '88:32:9B': 'Samsung', '8C:71:F8': 'Samsung', '94:35:0A': 'Samsung',
  '94:63:D1': 'Samsung', '9C:02:98': 'Samsung', 'A8:7C:01': 'Samsung', 'B0:72:BF': 'Samsung',
  'B4:3A:28': 'Samsung', 'B8:5E:7B': 'Samsung', 'BC:85:1F': 'Samsung', 'C4:57:6E': 'Samsung',
  'C4:88:E5': 'Samsung', 'CC:05:1B': 'Samsung', 'D0:22:BE': 'Samsung', 'D4:E8:B2': 'Samsung',
  // Sony
  'A0:39:F7': 'Sony', '00:1A:80': 'Sony', '54:42:49': 'Sony', '00:13:A9': 'Sony',
  '00:1D:0D': 'Sony', '00:23:06': 'Sony', '00:24:BE': 'Sony', '30:17:C8': 'Sony',
  '3C:62:00': 'Sony', '40:B8:37': 'Sony', '5C:99:60': 'Sony', '70:2F:13': 'Sony',
  '78:84:3C': 'Sony', 'AC:9B:0A': 'Sony', 'D4:A2:1D': 'Sony', 'F0:BF:97': 'Sony',
  // Synology
  '00:11:32': 'Synology', '00:12:13': 'Synology', '00:25:53': 'Synology', '14:8C:09': 'Synology',
  '18:C0:4D': 'Synology', '24:5E:BE': 'Synology', '30:4A:EA': 'Synology', '3C:2A:F4': 'Synology',
  '90:09:D0': 'Synology', 'A4:BB:6D': 'Synology',
  // TP-Link
  'E8:9F:80': 'TP-Link', '50:C7:BF': 'TP-Link', 'AC:84:C6': 'TP-Link', 'C0:25:E9': 'TP-Link',
  '14:CC:20': 'TP-Link', 'B0:95:75': 'TP-Link', '08:2E:5F': 'TP-Link', 'A0:F3:C1': 'TP-Link',
  '18:A6:F7': 'TP-Link', '98:48:27': 'TP-Link', '90:9A:4A': 'TP-Link', '10:FE:ED': 'TP-Link',
  '00:0A:EB': 'TP-Link', '00:1D:0F': 'TP-Link', '00:23:CD': 'TP-Link', '00:27:19': 'TP-Link',
  '14:91:82': 'TP-Link', '1C:3B:F3': 'TP-Link', '20:DC:E6': 'TP-Link', '24:69:68': 'TP-Link',
  '28:28:5D': 'TP-Link', '2C:D0:5A': 'TP-Link', '30:DE:4B': 'TP-Link', '38:94:ED': 'TP-Link',
  '3C:46:D8': 'TP-Link', '40:16:9F': 'TP-Link', '44:33:4C': 'TP-Link', '48:8B:0A': 'TP-Link',
  '4C:09:B4': 'TP-Link', '50:3E:AA': 'TP-Link', '54:C8:0F': 'TP-Link', '60:32:B1': 'TP-Link',
  '64:70:02': 'TP-Link', '6C:5A:B0': 'TP-Link', '6C:B0:CE': 'TP-Link', '70:4F:57': 'TP-Link',
  '74:EA:3A': 'TP-Link', '78:44:76': 'TP-Link', '7C:8B:CA': 'TP-Link', '80:8F:1D': 'TP-Link',
  '84:16:F9': 'TP-Link', '84:D8:1B': 'TP-Link', '88:D7:F6': 'TP-Link', '8C:21:0A': 'TP-Link',
  '90:F6:52': 'TP-Link', '94:D9:B3': 'TP-Link', '98:DA:C4': 'TP-Link', '9C:21:6A': 'TP-Link',
  'A4:2B:B0': 'TP-Link', 'B0:4E:26': 'TP-Link', 'B4:B0:24': 'TP-Link', 'BC:46:99': 'TP-Link',
  'C4:6E:1F': 'TP-Link', 'C8:D3:A3': 'TP-Link', 'D8:07:B6': 'TP-Link', 'DC:FE:18': 'TP-Link',
  'E0:05:C5': 'TP-Link', 'E4:D0:D8': 'TP-Link', 'E8:DE:27': 'TP-Link', 'EC:08:6B': 'TP-Link',
  'F4:EC:38': 'TP-Link', 'F8:1A:67': 'TP-Link', 'FC:D7:33': 'TP-Link',
  // Ubiquiti
  '80:2A:A8': 'Ubiquiti', '78:8A:20': 'Ubiquiti', '24:A4:3C': 'Ubiquiti', 'B4:FB:E4': 'Ubiquiti',
  'F0:9F:C2': 'Ubiquiti', '00:15:6D': 'Ubiquiti', '00:27:22': 'Ubiquiti', '04:18:D6': 'Ubiquiti',
  '0A:18:D6': 'Ubiquiti', '18:E8:29': 'Ubiquiti', '1C:87:2C': 'Ubiquiti', '24:5A:4C': 'Ubiquiti',
  '44:D9:E7': 'Ubiquiti', '60:22:32': 'Ubiquiti', '68:72:51': 'Ubiquiti', '6A:18:D6': 'Ubiquiti',
  '74:83:C2': 'Ubiquiti', '9C:05:D6': 'Ubiquiti', 'AC:8B:A9': 'Ubiquiti', 'E0:63:DA': 'Ubiquiti',
  'F4:E2:C6': 'Ubiquiti', 'FC:EC:DA': 'Ubiquiti',
  // VirtualBox
  '08:00:27': 'VirtualBox',
  // VMware
  '00:50:56': 'VMware', '00:0C:29': 'VMware', '00:05:69': 'VMware', '00:1C:14': 'VMware',
  // Xen
  '00:16:3E': 'Xen',
  // Xerox
  '00:00:8E': 'Xerox', '00:00:AA': 'Xerox',
  // Xiaomi
  'CC:32:E5': 'Xiaomi', '00:9E:C8': 'Xiaomi', '28:6C:07': 'Xiaomi', 'F8:A2:D6': 'Xiaomi',
  '64:09:80': 'Xiaomi', '04:CF:8C': 'Xiaomi', '0C:1D:AF': 'Xiaomi', '10:2A:B3': 'Xiaomi',
  '18:59:36': 'Xiaomi', '20:82:C0': 'Xiaomi', '28:E3:1F': 'Xiaomi', '34:CE:94': 'Xiaomi',
  '38:A4:ED': 'Xiaomi', '50:64:2B': 'Xiaomi', '58:44:98': 'Xiaomi', '64:B4:73': 'Xiaomi',
  '68:DF:DD': 'Xiaomi', '78:11:DC': 'Xiaomi', '7C:1D:D9': 'Xiaomi', '8C:BE:BE': 'Xiaomi',
  '94:FB:B2': 'Xiaomi', 'AC:C1:EE': 'Xiaomi', 'B0:E2:35': 'Xiaomi', 'C4:0B:CB': 'Xiaomi',
  'D4:97:0B': 'Xiaomi',
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

  /// Ping a single IP â€” returns latency in ms or null if unreachable.
  /// On Windows uses ICMP ping for accuracy; falls back to TCP probes.
  static Future<double?> pingDevice(String ip,
      {Duration timeout = const Duration(milliseconds: 600)}) async {
    // Windows: use system ping (ICMP) â€” most accurate & fast
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

  /// Scan the entire subnet â€” yields devices as found
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

    // Scan in batches â€” keep to 24 to avoid exhausting process handles
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
          final lastOctet = ip.split('.').last;
          String name;
          if (manufacturer != null) {
            var type = deviceTypeFromManufacturer(manufacturer);
            if (manufacturer.toLowerCase().contains('apple')) {
              type = refineAppleType(identity.hostname);
            }
            name = '$type ($lastOctet)';
          } else if (identity.hostname != null && identity.hostname!.isNotEmpty) {
            name = '${identity.hostname} ($lastOctet)';
          } else {
            name = _guessDeviceName(ip);
          }
          return Device(
            id: ip,
            name: name,
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
    if (lastOctet == '1' || lastOctet == '254') return 'Gateway / Router';
    return 'Unknown ($lastOctet)';
  }

  /// Map a manufacturer name to a human-readable device type label
  static String deviceTypeFromManufacturer(String? mfr) {
    if (mfr == null) return '';
    final m = mfr.toLowerCase();
    // Apple â€” distinguish iPhone/iPad vs Mac by hostname hints if available,
    // but at manufacturer level just say "Apple Device"
    if (m.contains('randomized')) return 'Phone / Laptop (randomized MAC)';
    if (m.contains('apple')) return 'Apple Device';
    if (m.contains('samsung')) return 'Samsung Device';
    if (m.contains('google')) return 'Google Device';
    if (m.contains('xiaomi') || m.contains('poco') || m.contains('redmi')) return 'Xiaomi Device';
    if (m.contains('huawei') || m.contains('honor')) return 'Huawei Device';
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) return 'OPPO / OnePlus';
    if (m.contains('lg')) return 'LG Device';
    if (m.contains('sony')) return 'Sony Device';
    if (m.contains('microsoft')) return 'Windows PC';
    if (m.contains('dell')) return 'Dell PC';
    if (m.contains('hp') || m.contains('hewlett')) return 'HP PC';
    if (m.contains('lenovo') || m.contains('thinkpad')) return 'Lenovo PC';
    if (m.contains('asus')) return 'ASUS PC';
    if (m.contains('intel') || m.contains('realtek')) return 'PC / Laptop';
    if (m.contains('raspberry')) return 'Raspberry Pi';
    if (m.contains('vmware') || m.contains('parallels')) return 'Virtual Machine';
    if (m.contains('nintendo')) return 'Nintendo Console';
    if (m.contains('amazon')) return 'Amazon Device';
    if (m.contains('cisco')) return 'Cisco Device';
    if (m.contains('tp-link') || m.contains('tplink')) return 'TP-Link Router';
    if (m.contains('netgear')) return 'Netgear Router';
    if (m.contains('d-link') || m.contains('dlink')) return 'D-Link Router';
    if (m.contains('ubiquiti') || m.contains('ubnt')) return 'Ubiquiti Device';
    if (m.contains('mikrotik')) return 'MikroTik Router';
    if (m.contains('linksys')) return 'Linksys Router';
    if (m.contains('belkin')) return 'Belkin Router';
    if (m.contains('lenovo') || m.contains('thinkpad')) return 'Lenovo PC';
    if (m.contains('oneplus') || m.contains('oppo') || m.contains('realme')) return 'Android Phone';
    if (m.contains('realtek') || m.contains('liteon')) return 'PC / Laptop';
    if (m.contains('aruba')) return 'Aruba AP / Switch';
    if (m.contains('fortinet')) return 'Fortinet Firewall';
    if (m.contains('synology')) return 'Synology NAS';
    if (m.contains('qnap')) return 'QNAP NAS';
    if (m.contains('hikvision')) return 'Hikvision Camera';
    if (m.contains('dahua')) return 'Dahua Camera';
    if (m.contains('epson')) return 'Epson Printer';
    if (m.contains('brother')) return 'Brother Printer';
    if (m.contains('canon')) return 'Canon Printer';
    return mfr; // fallback: show raw manufacturer name
  }

  /// Refine Apple device type using hostname clues
  static String refineAppleType(String? hostname) {
    if (hostname == null) return 'Apple Device';
    final h = hostname.toLowerCase();
    if (h.contains('iphone')) return 'iPhone';
    if (h.contains('ipad')) return 'iPad';
    if (h.contains('macbook')) return 'MacBook';
    if (h.contains('imac')) return 'iMac';
    if (h.contains('mac-mini') || h.contains('macmini')) return 'Mac Mini';
    if (h.contains('appletv') || h.contains('apple-tv')) return 'Apple TV';
    if (h.contains('homepod')) return 'HomePod';
    if (h.contains('watch')) return 'Apple Watch';
    if (h.contains('mac')) return 'Mac';
    return 'Apple Device';
  }

  /// Get MAC address via ARP cache (desktop only â€” Android/iOS restrict MAC access)
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
    // Locally-administered bit (bit 1 of first octet) = randomized/private MAC
    final firstByte = int.tryParse(mac.substring(0, 2), radix: 16) ?? 0;
    if (firstByte & 0x02 != 0) return 'Randomized MAC';
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
