import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'websocket_service.dart';
import 'pnl_service.dart';

class StrategyService {
  static final StrategyService _instance = StrategyService._internal();
  factory StrategyService() => _instance;
  StrategyService._internal() {
    _startClock();
    _startWsBinding();
  }

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final WebSocketService _wsService = WebSocketService();

  // State
  final ValueNotifier<String> currentTime = ValueNotifier<String>('');
  final ValueNotifier<String?> capturedSpotPrice = ValueNotifier<String?>(null);
  final ValueNotifier<int?> indexLotSize = ValueNotifier<int?>(null);
  final ValueNotifier<List<Map<String, dynamic>>> strikes = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<String?> statusMessage = ValueNotifier<String?>(null);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isCapturing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isResolving = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isStrategyDay = ValueNotifier<bool>(false);

  // Configuration (ValueNotifiers for dynamic updates)
  final ValueNotifier<String> targetIndex = ValueNotifier<String>('NIFTY');
  final ValueNotifier<String> strategyTime = ValueNotifier<String>('13:15');
  final ValueNotifier<bool> showTestButton = ValueNotifier<bool>(false);

  Map<String, dynamic> _settings = {};
  Timer? _timer;
  StreamSubscription? _wsSubscription;

  Future<void> init() async {
    await _loadSettingsAndRestore();
  }

