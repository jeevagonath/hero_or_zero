import 'dart:async';
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
    // Initial fetch if user is likely logged in
    _storageService.getUid().then((uid) {
      if (uid != null) {
        fetchPositions();
      }
    });
  }

  final ApiService _apiService = ApiService();
  final WebSocketService _webSocketService = WebSocketService();
  final StorageService _storageService = StorageService();

  final ValueNotifier<double> totalPnL = ValueNotifier<double>(0.0);
  final ValueNotifier<List<Map<String, dynamic>>> positions = ValueNotifier<List<Map<String, dynamic>>>([]);
  
  final ValueNotifier<Map<String, dynamic>> portfolioExitStatus = ValueNotifier<Map<String, dynamic>>({
    'peakProfit': 0.0,
    'tsl': -999999.0,
    'totalLots': 0.0,
    'exitTime': '15:00',
  });
  double _peakProfit = 0.0;
  final Set<String> _exitingTokens = {};

  Future<void> _initFromStorage() async {
    final settings = await _storageService.getStrategySettings();
    final String exitT = settings['exitTime'] ?? '15:00';
    
    final savedProfits = await _storageService.getPeakProfits();
    _peakProfit = savedProfits['portfolio'] ?? 0.0;
    
    portfolioExitStatus.value = {
      ...portfolioExitStatus.value,
      'peakProfit': _peakProfit,
      'exitTime': exitT,
    };
  }  
  StreamSubscription? _wsSubscription;
  bool _isFetching = false;
  Timer? _exitMonitorTimer;

  Future<void> fetchPositions() async {
    if (_isFetching) return;
    _isFetching = true;

    final String? uid = _apiService.userId ?? await _storageService.getUid();
    if (uid == null) {
      _isFetching = false;
      return;
    }

    try {
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
    } catch (e) {
      print('PnLService Fetch Error: $e');
    } finally {
      _isFetching = false;
    }
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
    double totalLots = 0.0;

    for (var pos in positions.value) {
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
        totalLots += netqty.abs() / lotSize;
      }
    }
    
    totalPnL.value = total;

    // Portfolio Exit Logic
    if (totalLots > 0) {
      final status = Map<String, dynamic>.from(portfolioExitStatus.value);
      status['totalLots'] = totalLots;

      // Trigger TSL activation if total profit >= 200 * totalLots
      final double activationThreshold = 200.0 * totalLots;
      final double trailingGap = 150.0 * totalLots;

      if (total > _peakProfit) {
        _peakProfit = total;
        status['peakProfit'] = _peakProfit;
        _storageService.savePeakProfits({'portfolio': _peakProfit});
      }

      if (status['tsl'] == -999999.0 && _peakProfit >= activationThreshold) {
        status['tsl'] = _peakProfit - trailingGap;
      } else if (status['tsl'] != -999999.0 && _peakProfit > status['peakProfit']) {
         // Trail the SL if peak moves up
         status['tsl'] = _peakProfit - trailingGap;
      }

      portfolioExitStatus.value = status;

      // Check for TSL Hit
      if (status['tsl'] != -999999.0 && total <= status['tsl']) {
        squareOffAll('Portfolio Trailing SL Hit');
      }
    }
  }

  void _startExitMonitor() {
    _exitMonitorTimer?.cancel();
    _exitMonitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      final String currentHhMm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final String exitT = portfolioExitStatus.value['exitTime'] ?? '15:00';
      
      if (currentHhMm == exitT) {
        squareOffAll('Time-Based Exit ($exitT)');
      }
      fetchPositions();
    });
  }

  Future<void> refreshSettings() async {
    await _initFromStorage();
  }

  Future<void> _autoSquareOff(Map<String, dynamic> position, String reason) async {
    final String token = position['token'] ?? '';
    if (_exitingTokens.contains(token)) return;

    _exitingTokens.add(token);

    print('Auto Squaring Off ${position['tsym']} due to $reason');
    await _apiService.squareOffPosition(
      userId: _apiService.userId ?? await _storageService.getUid() ?? '',
      position: position,
    );
    _exitingTokens.remove(token);
    await fetchPositions();
  }

  Future<int> squareOffAll([String reason = 'Manual Close All']) async {
    final String? uid = _apiService.userId ?? await _storageService.getUid();
    if (uid == null) return 0;

    int ordersPlaced = 0;
    final currentPositions = List<Map<String, dynamic>>.from(positions.value);
    
    for (var pos in currentPositions) {
      final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0;
      if (netqty != 0) {
        final result = await _apiService.squareOffPosition(
          userId: uid,
          position: pos,
        );
        if (result['stat'] == 'Ok') {
          ordersPlaced++;
        } else {
          print('Square Off Failed for ${pos['tsym']}: ${result['emsg']}');
        }
      }
    }
    
    // Clear peak profit after square off all
    _peakProfit = 0;
    _storageService.clearPeakProfits();
    final status = Map<String, dynamic>.from(portfolioExitStatus.value);
    status['peakProfit'] = 0.0;
    status['tsl'] = -999999.0;
    portfolioExitStatus.value = status;

    await fetchPositions();
    return ordersPlaced;
  }

  Future<Map<String, dynamic>> squareOffSingle(Map<String, dynamic> position) async {
    final String? uid = _apiService.userId ?? await _storageService.getUid();
    if (uid == null) return {'stat': 'Not_Ok', 'emsg': 'User ID not found'};

    final result = await _apiService.squareOffPosition(
      userId: uid,
      position: position,
    );
    await fetchPositions();
    return result;
  }

  void dispose() {
    _wsSubscription?.cancel();
    _exitMonitorTimer?.cancel();
  }
}
