import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  String? _userToken;
  String? get userToken => _userToken;

  static String sha256Hash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> quickAuth({
    required String userId,
    required String password,
    required String totp,
    required String vendorCode,
    required String apiKey,
    required String imei,
  }) async {
    final String pwdHash = sha256Hash(password);
    final String appKeyHash = sha256Hash('$userId|$apiKey');

    final Map<String, dynamic> jData = {
      'apkversion': ApiConstants.apkVersion,
      'uid': userId,
      'pwd': pwdHash,
      'factor2': totp,
      'vc': vendorCode,
      'appkey': appKeyHash,
      'imei': imei,
      'source': ApiConstants.source,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.quickAuth}'),
        body: 'jData=${jsonEncode(jData)}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['stat'] == 'Ok') {
          _userToken = data['usertoken'];
        }
        return data;
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }
}
