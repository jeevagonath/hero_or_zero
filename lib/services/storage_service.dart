import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyUserToken = 'usertoken';
  static const String _keyUid = 'uid';
  static const String _keyNiftyDay = 'nifty_day';
  static const String _keySensexDay = 'sensex_day';
  static const String _keyNiftyLotSize = 'nifty_lot_size';
  static const String _keySensexLotSize = 'sensex_lot_size';
  static const String _keyShowTestButton = 'show_test_button';
  static const String _keyVendorCode = 'dev_vendor_code';
  static const String _keyApiKey = 'dev_api_key';
  static const String _keyImei = 'dev_imei';
  static const String _keyStrategyTime = 'strategy_time';
  static const String _keyStrategy930CaptureTime = 'strategy_930_capture_time';
  static const String _keyStrategy930FetchTime = 'strategy_930_fetch_time';
  static const String _keyExitTime = 'exit_time';
  static const String _keyExitTriggerBuffer = 'exit_trigger_buffer';
  static const String _keyNiftyTrailingStep = 'nifty_trailing_step';
  static const String _keyNiftyTrailingIncrement = 'nifty_trailing_increment';
  static const String _keySensexTrailingStep = 'sensex_trailing_step';
  static const String _keySensexTrailingIncrement = 'sensex_trailing_increment';
  static const String _keyLoginDate = 'last_login_date';
  static const String _keyDevicePin = 'device_pin';

  Future<void> saveUserToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserToken, token);
    // Auto-save current date as login date
    final String today = DateTime.now().toString().split(' ')[0]; // yyyy-MM-dd
    await prefs.setString(_keyLoginDate, today);
  }

  Future<String?> getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserToken);
  }

  Future<String?> getLastLoginDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLoginDate);
  }

  Future<void> saveUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, uid);
  }

  Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUid);
  }

  Future<void> savePeakProfits(Map<String, double> profits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('peak_profits', jsonEncode(profits));
  }

  Future<Map<String, double>> getPeakProfits() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('peak_profits');
    if (data == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(data);
    return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  Future<void> clearPeakProfits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('peak_profits');
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserToken);
    // await prefs.remove(_keyUid); // Keep UID for Biometric Login / Remember Me
  }

  // Developer Settings
  Future<void> saveDevConfig({
    required String vendorCode,
    required String apiKey,
    required String imei,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVendorCode, vendorCode);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyImei, imei);
  }

  Future<Map<String, String>> getDevConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'vendorCode': prefs.getString(_keyVendorCode) ?? '',
      'apiKey': prefs.getString(_keyApiKey) ?? '',
      'imei': prefs.getString(_keyImei) ?? '',
    };
  }

  // Strategy Settings
  Future<void> saveStrategySettings({
    required String niftyDay,
    required String sensexDay,
    required int niftyLotSize,
    required int sensexLotSize,
    required String strategyTime,
    required String strategy930CaptureTime,
    required String strategy930FetchTime,
    required String exitTime,
    required double exitTriggerBuffer,
    required double niftyTrailingStep,
    required double niftyTrailingIncrement,
    required double sensexTrailingStep,
    required double sensexTrailingIncrement,
    required bool showTestButton,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNiftyDay, niftyDay);
    await prefs.setString(_keySensexDay, sensexDay);
    await prefs.setInt(_keyNiftyLotSize, niftyLotSize);
    await prefs.setInt(_keySensexLotSize, sensexLotSize);
    await prefs.setBool(_keyShowTestButton, showTestButton);
    await prefs.setString(_keyStrategyTime, strategyTime);
    await prefs.setString(_keyStrategy930CaptureTime, strategy930CaptureTime);
    await prefs.setString(_keyStrategy930FetchTime, strategy930FetchTime);
    await prefs.setString(_keyExitTime, exitTime);
    await prefs.setDouble(_keyExitTriggerBuffer, exitTriggerBuffer);
    await prefs.setDouble(_keyNiftyTrailingStep, niftyTrailingStep);
    await prefs.setDouble(_keyNiftyTrailingIncrement, niftyTrailingIncrement);
    await prefs.setDouble(_keySensexTrailingStep, sensexTrailingStep);
    await prefs.setDouble(_keySensexTrailingIncrement, sensexTrailingIncrement);
  }

  Future<Map<String, dynamic>> getStrategySettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'niftyDay': prefs.getString(_keyNiftyDay) ?? 'Tuesday',
      'sensexDay': prefs.getString(_keySensexDay) ?? 'Thursday',
      'niftyLotSize': prefs.getInt(_keyNiftyLotSize) ?? 25, // NIFTY Default
      'sensexLotSize': prefs.getInt(_keySensexLotSize) ?? 10, // SENSEX Default
      'showTestButton': prefs.getBool(_keyShowTestButton) ?? true,
      'strategyTime': prefs.getString(_keyStrategyTime) ?? '13:15',
      'strategy930CaptureTime': prefs.getString(_keyStrategy930CaptureTime) ?? '09:25',
      'strategy930FetchTime': prefs.getString(_keyStrategy930FetchTime) ?? '09:30',
      'exitTime': prefs.getString(_keyExitTime) ?? '15:00',
      'exitTriggerBuffer': prefs.getDouble(_keyExitTriggerBuffer) ?? 0.5,
      'niftyTrailingStep': prefs.getDouble(_keyNiftyTrailingStep) ?? 10.0,
      'niftyTrailingIncrement': prefs.getDouble(_keyNiftyTrailingIncrement) ?? 8.0,
      'sensexTrailingStep': prefs.getDouble(_keySensexTrailingStep) ?? 20.0,
      'sensexTrailingIncrement': prefs.getDouble(_keySensexTrailingIncrement) ?? 15.0,
    };
  }
  // Daily Strategy Capture (Persistence)
  Future<void> saveDailyCapture(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_strategy_capture', jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getDailyCapture() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('daily_strategy_capture');
    if (data == null) return null;
    return jsonDecode(data);
  }

  Future<void> clearDailyCapture() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('daily_strategy_capture');
  }

  // Strategy 930 Persistence
  Future<void> saveStrategy930Data(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('strategy_930_data', jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getStrategy930Data() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('strategy_930_data');
    if (data == null) return null;
    return jsonDecode(data);
  }

  Future<void> clearStrategy930Data() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('strategy_930_data');
  }

  // Device PIN for Biometrics
  Future<void> saveDevicePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDevicePin, pin);
  }

  Future<String?> getDevicePin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDevicePin);
  }

  Future<void> clearDevicePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDevicePin);
  }
}
