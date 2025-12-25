import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'websocket_service.dart';

class PnLService {
  static final PnLService _instance = PnLService._internal();
  factory PnLService() => _instance;
  PnLService._internal();

  final ApiService _apiService = ApiService();
  final WebSocketService _webSocketService = WebSocketService();

  final ValueNotifier<double> totalPnL = ValueNotifier<double>(0.0);
  final ValueNotifier<List<Map<String, dynamic>>> positions = ValueNotifier<List<Map<String, dynamic>>>([]);
  
  StreamSubscription? _wsSubscription;
  bool _isFetching = false;

  Future<void> fetchPositions() async {
    if (_isFetching) return;
    _isFetching = true;

    final String? uid = _apiService.userId;
    if (uid == null) {
      _isFetching = false;
      return;
    }

    final result = await _apiService.getPositionBook(userId: uid);
    if (result['stat'] == 'Ok' && result['positions'] != null) {
      final List<dynamic> posList = result['positions'];
      final List<Map<String, dynamic>> updatedPositions = posList.map((p) => Map<String, dynamic>.from(p)).toList();
      
      positions.value = updatedPositions;
      _subscribeToPositions(updatedPositions);
      _calculateTotalPnL();
    } else if (result['emsg']?.toString().toLowerCase().contains('no data') ?? false) {
      positions.value = [];
      totalPnL.value = 0.0;
    }
    
    _isFetching = false;
  }

  void _subscribeToPositions(List<Map<String, dynamic>> posList) {
    _wsSubscription?.cancel();
    
    for (var pos in posList) {
      final String exch = pos['exch'] ?? '';
      final String token = pos['token'] ?? '';
      if (exch.isNotEmpty && token.isNotEmpty) {
        _webSocketService.subscribeTouchline(exch, token);
      }
    }

    _wsSubscription = _webSocketService.messageStream.listen((data) {
      if (data['t'] == 't' || data['t'] == 'tf') {
        _updatePositionLTP(data);
      }
    });
  }

  void _updatePositionLTP(Map<String, dynamic> data) {
    final String? token = data['tk'];
    final String? lpStr = data['lp'];
    if (token == null || lpStr == null) return;

    final double newLtp = double.tryParse(lpStr) ?? 0.0;
    bool updated = false;

    final List<Map<String, dynamic>> currentPositions = List.from(positions.value);
    for (var i = 0; i < currentPositions.length; i++) {
      if (currentPositions[i]['token'] == token) {
        currentPositions[i]['lp'] = lpStr; // Store as string to match original format
        updated = true;
      }
    }

    if (updated) {
      positions.value = currentPositions;
      _calculateTotalPnL();
    }
  }

  void _calculateTotalPnL() {
    double total = 0.0;
    for (var pos in positions.value) {
      final double rpnl = double.tryParse(pos['rpnl']?.toString() ?? '0') ?? 0.0;
      final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0.0;
      final double lp = double.tryParse(pos['lp']?.toString() ?? '0') ?? 0.0;
      final double netavgprc = double.tryParse(pos['netavgprc']?.toString() ?? '0') ?? 0.0;
      final double prcftr = double.tryParse(pos['prcftr']?.toString() ?? '1') ?? 1.0;

      // urmtom = netqty * (lp - netavgprc) * prcftr
      final double urmtom = netqty * (lp - netavgprc) * prcftr;
      total += (rpnl + urmtom);
    }
    totalPnL.value = total;
  }

  void dispose() {
    _wsSubscription?.cancel();
  }
}
