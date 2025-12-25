import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final StorageService _storageService = StorageService();
  String? _userToken;
  String? _userId;
  String? get userToken => _userToken;
  String? get userId => _userId;

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
          _userToken = data['susertoken'];
          if (_userToken != null) {
            await _storageService.saveUserToken(_userToken!);
            await _storageService.saveUid(userId);
          } else {
            return {'stat': 'Not_Ok', 'emsg': 'Login successful but usertoken missing'};
          }
        }
        return data;
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<void> initToken() async {
    _userToken = await _storageService.getUserToken();
    _userId = await _storageService.getUid();
  }

  Future<Map<String, dynamic>> searchScrip({
    required String userId,
    required String searchText,
  }) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'stext': searchText.replaceAll(' ', '%20'),
    };

    print('API Request: ${ApiConstants.baseUrl}${ApiConstants.searchScrip}');
    print('jData: ${jsonEncode(jData)}');
    print('jKey: $_userToken');

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.searchScrip}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getQuote({
    required String userId,
    required String exchange,
    required String token,
  }) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'exch': exchange,
      'token': token,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.getQuote}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('API Response for GetQuote: ${response.statusCode}');
      print('API Body for GetQuote: ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> placeOrder({
    required String userId,
    required String exchange,
    required String tradingSymbol,
    required String quantity,
    required String price,
    required String transactionType, // 'B' or 'S'
    required String productType, // 'C', 'M', 'I', 'H'
    required String orderType, // 'LMT', 'MKT', 'SL-LMT', 'SL-MKT'
    String? triggerPrice,
    String ret = 'DAY',
  }) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'actid': userId,
      'exch': exchange,
      'tsym': tradingSymbol,
      'qty': quantity,
      'prc': price,
      'trantype': transactionType,
      'prd': productType,
      'ret': ret,
      'prctyp': orderType,
      'ordersource': 'API',
    };

    if (triggerPrice != null) {
      jData['trgprc'] = triggerPrice;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.placeOrder}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPositionBook({required String userId}) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'actid': userId,
    };
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.positionBook}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return {'stat': 'Ok', 'positions': data};
        }
        return data as Map<String, dynamic>;
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getTradeBook({required String userId}) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'actid': userId,
    };
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tradeBook}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return {'stat': 'Ok', 'trades': data};
        }
        return data as Map<String, dynamic>;
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getOrderBook({required String userId}) async {
    final Map<String, dynamic> jData = {'uid': userId};
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.orderBook}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return {'stat': 'Ok', 'orders': data};
        }
        return data as Map<String, dynamic>;
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> squareOffPosition({
    required String userId,
    required Map<String, dynamic> position,
  }) async {
    final double netqty = double.tryParse(position['netqty']?.toString() ?? '0') ?? 0;
    if (netqty == 0) return {'stat': 'Not_Ok', 'emsg': 'Net quantity is zero'};

    final String transactionType = netqty > 0 ? 'S' : 'B';
    final String absQty = netqty.abs().toInt().toString();

    return placeOrder(
      userId: userId,
      exchange: position['exch'],
      tradingSymbol: position['tsym'],
      quantity: absQty,
      price: '0',
      transactionType: transactionType,
      productType: position['prd'],
      orderType: 'MKT',
    );
  }

  Future<Map<String, dynamic>> getHoldings({required String userId}) async {
    final Map<String, dynamic> jData = {'uid': userId, 'actid': userId};
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.holdings}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return {'stat': 'Ok', 'holdings': data};
        }
        return data as Map<String, dynamic>;
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUserDetails({required String userId}) async {
    final Map<String, dynamic> jData = {'uid': userId};
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userDetails}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addMultiScripsToMW({
    required String userId,
    required String scrips,
    String wlname = 'DEFAULT',
  }) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'wlname': wlname,
      'scrips': scrips,
    };
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.addMultiScripsToMW}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMultiMWScrips({
    required String userId,
    required String scrips,
    String wlname = 'DEFAULT',
  }) async {
    final Map<String, dynamic> jData = {
      'uid': userId,
      'wlname': wlname,
      'scrips': scrips,
    };
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deleteMultiMWScrips}'),
        body: 'jData=${jsonEncode(jData)}&jKey=${_userToken ?? ''}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'stat': 'Not_Ok', 'emsg': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'stat': 'Not_Ok', 'emsg': e.toString()};
    }
  }

  void clearSession() {
    _userToken = null;
    _userId = null;
  }
}