  /// Public method to reload settings from storage (e.g. after SettingsPage save)
  Future<void> refreshSettings() async {
    await _loadSettingsAndRestore();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      currentTime.value = DateFormat('HH:mm:ss').format(now);
      _checkStrategyCondition(now);
    });
  }

  void _startWsBinding() {
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.messageStream.listen((message) {
      final String? type = message['t']?.toString();
      if (type == 't' || type == 'tf' || type == 'tk') {
        final String? token = message['tk']?.toString();
        final String? lp = message['lp']?.toString();
        if (token != null && lp != null) {
          _updateStrikePrice(token, lp);
        }
      }
    });
  }

  Future<void> _loadSettingsAndRestore() async {
    _settings = await _storageService.getStrategySettings();
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    strategyTime.value = _settings['strategyTime'] ?? '13:15';
    showTestButton.value = _settings['showTestButton'] ?? false;
    
    print('StrategyService: DayName=$dayName, NiftyDay=${_settings['niftyDay']}, SensexDay=${_settings['sensexDay']}, TargetTime=${strategyTime.value}');
    
    if (dayName == _settings['niftyDay']) {
      isStrategyDay.value = true;
      targetIndex.value = 'NIFTY';
    } else if (dayName == _settings['sensexDay']) {
      isStrategyDay.value = true;
      targetIndex.value = 'SENSEX';
    } else {
      isStrategyDay.value = false;
    }

    // If current time is LESS than strategy trigger time, clear any existing capture
    // to ensure we are in "Waiting" mode.
    final String currentHhMm = DateFormat('HH:mm').format(now);
    if (currentHhMm.compareTo(strategyTime.value) < 0) {
      debugPrint('StrategyService: Resetting state because current time ($currentHhMm) is before trigger (${strategyTime.value})');
      await resetStrategy();
      return;
    }

    // Load saved daily capture
    final savedCapture = await _storageService.getDailyCapture();
    if (savedCapture != null && savedCapture['date'] == todayStr) {
      print('StrategyService: Restoring Daily Capture');
      capturedSpotPrice.value = savedCapture['spot']?.toString();
      indexLotSize.value = savedCapture['indexLotSize'] as int?;
      final List<dynamic> strikesRaw = savedCapture['strikes'] ?? [];
      final List<Map<String, dynamic>> resolvedStrikes = strikesRaw.map((s) => Map<String, dynamic>.from(s)).toList();
      strikes.value = resolvedStrikes;

      // Subscribe to WS
      final String exchange = targetIndex.value == 'NIFTY' ? 'NFO' : 'BFO';
      for (var s in resolvedStrikes) {
        _wsService.subscribeTouchline(exchange, s['token'].toString());
      }
    }
  }

  void _checkStrategyCondition(DateTime now) {
    if (capturedSpotPrice.value != null || isCapturing.value || isResolving.value) return;

    if (!isStrategyDay.value) {
      return;
    }

    final String timeStr = DateFormat('HH:mm').format(now);
    
    if (timeStr.compareTo(strategyTime.value) >= 0) {
      debugPrint('StrategyService: [Auto-Trigger] Time MET. Current: $timeStr, Target: ${strategyTime.value}');
      _runAutoStrategy();
    }
  }

  Future<void> _runAutoStrategy() async {
    // Run spot capture with retries
    bool captured = await _retry(() => captureSpotPrice(), 
      name: 'Spot Capture', 
      maxAttempts: 5,
      delay: const Duration(seconds: 10)
    );
  }

  Future<bool> _retry(Future<void> Function() action, {required String name, int maxAttempts = 3, Duration delay = const Duration(seconds: 5)}) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      attempts++;
      try {
        errorMessage.value = null; // Clear error before retry
        await action();
        
        // If it was captureSpotPrice, success is capturedSpotPrice != null
        // If it was _generateAndResolveStrikes, success is strikes != empty (or depends on implementation)
        // Since we wrap actions that update state, we check the relevant state or just return true if no exception.
        if (errorMessage.value == null) {
          debugPrint('StrategyService: $name SUCCESS on attempt $attempts');
          return true;
        }
      } catch (e) {
        debugPrint('StrategyService: $name attempt $attempts FAILED with: $e');
      }
      
      if (attempts < maxAttempts) {
        statusMessage.value = 'Retrying $name ($attempts/$maxAttempts) in ${delay.inSeconds}s...';
        debugPrint('StrategyService: Retrying $name in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    debugPrint('StrategyService: $name EXHAUSTED after $maxAttempts attempts.');
    return false;
  }

  Future<void> captureSpotPrice() async {
    if (isCapturing.value) return;
    
    debugPrint('StrategyService: Capture process STARTED for ${targetIndex.value}');
    isCapturing.value = true;
    errorMessage.value = null;
    statusMessage.value = 'Capturing Spot Price for ${targetIndex.value}...';

    final String? uid = await _storageService.getUid();
    if (uid == null) {
      errorMessage.value = 'User ID not found. Please log in again.';
      isCapturing.value = false;
      debugPrint('StrategyService: Capture FAILED - No User ID');
      return;
    }

    try {
      final String indexSymbol = targetIndex.value == 'NIFTY' ? 'Nifty 50' : 'SENSEX';
      final String exchange = targetIndex.value == 'NIFTY' ? 'NSE' : 'BSE';
      final String token = targetIndex.value == 'NIFTY' ? '26000' : '1';

      debugPrint('StrategyService: Fetching quote for $indexSymbol ($exchange|$token)...');
      final response = await _apiService.getQuote(
        userId: uid,
        exchange: exchange,
        token: token,
      );

      if (response['stat'] == 'Ok') {
        final String? lp = response['lp']?.toString();
        final String? ls = response['ls']?.toString();
        
        if (lp != null) {
          debugPrint('StrategyService: Spot Captured SUCCESS: $lp');
          capturedSpotPrice.value = lp;
          indexLotSize.value = int.tryParse(ls ?? '1');
          statusMessage.value = 'Spot Captured: $lp. Resolving strikes...';
          await _generateAndResolveStrikes(double.parse(lp), uid);
        } else {
          errorMessage.value = 'Failed to get spot price from response.';
          debugPrint('StrategyService: Capture FAILED - No "lp" in response');
        }
      } else {
        errorMessage.value = response['emsg'] ?? 'API Error capturing spot.';
        debugPrint('StrategyService: API Error during capture: ${response['emsg']}');
      }
    } catch (e) {
      errorMessage.value = 'Capture Error: $e';
      debugPrint('StrategyService: Exception during capture: $e');
    } finally {
      isCapturing.value = false;
    }
  }

  Future<void> _generateAndResolveStrikes(double spot, String uid) async {
    isResolving.value = true;
    debugPrint('StrategyService: Resolution STARTED for Spot $spot');
    final List<Map<String, dynamic>> resolvedStrikes = [];
    final String exchange = targetIndex.value == 'NIFTY' ? 'NFO' : 'BFO';

    // Step size: NIFTY=50, SENSEX=100
    final int step = targetIndex.value == 'NIFTY' ? 50 : 100;

    // Calculate first OTM CE and PE separately
    final int ceBase = (spot / step).floor().toInt() * step + step;
    final int peBase = (spot / step).ceil().toInt() * step - step;
    
    final List<Map<String, dynamic>> targets = [
      {'strike': ceBase, 'type': 'C'},           // OTM CE 1
      {'strike': ceBase + step, 'type': 'C'},    // OTM CE 2
      {'strike': peBase, 'type': 'P'},           // OTM PE 1
      {'strike': peBase - step, 'type': 'P'},    // OTM PE 2
    ];

    for (var s in targets) {
      final strike = s['strike'];
      final type = s['type'];
      
      final String lookFor = (type == 'C' ? 'CE' : 'PE');
      
      // Broader search pattern: Index name + Strike + Type
      final List<String> searchStrings = [
        '${targetIndex.value} $strike $lookFor',
        '${targetIndex.value}$strike $lookFor',
        '${targetIndex.value} $strike',
      ];

      Map<String, dynamic>? bestMatch;
      
      for (var query in searchStrings) {
        statusMessage.value = 'Searching for $query...';
        debugPrint('StrategyService: Searching for "$query"...');
        try {
          final searchResult = await _retryWithResult(() => _apiService.searchScrip(userId: uid, searchText: query), name: 'Search $query');
          if (searchResult != null && searchResult['stat'] == 'Ok' && searchResult['values'] != null) {
            final List<dynamic> values = searchResult['values'];
            
            for (var v in values) {
              final String tsym = v['tsym'].toString().trim();
              final String optt = v['optt']?.toString() ?? '';
              
              // Filter by strike presence and option type
              if (tsym.contains(strike.toString()) && (optt == lookFor || tsym.contains(lookFor))) {
                bestMatch = v;
                break; 
              }
            }
            
            if (bestMatch != null) {
              debugPrint('StrategyService: FOUND Match for "$query" -> ${bestMatch['tsym']}');
              break; 
            }
          }
        } catch (e) {
          debugPrint('StrategyService: Error during search for "$query": $e');
        }
      }

      if (bestMatch != null) {
        statusMessage.value = 'Fetching price for ${bestMatch['tsym']}...';
        String initialLp = '...';
        try {
          final quote = await _retryWithResult(() => _apiService.getQuote(userId: uid, exchange: exchange, token: bestMatch!['token'].toString()), name: 'Quote ${bestMatch['tsym']}');
          if (quote != null && quote['stat'] == 'Ok') {
            initialLp = quote['lp']?.toString() ?? '...';
          }
        } catch (e) {
          debugPrint('StrategyService: Error fetching initial lp for ${bestMatch['tsym']}: $e');
        }

        resolvedStrikes.add({
          'strike': strike,
          'type': type == 'P' ? 'PE' : 'CE',
          'token': bestMatch['token'],
          'tsym': bestMatch['tsym'],
          'exd': bestMatch['exd'],
          'exch': bestMatch['exch'],
          'selected': true,
          'lp': initialLp,
        });
        _wsService.subscribeTouchline(exchange, bestMatch['token'].toString());
      } else {
        debugPrint('StrategyService: NO MATCH found for strike $strike $type');
      }
    }

    if (resolvedStrikes.isEmpty) {
      errorMessage.value = 'Failed to resolve contracts for ${targetIndex.value}. Please check if ${targetIndex.value} $spot has active strikes.';
      debugPrint('StrategyService: Resolution COMPLETE - ZERO strikes found.');
    } else if (resolvedStrikes.length < targets.length) {
      errorMessage.value = 'Only resolved ${resolvedStrikes.length}/${targets.length} strikes.';
    }

    strikes.value = resolvedStrikes;
    _saveCaptureState();
    isResolving.value = false;
    statusMessage.value = 'Strikes ready.';
  }

  void _updateStrikePrice(String token, String lp) {
    bool updated = false;
    final List<Map<String, dynamic>> currentStrikes = List.from(strikes.value);
    for (var strike in currentStrikes) {
      if (strike['token']?.toString() == token) {
        if (strike['lp'] != lp) {
          strike['lp'] = lp;
          updated = true;
        }
      }
    }
    if (updated) {
      strikes.value = currentStrikes;
    }
  }

  void toggleStrikeSelection(int index) {
    if (index < 0 || index >= strikes.value.length) return;
    final List<Map<String, dynamic>> currentStrikes = List.from(strikes.value);
    currentStrikes[index]['selected'] = !(currentStrikes[index]['selected'] ?? false);
    strikes.value = currentStrikes;
    _saveCaptureState();
  }

  void deleteStrike(int index) {
    if (index < 0 || index >= strikes.value.length) return;
    final List<Map<String, dynamic>> currentStrikes = List.from(strikes.value);
    final strike = currentStrikes.removeAt(index);
    
    final String token = strike['token']?.toString() ?? '';
    final String exch = targetIndex.value == 'NIFTY' ? 'NFO' : 'BFO';
    if (token.isNotEmpty) {
      _wsService.unsubscribeTouchline(exch, token);
    }

    strikes.value = currentStrikes;
    _saveCaptureState();
  }

  Future<void> _saveCaptureState() async {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _storageService.saveDailyCapture({
      'date': todayStr,
      'spot': capturedSpotPrice.value,
      'indexLotSize': indexLotSize.value,
      'strikes': strikes.value,
    });
  }

  /// Resets the daily capture state. Use this to re-trigger the strategy.
  Future<void> resetStrategy() async {
    debugPrint('StrategyService: Resetting daily capture state...');
    // Unsubscribe from current strikes
    final String exchange = targetIndex.value == 'NIFTY' ? 'NFO' : 'BFO';
    for (var s in strikes.value) {
      final String token = s['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        _wsService.unsubscribeTouchline(exchange, token);
      }
    }

    capturedSpotPrice.value = null;
    indexLotSize.value = null;
    strikes.value = [];
    errorMessage.value = null;
    statusMessage.value = null;
    
    await _storageService.clearDailyCapture();
    debugPrint('StrategyService: Reset COMPLETE.');
  }

  // Track order status for UI feedback
  final ValueNotifier<String?> orderStatus = ValueNotifier<String?>(null);

  Future<void> placeOrders() async {
    final String? uid = await _storageService.getUid();
    if (uid == null) {
      errorMessage.value = 'User ID not found.';
      return;
    }
    
    orderStatus.value = 'Placing orders...';
    errorMessage.value = null;

    final settings = await _storageService.getStrategySettings();
    final int userLots = targetIndex.value == 'NIFTY' 
        ? (settings['niftyLotSize'] ?? 1) 
        : (settings['sensexLotSize'] ?? 1);

    int successCount = 0;
    String? lastError;
    final List<Map<String, dynamic>> selectedStrikes = strikes.value.where((s) => s['selected'] == true).toList();

    if (selectedStrikes.isEmpty) {
        orderStatus.value = 'No strikes selected';
        return;
    }

    final int? effectiveIndexLotSize = indexLotSize.value;

    for (var strike in selectedStrikes) {
      final int effectiveLs = effectiveIndexLotSize ?? (targetIndex.value == 'NIFTY' ? 75 : 20);
      final int finalQty = userLots * effectiveLs;
      
      try {
        final response = await _apiService.placeOrder(
          userId: uid,
          exchange: strike['exch'],
          tradingSymbol: strike['tsym'],
          quantity: finalQty.toString(),
          price: '0', 
          transactionType: 'B',
          productType: 'M', 
          orderType: 'MKT',
          ret: 'DAY',
        );

        if (response['stat'] == 'Ok') {
          successCount++;
        } else {
          lastError = response['emsg'] ?? 'Unknown Error';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (successCount == selectedStrikes.length) {
      orderStatus.value = 'Successfully placed $successCount orders';
    } else {
      orderStatus.value = 'Placed $successCount/${selectedStrikes.length} orders.';
      errorMessage.value = lastError;
    }
    
    // Refresh PnLService to see new positions
    PnLService().fetchPositions();
  }

  Future<T?> _retryWithResult<T>(Future<T> Function() action, {required String name, int maxAttempts = 3, Duration delay = const Duration(seconds: 5)}) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      attempts++;
      try {
        return await action();
      } catch (e) {
        debugPrint('StrategyService: $name attempt $attempts FAILED with: $e');
        if (attempts < maxAttempts) {
          await Future.delayed(delay);
        }
      }
    }
    return null;
  }

  void dispose() {
    _timer?.cancel();
    _wsSubscription?.cancel();
  }
}
