import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'websocket_service.dart';
import 'pnl_service.dart';
import 'exit_strategy_service.dart';

class Strategy930Service {
  static final Strategy930Service _instance = Strategy930Service._internal();
  factory Strategy930Service() => _instance;
  Strategy930Service._internal() {
    _startWsBinding(); // Start listening to WebSocket
    _loadSettings().then((_) => _restoreState());
  }

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final WebSocketService _wsService = WebSocketService();
  final PnLService _pnlService = PnLService();
  final ExitStrategyService _exitService = ExitStrategyService();

  // State
  final ValueNotifier<String> currentTime = ValueNotifier<String>('');
  final ValueNotifier<double?> niftySpot = ValueNotifier<double?>(null);
  final ValueNotifier<double?> sensexSpot = ValueNotifier<double?>(null);
  
  // List of resolved strikes. 
  // Structure: { 'strike': int, 'type': 'CE'/'PE', 'tsym': String, 'token': String, 'exch': String, 'lp': String, 'selected': bool }
  final ValueNotifier<List<Map<String, dynamic>>> niftyStrikes = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> sensexStrikes = ValueNotifier<List<Map<String, dynamic>>>([]);
  
  final ValueNotifier<String?> statusMessage = ValueNotifier<String?>(null);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);

  // Constants (Defaults)
  // Constants (Defaults) -> Now ValueNotifiers for UI
  final ValueNotifier<String> timeSpotCapture = ValueNotifier<String>('09:25');
  final ValueNotifier<String> timeStrikeFetch = ValueNotifier<String>('09:30');

  Timer? _timer;
  StreamSubscription? _wsSubscription;
  bool _spotCapturedToday = false;
  bool _strikesFetchedToday = false;

  // Exit Logic State
  // Token -> SL Order Number
  final Map<String, String> _activeSLOrders = {}; 
  // Token -> Last Known SL Level (0=None, 1=Initial, 2=Modified)
  final Map<String, int> _slLevels = {};
  
  // Token -> Status Message (e.g., "SL: 120.5", "Hard SL Hit")
  final ValueNotifier<Map<String, String>> exitStatusMap = ValueNotifier<Map<String, String>>({});



  Future<void> _saveState() async {
     try {
       final String today = DateTime.now().toString().split(' ')[0];
       final data = {
         'date': today,
         'niftySpot': niftySpot.value,
         'sensexSpot': sensexSpot.value,
         'niftyStrikes': niftyStrikes.value,
         'sensexStrikes': sensexStrikes.value,
         'spotCaptured': _spotCapturedToday,
         'strikesFetched': _strikesFetchedToday,
       };
       await _storageService.saveStrategy930Data(data);
     } catch (e) {
       debugPrint('Strategy930: Save State Error: $e');
     }
  }

  Future<void> _restoreState() async {
      try {
        final data = await _storageService.getStrategy930Data();
        if (data == null) return;

        final String savedDate = data['date'];
        final String today = DateTime.now().toString().split(' ')[0];

        if (savedDate != today) {
          debugPrint('Strategy930: Found old data from $savedDate. Clearing.');
          await _storageService.clearStrategy930Data();
          return;
        }

        // Restore
        debugPrint('Strategy930: Restoring state for $today');
        niftySpot.value = data['niftySpot'];
        sensexSpot.value = data['sensexSpot'];
        
        if (data['niftyStrikes'] != null) {
           final List<dynamic> ns = data['niftyStrikes'];
           niftyStrikes.value = ns.map((e) => Map<String, dynamic>.from(e)).toList();
           // Resubscribe symbols
           for(var s in niftyStrikes.value) {
              _wsService.subscribeTouchline(s['exch'], s['token']);
              _exitService.excludeToken(s['token'].toString());
           }
        }

        if (data['sensexStrikes'] != null) {
           final List<dynamic> ss = data['sensexStrikes'];
           sensexStrikes.value = ss.map((e) => Map<String, dynamic>.from(e)).toList();
           for(var s in sensexStrikes.value) {
              _wsService.subscribeTouchline(s['exch'], s['token']);
              _exitService.excludeToken(s['token'].toString());
           }
        }

        _spotCapturedToday = data['spotCaptured'] ?? false;
        _strikesFetchedToday = data['strikesFetched'] ?? false;
        
      } catch (e) {
        debugPrint('Strategy930: Restore State Error: $e');
      }
  }

  /// Public method to refresh settings from storage (called by SettingsPage)
  Future<void> refreshSettings() async {
    await _loadSettings();
    // Also reset "Today" flags for testing convenience? 
    // No, that might cause double triggers. User can use manual button to force run.
  }

    Future<void> _loadSettings() async {
    final settings = await _storageService.getStrategySettings();
    timeSpotCapture.value = settings['strategy930CaptureTime'] ?? '09:25';
    timeStrikeFetch.value = settings['strategy930FetchTime'] ?? '09:30';
    debugPrint('Strategy930: Loaded Times - Capture: ${timeSpotCapture.value}, Fetch: ${timeStrikeFetch.value}');
  }

  void ensureTimerRunning() {
    if (_timer == null || !_timer!.isActive) {
      debugPrint('Strategy930: Timer was not active. Restarting.');
      _startClock();
    }
  }

  void _startClock() {
    _timer?.cancel();
    debugPrint('Strategy930: Starting Clock...');
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss').format(now);
      currentTime.value = timeStr;
      
      final shortTime = DateFormat('HH:mm').format(now);
      _checkTriggers(shortTime);
    });
  }

  void _checkTriggers(String shortTime) {
    if (isBusy.value) return;

    // Reset flags if it's a new day (simple check: if time is 09:00, reset)
    // Actually safer to just rely on "once per day" logic or manual reset.
    // Let's assume the app might be restarted. Ideally we should save state, 
    // but for now we follow the requirement: 9:25 Capture, 9:30 Fetch.
    
    // Trigger 1: Spot Capture
    if (shortTime == timeSpotCapture.value && !_spotCapturedToday) {
      captureSpots();
    }
    
    // Trigger 2: Fetch Strikes
    if (shortTime == timeStrikeFetch.value && !_strikesFetchedToday) {
      fetchStrikes();
    }
    
    // Continuous Exit Monitoring (Run every second)
    _monitorExits();
  }

  Future<void> _monitorExits() async {
    // Only run if we have active positions matching our strikes
    final positions = _pnlService.positions.value;
    if (positions.isEmpty) return;

    final allStrikes = [...niftyStrikes.value, ...sensexStrikes.value];
    final Set<String> strategyTokens = allStrikes.map((s) => s['token'].toString()).toSet();

    for (var pos in positions) {
      final String token = pos['token']?.toString() ?? '';
      if (!strategyTokens.contains(token)) continue;

      final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0;
      if (netqty == 0) {
        // Position Closed: Cleanup SL if exists
        if (_activeSLOrders.containsKey(token)) {
           await _cancelSLOrder(token);
        }
        continue;
      }

      // Check Exit Rules
      await _checkExitRules(pos, token);
    }
  }

  Future<void> _checkExitRules(Map<String, dynamic> pos, String token) async {
      final double avgPrice = double.tryParse(pos['netavgprc']?.toString() ?? '0') ?? 0.0;
      final double ltp = double.tryParse(pos['lp']?.toString() ?? '0') ?? 0.0;
      
      if (avgPrice <= 0 || ltp <= 0) return;

      // 1. Hard Stop-Loss: -18 points
      if (ltp <= (avgPrice - 18)) {
        debugPrint('Strategy930: Hard SL Hit for $token. LTP: $ltp, Avg: $avgPrice');
        statusMessage.value = 'Hard SL Hit: Exiting ${pos['tsym']}';
        
        _updateExitStatus(token, 'Hard SL Exit');

        // Cancel pending SL first
        if (_activeSLOrders.containsKey(token)) {
           await _cancelSLOrder(token);
        }
        await _apiService.squareOffPosition(userId: _apiService.userId!, position: pos);
        return;
      }

      // 2. Initial Profit Protection (TSL Placement): +20 points
      if (ltp >= (avgPrice + 20)) {
         // Calculate Trailing Level
         // Level 1: Profit >= 20 -> SL = Avg + 2
         // Level 2: Profit >= 40 -> SL = Avg + 30
         // Level 3: Profit >= 60 -> SL = Avg + 50
         // Level N: Profit >= 40 + (N-2)*20 -> SL = Avg + 30 + (N-2)*20
         
         int targetLevel = 0;
         double targetSLPrice = 0.0;
         
         double profitPoints = ltp - avgPrice;
         
         if (profitPoints >= 40) {
             // For profit 40, steps=0. Profit 60, steps=1.
             int steps = ((profitPoints - 40) / 20).floor();
             targetLevel = 2 + steps;
             targetSLPrice = avgPrice + 30 + (steps * 20);
         } else if (profitPoints >= 20) {
             targetLevel = 1;
             targetSLPrice = avgPrice + 2;
         }

         if (targetLevel > 0) {
             if (!_activeSLOrders.containsKey(token)) {
                 // Place Initial SL
                 await _placeSLOrder(pos, token, targetSLPrice);
                 _slLevels[token] = targetLevel;
             } else {
                 // Modify if moving to a HIGHER level
                 final int currentLevel = _slLevels[token] ?? 1;
                 if (targetLevel > currentLevel) {
                     await _modifySLOrder(pos, token, targetSLPrice);
                     _slLevels[token] = targetLevel;
                 }
             }
         }
      }
  }

  Future<void> _placeSLOrder(Map<String, dynamic> pos, String token, double slPrice) async {
    debugPrint('Strategy930: Placing SL for ${pos['tsym']} at $slPrice');
    statusMessage.value = 'Placing TSL for ${pos['tsym']} at $slPrice';
    
    // Ensure we use the correct quantity (netqty)
    final String qty = pos['netqty'].toString(); // Assuming positive for Buy position

    // SL-LIMIT Order
    // Trigger = slPrice
    // Price = slPrice (or slightly lower for Sell? For SL-LMT Sell, Price <= Trigger)
    // Let's use Price = Trigger for simplicity, or Trigger - 0.5?
    // Requirement says "Stop-loss price should be Order price + 2". 
    // Usually means Trigger. We'll set limit same as trigger.
    
    final res = await _apiService.placeOrder(
      userId: _apiService.userId!,
      exchange: pos['exch'],
      tradingSymbol: pos['tsym'],
      quantity: qty,
      price: slPrice.toStringAsFixed(1), // Limit Price
      triggerPrice: slPrice.toStringAsFixed(1), // Trigger Price
      transactionType: 'S', // Sell to exit Buy
      productType: pos['prd'] ?? 'M',
      orderType: 'SL-LMT',
      ret: 'DAY'
    );

    if (res['stat'] == 'Ok') {
       if (res['norenordno'] != null) {
         _activeSLOrders[token] = res['norenordno'];
         _slLevels[token] = 1; // Level 1 Set
         _updateExitStatus(token, 'SL Placed: $slPrice');
       }
    } else {
       errorMessage.value = 'Failed to place SL: ${res['emsg']}';
       _updateExitStatus(token, 'SL Fail');
    }
  }

  Future<void> _modifySLOrder(Map<String, dynamic> pos, String token, double newPrice) async {
     final String? ordNo = _activeSLOrders[token];
     if (ordNo == null) return;

     debugPrint('Strategy930: Modifying SL for ${pos['tsym']} to $newPrice');
     statusMessage.value = 'Modifying TSL for ${pos['tsym']} to $newPrice';

     final String qty = pos['netqty'].toString();

     final res = await _apiService.modifyOrder(
       userId: _apiService.userId!,
       norenordno: ordNo,
       exchange: pos['exch'],
       tradingSymbol: pos['tsym'],
       quantity: qty,
       price: newPrice.toStringAsFixed(1),
       triggerPrice: newPrice.toStringAsFixed(1),
       orderType: 'SL-LMT',
       productType: pos['prd'] ?? 'M',
     );

     if (res['stat'] == 'Ok') {
        _slLevels[token] = 2; // Level 2 Set
        _updateExitStatus(token, 'SL Mod: $newPrice');
     } else {
        debugPrint('Strategy930: Failed to modify SL: ${res['emsg']}');
        // If modification fails (maybe order executed?), check status?
     }
  }

  Future<void> _cancelSLOrder(String token) async {
    final String? ordNo = _activeSLOrders[token];
    if (ordNo == null) return;
    
    debugPrint('Strategy930: Cancelling SL Order $ordNo');
    await _apiService.cancelOrder(userId: _apiService.userId!, norenordno: ordNo);
    _activeSLOrders.remove(token);
    _slLevels.remove(token);
    _updateExitStatus(token, ''); // Clear status
  }
  
  void _updateExitStatus(String token, String status) {
     final current = Map<String, String>.from(exitStatusMap.value);
     if (status.isEmpty) {
       current.remove(token);
     } else {
       current[token] = status;
     }
     exitStatusMap.value = current;
  }

  void _startWsBinding() {
    debugPrint('Strategy930: Starting WS Binding...');
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.messageStream.listen((message) {
      final String? type = message['t']?.toString();
      if (type == 't' || type == 'tf' || type == 'tk') {
        final String? token = message['tk']?.toString();
        final String? lp = message['lp']?.toString();
        final String? pc = message['pc']?.toString();
        // debugPrint('Strategy930: WS Tick for $token -> $lp ($pc%)');
        if (token != null && lp != null) {
          _updateStrikePrice(token, lp, pc);
        }
      }
    });
  }

  void _updateStrikePrice(String token, String lp, String? pc) {
    bool updated = false;

    // Check Nifty
    final nifty = List<Map<String, dynamic>>.from(niftyStrikes.value);
    for (var s in nifty) {
      if (s['token'] == token) {
        if (s['lp'] != lp || s['pc'] != pc) {
          s['lp'] = lp;
          if (pc != null) s['pc'] = pc;
          updated = true;
        }
      }
    }
    if (updated) {
       niftyStrikes.value = nifty;
    }

    updated = false;
    // Check Sensex
    final sensex = List<Map<String, dynamic>>.from(sensexStrikes.value);
    for (var s in sensex) {
      if (s['token'] == token) {
        if (s['lp'] != lp || s['pc'] != pc) {
          s['lp'] = lp;
          if (pc != null) s['pc'] = pc;
          updated = true;
        }
      }
    }
    if (updated) {
       sensexStrikes.value = sensex;
    }
  }

  Future<void> captureSpots() async {
    if (isBusy.value) return;
    isBusy.value = true;
    statusMessage.value = 'Capturing 9:25 Spot Prices...';
    errorMessage.value = null;

    try {
      final String? uid = await _storageService.getUid();
      if (uid == null) throw 'User not logged in';

      // Capture NIFTY (NSE|26000)
      final niftyRes = await _apiService.getQuote(userId: uid, exchange: 'NSE', token: '26000');
      if (niftyRes['stat'] == 'Ok' && niftyRes['lp'] != null) {
        niftySpot.value = double.tryParse(niftyRes['lp']);
      }

      // Capture SENSEX (BSE|1)
      final sensexRes = await _apiService.getQuote(userId: uid, exchange: 'BSE', token: '1');
      if (sensexRes['stat'] == 'Ok' && sensexRes['lp'] != null) {
        sensexSpot.value = double.tryParse(sensexRes['lp']);
      }

      _spotCapturedToday = true;
      statusMessage.value = 'Spot Captured: Nifty ${niftySpot.value}, Sensex ${sensexSpot.value}';
      _saveState();
    } catch (e) {
      errorMessage.value = 'Spot Capture Failed: $e';
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> fetchStrikes() async {
    if (isBusy.value) return;
    isBusy.value = true;
    statusMessage.value = 'Fetching 9:30 Option Contracts...';
    errorMessage.value = null;

    try {
      final String? uid = await _storageService.getUid();
      if (uid == null) throw 'User not logged in';

      // Ensure we have spots (re-capture if needed, though 9:25 should have run)
      if (niftySpot.value == null || sensexSpot.value == null) {
        await captureSpots();
      }

      if (niftySpot.value != null) {
        await _resolveStrikesForIndex(uid, 'NIFTY', niftySpot.value!, 50, niftyStrikes);
      }
      
      if (sensexSpot.value != null) {
        await _resolveStrikesForIndex(uid, 'SENSEX', sensexSpot.value!, 100, sensexStrikes);
      }

      _strikesFetchedToday = true;
      _strikesFetchedToday = true;
      if (niftyStrikes.value.isEmpty && sensexStrikes.value.isEmpty) {
        statusMessage.value = 'Fetch Complete: No strikes found. Check Search Logic.';
        errorMessage.value = 'No contracts found for current spot.';
      } else {
        statusMessage.value = 'Contracts Fetched: ${niftyStrikes.value.length} Nifty, ${sensexStrikes.value.length} Sensex';
        _saveState();
      }

    } catch (e) {
      errorMessage.value = 'Fetch Failed: $e';
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> _resolveStrikesForIndex(
    String uid, 
    String indexName, 
    double spot, 
    int step, 
    ValueNotifier<List<Map<String, dynamic>>> targetNotifier
  ) async {
    final int atm = (spot / step).round() * step;
    
    // Requirement: 1 ATM and 4 ITM
    // ITM for CE: Strikes BELOW Spot (Strike < Spot) -> Since ATM is close to spot, we take ATM and 4 BELOW.
    // ITM for PE: Strikes ABOVE Spot (Strike > Spot) -> ATM and 4 ABOVE.

    List<int> ceStrikes = [];
    for (int i = 0; i < 5; i++) {
      ceStrikes.add(atm - (i * step)); // ATM, ATM-50, ATM-100...
    }
    // Sort ascending for display consistency
    ceStrikes.sort();

    List<int> peStrikes = [];
    for (int i = 0; i < 5; i++) {
      peStrikes.add(atm + (i * step)); // ATM, ATM+50, ATM+100...
    }
    peStrikes.sort();

    List<Map<String, dynamic>> resolved = [];

    // Resolve CE
    for (int strike in ceStrikes) {
      final match = await _searchStrike(uid, indexName, strike, 'CE');
      if (match != null) resolved.add(match);
    }

    // Resolve PE
    for (int strike in peStrikes) {
      final match = await _searchStrike(uid, indexName, strike, 'PE');
      if (match != null) resolved.add(match);
    }

    targetNotifier.value = resolved;
  }

  Future<Map<String, dynamic>?> _searchStrike(String uid, String index, int strike, String type) async {
    // Search Pattern: "NIFTY 25000 CE" or "SENSEX 85000 PE"
    final String query = '$index $strike $type';
    try {
      final res = await _apiService.searchScrip(userId: uid, searchText: query);
      if (res != null && res['stat'] == 'Ok' && res['values'] != null) {
        final List<dynamic> values = res['values'];
        for (var v in values) {
          final String tsym = v['tsym'].toString();
          // Basic validation
           if (v['optt'] == type || tsym.endsWith(type)) {
             // Subscribe
             _wsService.subscribeTouchline(v['exch'], v['token']);
             // Register with ExitStrategyService to IGNORE this token (so old strategy doesn't touch it)
             _exitService.excludeToken(v['token'].toString());
             
             // Fetch authoritative Lot Size (LS) & Price (LP) via Quote
             String contractLotSize = '1';
             String initialLp = '...';
             
             try {
               final quote = await _apiService.getQuote(userId: uid, exchange: v['exch'], token: v['token']);
               if (quote['stat'] == 'Ok') {
                 contractLotSize = quote['ls']?.toString() ?? '1';
                 initialLp = quote['lp']?.toString() ?? '...';
               }
             } catch (e) {
                debugPrint('Strategy930: Failed to fetch Quote for $tsym');
             }

             return {
               'strike': strike,
               'type': type,
               'tsym': tsym,
               'token': v['token'],
               'exch': v['exch'],
               'lp': initialLp, // Use fetched price
               'ls': contractLotSize, 
               'selected': false,
             };
           }
        }
      }
    } catch (e) {
      debugPrint('Strategy930: Error searching $query: $e');
      // Optional: Update status to show "Search Error" briefly?
    }
    return null;
  }

  void toggleSelection(List<Map<String, dynamic>> list, int index) {
    if (index >= 0 && index < list.length) {
      list[index]['selected'] = !list[index]['selected'];
      // Notify listeners
      if (list == niftyStrikes.value) niftyStrikes.notifyListeners(); 
      // Note: ValueNotifier check regarding identity might need reinstantiation or use notifyListeners if extended.
      // Since it's standard ValueNotifier, we need to set .value to trigger.
      if (list == niftyStrikes.value) {
          niftyStrikes.value = List.from(list);
      } else {
          sensexStrikes.value = List.from(list);
      }
      _saveState();
    }
  }

  void removeStrike(List<Map<String, dynamic>> list, int index) {
    if (index >= 0 && index < list.length) {
      final item = list[index];
      // Unsubscribe? Maybe keep it if reused, but better to unsubscribe to save bandwidth if deleted by user.
      _wsService.unsubscribeTouchline(item['exch'], item['token']);
      
      list.removeAt(index);
       if (list == niftyStrikes.value) {
          niftyStrikes.value = List.from(list);
      } else {
          sensexStrikes.value = List.from(list);
      }
      _saveState();
    }
  }

  Future<void> placeOrders(List<Map<String, dynamic>> targets) async {
     final String? uid = await _storageService.getUid();
     if (uid == null) return;
     
     statusMessage.value = 'Placing ${targets.length} orders...';
     
     for (var t in targets) {
       try {
         // Default quantity? The 9:30 strategy didn't specify lots.
         // We'll assume 1 lot for now or fetch lot size. 
         // Let's implement dynamic lot fetching in search or just hardcode '1' for validity 
         // BUT typically this app uses "Settings" for lots.
         // Let's grab lots from StorageService to be safe.
         
         final settings = await _storageService.getStrategySettings();
         // Use existing lot settings
         int userLots = (t['tsym'].toString().startsWith('NIFTY')) 
             ? (settings['niftyLotSize'] ?? 1) 
             : (settings['sensexLotSize'] ?? 1);
        
         // Use fetched Lot Size
         int contractSize = int.tryParse(t['ls']?.toString() ?? '1') ?? 1;
         
         // Fallback if LS is still 1 (maybe API failed)
         if (contractSize == 1) {
            contractSize = (t['tsym'].toString().startsWith('NIFTY')) ? 75 : 10;
         }

          await _apiService.placeOrder(
            userId: uid, 
            exchange: t['exch'], 
            tradingSymbol: t['tsym'], 
            quantity: (userLots * contractSize).toString(), // Dynamic Qty
            price: '0', 
            transactionType: 'B', 
            productType: 'M', 
            orderType: 'MKT',
            ret: 'DAY'
          );
       } catch (e) {
         debugPrint('Order Error: $e');
       }
     }
     statusMessage.value = 'Orders Placed.';
  }

  // Manual Triggers for Testing
  // Manual Triggers for Testing
  void manualCapture() => captureSpots();
  void manualFetch() => fetchStrikes();

  // Reset Logic for Testing
  Future<void> resetDay() async {
    _spotCapturedToday = false;
    _strikesFetchedToday = false;
    niftySpot.value = null;
    sensexSpot.value = null;
    niftyStrikes.value = [];
    sensexStrikes.value = [];
    statusMessage.value = 'Day Reset. Auto-trigger enabled.';
    exitStatusMap.value = {};
    _activeSLOrders.clear();
    _slLevels.clear();
    
    // Clear Persistence
    await _storageService.clearStrategy930Data();
  }
}
