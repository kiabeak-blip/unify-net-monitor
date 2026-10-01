// lib/services/license_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── License status ────────────────────────────────────────────────────────

enum LicenseStatus { trial, expired, active, forever }

class LicenseInfo {
  final LicenseStatus status;
  final int trialDaysLeft;   // only when status == trial
  final DateTime? expiresOn; // only when status == active
  final String? licenseKey;

  const LicenseInfo({
    required this.status,
    this.trialDaysLeft = 0,
    this.expiresOn,
    this.licenseKey,
  });

  bool get canUse =>
      status == LicenseStatus.trial ||
      status == LicenseStatus.active ||
      status == LicenseStatus.forever;
}

// ─── License service ───────────────────────────────────────────────────────

class LicenseService {
  static const _trialDays = 60;
  static const _firstLaunchKey = 'unm_first_launch';
  static const _licenseKey     = 'unm_license_key';

  // Secret used to validate/generate codes — keep this private
  static const _secret = 'UNM-UNIFY-NET-MONITOR-2024-SECRET';

  // ── Check current status ──────────────────────────────────────────────

  static Future<LicenseInfo> check() async {
    final prefs = await SharedPreferences.getInstance();

    // Record first launch
    if (!prefs.containsKey(_firstLaunchKey)) {
      await prefs.setString(
          _firstLaunchKey, DateTime.now().toIso8601String());
    }

    // Check stored license key
    final stored = prefs.getString(_licenseKey);
    if (stored != null) {
      final result = _validate(stored);
      if (result != null) return result;
      // Invalid key — clear it
      await prefs.remove(_licenseKey);
    }

    // Trial check
    final firstStr = prefs.getString(_firstLaunchKey)!;
    final first = DateTime.parse(firstStr);
    final daysPassed = DateTime.now().difference(first).inDays;
    final daysLeft = _trialDays - daysPassed;

    if (daysLeft > 0) {
      return LicenseInfo(
          status: LicenseStatus.trial, trialDaysLeft: daysLeft);
    }
    return const LicenseInfo(status: LicenseStatus.expired);
  }

  // ── Activate a license key ────────────────────────────────────────────

  static Future<({bool ok, String message, LicenseInfo? info})> activate(
      String rawKey) async {
    final key = rawKey.trim().toUpperCase();
    final result = _validate(key);
    if (result == null) {
      return (ok: false, message: 'Invalid license key. Please check and try again.', info: null);
    }
    if (result.status == LicenseStatus.active && result.expiresOn != null &&
        result.expiresOn!.isBefore(DateTime.now())) {
      return (ok: false, message: 'This license key has already expired.', info: null);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKey, key);
    return (ok: true, message: 'License activated successfully!', info: result);
  }

  // ── Validate key format & signature ──────────────────────────────────
  // Format: UNM-YYYYMMDD-XXXXXX
  //   YYYYMMDD = expiry date  |  99991231 = lifetime
  //   XXXXXX   = first 6 chars of HMAC-SHA256(_secret + ':' + YYYYMMDD)

  static LicenseInfo? _validate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    if (parts[0] != 'UNM') return null;

    final datePart = parts[1];
    final sigPart  = parts[2];

    if (datePart.length != 8) return null;
    if (sigPart.length < 6)   return null;

    // Verify signature
    final expected = _hmac('$_secret:$datePart');
    if (sigPart != expected) return null;

    // Parse expiry
    if (datePart == '99991231') {
      return LicenseInfo(
          status: LicenseStatus.forever, licenseKey: key);
    }

    try {
      final year  = int.parse(datePart.substring(0, 4));
      final month = int.parse(datePart.substring(4, 6));
      final day   = int.parse(datePart.substring(6, 8));
      final expiry = DateTime(year, month, day, 23, 59, 59);

      if (expiry.isBefore(DateTime.now())) {
        return LicenseInfo(
            status: LicenseStatus.expired, licenseKey: key);
      }
      return LicenseInfo(
          status: LicenseStatus.active,
          expiresOn: expiry,
          licenseKey: key);
    } catch (_) {
      return null;
    }
  }

  // ── HMAC helper ───────────────────────────────────────────────────────

  static String _hmac(String data) {
    final key   = utf8.encode(_secret);
    final bytes = utf8.encode(data);
    final hmac  = Hmac(sha256, key);
    final digest = hmac.convert(bytes).toString().toUpperCase();
    return digest.substring(0, 6);
  }

  // ── Key generator (for owner use) ─────────────────────────────────────
  // Call this to generate valid keys to give to users.

  static String generateKey({DateTime? expiry}) {
    final datePart = expiry == null
        ? '99991231'
        : '${expiry.year.toString().padLeft(4, '0')}'
          '${expiry.month.toString().padLeft(2, '0')}'
          '${expiry.day.toString().padLeft(2, '0')}';
    final sig = _hmac('$_secret:$datePart');
    return 'UNM-$datePart-$sig';
  }
}
