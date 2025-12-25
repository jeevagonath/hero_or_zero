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

  Future<void> saveUserToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserToken, token);
  }

  Future<String?> getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserToken);
  }

  Future<void> saveUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, uid);
  }

  Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUid);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserToken);
    await prefs.remove(_keyUid);
    // Note: We DO NOT remove developer settings here as requested.
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
    required bool showTestButton,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNiftyDay, niftyDay);
    await prefs.setString(_keySensexDay, sensexDay);
    await prefs.setInt(_keyNiftyLotSize, niftyLotSize);
    await prefs.setInt(_keySensexLotSize, sensexLotSize);
    await prefs.setBool(_keyShowTestButton, showTestButton);
  }

  Future<Map<String, dynamic>> getStrategySettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'niftyDay': prefs.getString(_keyNiftyDay) ?? 'Tuesday',
      'sensexDay': prefs.getString(_keySensexDay) ?? 'Thursday',
      'niftyLotSize': prefs.getInt(_keyNiftyLotSize) ?? 25, // NIFTY Default
      'sensexLotSize': prefs.getInt(_keySensexLotSize) ?? 10, // SENSEX Default
      'showTestButton': prefs.getBool(_keyShowTestButton) ?? true,
    };
  }
}
