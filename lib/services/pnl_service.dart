import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'websocket_service.dart';
import 'storage_service.dart';

class PnLService {
  static final PnLService _instance = PnLService._internal();
  factory PnLService() => _instance;
  PnLService._internal() {
    _initFromStorage();
    _startExitMonitor();
  }

  final ApiService _apiService = ApiService();
  final WebSocketService _webSocketService = WebSocketService();
  final StorageService _storageService = StorageService();

  final ValueNotifier<double> totalPnL = ValueNotifier<double>(0.0);
  final ValueNotifier<List<Map<String, dynamic>>> positions = ValueNotifier<List<Map<String, dynamic>>>([]);
  
  // Track peak profit and TSL per token
  final ValueNotifier<Map<String, dynamic>> exitStatus = ValueNotifier<Map<String, dynamic>>({});
  Map<String, double> _persistentPeakProfits = {};

  Future<void> _initFromStorage() async {
    _persistentPeakProfits = await _storageService.getPeakProfits();
  }  
  StreamSubscription? _wsSubscription;
  bool _isFetching = false;
  Timer? _exitMonitorTimer;

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

    bool updated = false;
    final List<Map<String, dynamic>> currentPositions = List.from(positions.value);
    for (var i = 0; i < currentPositions.length; i++) {
      if (currentPositions[i]['token'] == token) {
        currentPositions[i]['lp'] = lpStr;
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
    final Map<String, dynamic> currentExitStatus = Map.from(exitStatus.value);

    for (var pos in positions.value) {
      final String token = pos['token'] ?? '';
      final double rpnl = double.tryParse(pos['rpnl']?.toString() ?? '0') ?? 0.0;
      final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0.0;
      final double lp = double.tryParse(pos['lp']?.toString() ?? '0') ?? 0.0;
      final double netavgprc = double.tryParse(pos['netavgprc']?.toString() ?? '0') ?? 0.0;
      final double prcftr = double.tryParse(pos['prcftr']?.toString() ?? '1') ?? 1.0;
      final double lotSize = double.tryParse(pos['ls']?.toString() ?? '1') ?? 1.0;

      final double urmtom = netqty * (lp - netavgprc) * prcftr;
      final double currentPnL = rpnl + urmtom;
      total += currentPnL;

      if (netqty != 0) {
        // Trailing SL Logic
        final double numLots = netqty.abs() / lotSize;
        final double pnlPerLot = currentPnL / numLots;

        var status = currentExitStatus[token] ?? {
          'tsym': pos['tsym'],
          'peakProfitPerLot': _persistentPeakProfits[token] ?? 0.0,
          'tslPerLot': -999999.0, // Indicated as not active
          'lots': numLots,
        };

        // Recalculate TSL from stored peak if not already set (e.g. after restart)
        if (status['tslPerLot'] == -999999.0 && status['peakProfitPerLot'] >= 200) {
            status['tslPerLot'] = status['peakProfitPerLot'] - 150;
        }

        if (pnlPerLot > (status['peakProfitPerLot'] ?? 0.0)) {
          status['peakProfitPerLot'] = pnlPerLot;
          _persistentPeakProfits[token] = pnlPerLot;
          _storageService.savePeakProfits(_persistentPeakProfits);
          
          // Update TSL if threshold ₹200 met
          if (pnlPerLot >= 200) {
            // TSL = PeakProfit - 150
            status['tslPerLot'] = pnlPerLot - 150;
          }
        }
        currentExitStatus[token] = status;

        // Auto-exit if TSL hit
        if (status['tslPerLot'] != -999999.0 && pnlPerLot <= status['tslPerLot']) {
          _autoSquareOff(pos, 'Trailing SL Hit');
        }
      }
    }
    totalPnL.value = total;
    exitStatus.value = currentExitStatus;
  }

  void _startExitMonitor() {
    _exitMonitorTimer?.cancel();
    _exitMonitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      // 3:00 PM Exit
      if (now.hour == 15 && now.minute == 0) {
        squareOffAll('Time-Based Exit (3:00 PM)');
      }
    });
  }

  Future<void> _autoSquareOff(Map<String, dynamic> position, String reason) async {
    final String token = position['token'] ?? '';
    // Prevent multiple triggers
    if (exitStatus.value[token]?['isExiting'] == true) return;

    final Map<String, dynamic> newStatus = Map.from(exitStatus.value);
    newStatus[token]['isExiting'] = true;
    exitStatus.value = newStatus;

    print('Auto Squaring Off ${position['tsym']} due to $reason');
    await _apiService.squareOffPosition(
      userId: _apiService.userId ?? '',
      position: position,
    );
    // Refresh positions after square-off
    await fetchPositions();
  }

  Future<void> squareOffAll([String reason = 'Manual Close All']) async {
    for (var pos in positions.value) {
      final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0;
      if (netqty != 0) {
        await _apiService.squareOffPosition(
          userId: _apiService.userId ?? '',
          position: pos,
        );
      }
    }
    await fetchPositions();
  }

  Future<void> squareOffSingle(Map<String, dynamic> position) async {
    await _apiService.squareOffPosition(
      userId: _apiService.userId ?? '',
      position: position,
    );
    await fetchPositions();
  }

  void dispose() {
    _wsSubscription?.cancel();
    _exitMonitorTimer?.cancel();
  }
}
