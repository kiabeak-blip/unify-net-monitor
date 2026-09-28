# NetWatch — Network Device Monitor

A Flutter mobile app that scans your local network, monitors device connectivity, shows ping latency and open ports, and sends push notifications when devices go down.

---

## Features

- 🔍 **Auto Network Scan** — Discovers all active devices on your Wi-Fi subnet (192.168.x.1–254)
- ➕ **Manual Device Entry** — Add any device by IP address and name
- 📡 **Ping + Latency** — Real-time response time with quality ratings (Excellent / Good / Fair / Poor)
- 🔌 **Port Scanner** — Checks 10 common ports: SSH, HTTP, HTTPS, RDP, SMB, DNS, etc.
- 🔔 **Push Notifications** — Alerts when a device goes offline or comes back online
- 📈 **Latency History Chart** — Line chart showing last 10 latency readings per device
- ♻️ **Auto Refresh** — Configurable auto-check every 15s / 30s / 1m / 2m / 5m
- 💾 **Persistent Storage** — Device list survives app restarts

---

## Setup

### Prerequisites
- Flutter SDK 3.0+
- Android Studio or Xcode
- A physical device or emulator connected to Wi-Fi

### Installation

```bash
# 1. Clone / copy this project
cd network_monitor

# 2. Install dependencies
flutter pub get

# 3. Run on Android
flutter run

# 4. Run on iOS
open ios/Runner.xcworkspace  # then build in Xcode
flutter run
```

### Android
No extra setup needed. The app requests notification permission on first launch.

### iOS
In `ios/Runner/Info.plist`, add:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>NetWatch needs local network access to scan and monitor devices on your Wi-Fi.</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
</array>
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point + theme
├── models/
│   └── device.dart              # Device & PortInfo models
├── services/
│   ├── network_scanner.dart     # Ping + port scanning logic
│   ├── notification_service.dart # Push notifications
│   └── device_manager.dart      # State management (Provider)
├── screens/
│   ├── home_screen.dart         # Dashboard with device list
│   ├── device_detail_screen.dart # Per-device detail + chart
│   ├── add_device_screen.dart   # Manual IP entry form
│   └── settings_screen.dart     # Auto-refresh + preferences
└── widgets/
    ├── stat_card.dart           # Stats (Total/Online/Offline)
    ├── device_list_tile.dart    # Device row with status
    └── scan_progress_bar.dart   # Scan progress indicator
```

---

## How It Works

### Network Scanning
The scanner tries TCP connections to common ports (80, 443, 22, etc.) on each IP in the subnet range. If any port responds, the device is considered online and the TCP handshake time is used as latency.

### Port Detection
For each discovered device, the app checks 10 common ports concurrently:
- 22 (SSH), 23 (Telnet), 25 (SMTP), 53 (DNS)
- 80 (HTTP), 443 (HTTPS), 445 (SMB)
- 3389 (RDP), 8080 (HTTP Alt), 8443 (HTTPS Alt)

### Notifications
Uses `flutter_local_notifications`. Fires when:
- A previously-online device stops responding → "Device Offline" alert
- An offline device comes back → "Device Back Online" alert
- A full scan completes → summary notification

---

## Permissions Required

| Permission | Reason |
|------------|--------|
| `INTERNET` | Network communication |
| `ACCESS_WIFI_STATE` | Read local IP / subnet |
| `POST_NOTIFICATIONS` | Push alerts (Android 13+) |
| `WAKE_LOCK` | Background scanning |

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `network_info_plus` | Get local IP address |
| `flutter_local_notifications` | Push notifications |
| `provider` | State management |
| `shared_preferences` | Device persistence |
| `fl_chart` | Latency history chart |
| `permission_handler` | Runtime permissions |
