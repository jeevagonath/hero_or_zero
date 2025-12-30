import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'pnl_service.dart';
import 'pnl_service.dart';

class ExitStrategyService {
  static final ExitStrategyService _instance = ExitStrategyService._internal();
  factory ExitStrategyService() => _instance;
  ExitStrategyService._internal();

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final PnLService _pnlService = PnLService();

  Future<void> _syncStateWithOpenOrders() async {
    try {
       final String? uid = await _storageService.getUid();
       if (uid == null) return;

       final result = await _apiService.getOrderBook(userId: uid);
       if (result['stat'] == 'Ok' && result['orders'] != null) {
          final List<dynamic> orders = result['orders'];
          for (var o in orders) {
             final status = o['status']?.toString().toLowerCase() ?? '';
             // Look for Open/Trigger Pending SL-LMT orders
             if ((status.contains('open') || status.contains('pending') || status.contains('trigger')) && 
                 o['remarks'] != 'Hard SL Exit') { // Optional filter if you tag orders
                
                final String token = o['token'];
                if (_excludedTokens.contains(token)) continue; 
                
                // We found an active strategy order. Reconstruct tracker.
                final double prc = double.tryParse(o['prc'] ?? '0') ?? 0;
                // We don't know exact 'buyPrice' easily, but we can assume from order price / 2
                // Or just init with safer defaults to enable Trailing.
                
                // If we don't know the Buy Price, we can't easily calculate if it SHOULD trail, 
                // but we can at least enable modification.
                
                _activeExits[token] = {
                   'isExitPlaced': true,
                   'orderNo': o['norenordno'],
                   'savedPrice': 0.0, // Will update on next tick
                   'buyPrice': prc / 2.0, // Best guess or fetch from position
                   'currentOrderPrice': prc,
                };
                print('ExitStrategyService: Restored active order ${o['norenordno']} for $token');
             }
          }
       }
    } catch (e) {
      print('ExitStrategyService: Sync Error: $e');
    }
  }

  // State Tracking
  // Key: Token
  // Value: { 'orderNo': String, 'savedPrice': double, 'isExitPlaced': bool, 'buyPrice': double }
  // State Tracking
  // Key: Token
  // Value: { 'orderNo': String, 'savedPrice': double, 'isExitPlaced': bool, 'buyPrice': double }
  final Map<String, Map<String, dynamic>> _activeExits = {};

  // Tokens to ignore (e.g., managed by other strategies like 9:30)
  final Set<String> _excludedTokens = {};
  // Tokens currently placing order to prevent race conditions
  final Set<String> _placingOrders = {};

  void excludeToken(String token) {
    _excludedTokens.add(token);
  }

  void includeToken(String token) {
    _excludedTokens.remove(token);
  }
  
  StreamSubscription? _positionSubscription;
  bool _isMonitoring = false;
  double _exitTriggerBuffer = 0.5;
  double _niftyTrailingStep = 10.0;
  double _niftyTrailingIncrement = 8.0;
  double _sensexTrailingStep = 20.0;
  double _sensexTrailingIncrement = 15.0;

  Future<void> init() async {
    await _loadSettings();
    await _syncStateWithOpenOrders(); // Restore state from API
    _startMonitoring();
  }

  Future<void> _loadSettings() async {
    final settings = await _storageService.getStrategySettings();
    _exitTriggerBuffer = settings['exitTriggerBuffer'] ?? 0.5;
    _niftyTrailingStep = settings['niftyTrailingStep'] ?? 10.0;
    _niftyTrailingIncrement = settings['niftyTrailingIncrement'] ?? 8.0;
    _sensexTrailingStep = settings['sensexTrailingStep'] ?? 20.0;
    _sensexTrailingIncrement = settings['sensexTrailingIncrement'] ?? 15.0;
    print('ExitStrategyService Loaded: Buffer=$_exitTriggerBuffer, NiftyTrace=$_niftyTrailingStep/$_niftyTrailingIncrement, SensexTrace=$_sensexTrailingStep/$_sensexTrailingIncrement');
  }

  void _startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    // Listen to position updates from PnLService
    _positionSubscription = _pnlService.positions.addListener(() {
        _checkPositions(_pnlService.positions.value);
    }) as StreamSubscription?;
    
    // Also listen manually if needed, but valueNotifier listener is good.
    // Actually ValueNotifier doesn't return a StreamSubscription directly in adds.
    // We should use the addListener method.
    _pnlService.positions.addListener(_onPositionsUpdate);
    print('ExitStrategyService: Monitoring Started');
  }

  void _onPositionsUpdate() {
    _checkPositions(_pnlService.positions.value);
  }

  void _checkPositions(List<Map<String, dynamic>> positions) {
    for (var pos in positions) {
      _processPosition(pos);
    }
  }

  Future<void> _processPosition(Map<String, dynamic> pos) async {
    final String token = pos['token']?.toString() ?? '';
    if (token.isEmpty) return;
    
    // Skip if excluded (managed by another strategy)
    if (_excludedTokens.contains(token)) return;

    final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0;
    
    // If position is closed (qty 0), remove from tracking
    if (netqty == 0) {
      if (_activeExits.containsKey(token)) {
        final tracker = _activeExits[token]!;
        final String? ordNo = tracker['orderNo'];
        
        if (ordNo != null && ordNo.isNotEmpty) {
           print('ExitStrategyService: Position closed. Cancelling SL Order $ordNo');
           final String? uid = await _storageService.getUid();
           if (uid != null) {
              await _apiService.cancelOrder(userId: uid, norenordno: ordNo);
           }
        }

        print('ExitStrategyService: Position closed for $token. Removing tracker.');
        _activeExits.remove(token);
      }
      return;
    }

    // Convert string values to double
    final double lp = double.tryParse(pos['lp']?.toString() ?? '0') ?? 0.0;
    // For Buy Average, use netavgprc if netqty > 0. 
    // If we are selling (netqty < 0), logic might be different but requirement implies "Buy Price" -> Long positions.
    // Assuming Long Strategy for now as per "Hero or Zero" context (Option Buying).
    final double avgPrice = double.tryParse(pos['netavgprc']?.toString() ?? '0') ?? 0.0;

    if (avgPrice <= 0 || lp <= 0) return;

    // Initialize tracker if missing
    if (!_activeExits.containsKey(token)) {
      _activeExits[token] = {
        'isExitPlaced': false,
        'orderNo': null,
        'savedPrice': 0.0,
        'buyPrice': avgPrice,
      };
    }

    final tracker = _activeExits[token]!;
    final bool isExitPlaced = tracker['isExitPlaced'] ?? false;

    if (!isExitPlaced) {
      // PLACEMENT LOGIC
      // Trigger: LTP >= 2.5 * avgPrice
      if (lp >= (2.5 * avgPrice)) {
         if (_placingOrders.contains(token)) return; // Prevent concurrent placement
         _placingOrders.add(token);
         
         print('ExitStrategyService: Trigger MET for ${pos['tsym']} (LTP: $lp, Buy: $avgPrice). Placing Exit Order...');
         await _placeExitOrder(pos, avgPrice, lp);
         
         _placingOrders.remove(token);
      }
    } else {
      // MODIFICATION LOGIC
      await _checkAndTrailing(pos, tracker, lp);
    }
  }

  Future<void> _placeExitOrder(Map<String, dynamic> pos, double buyPrice, double currentLc) async {
    final String? uid = await _storageService.getUid();
    if (uid == null) return;

    final String token = pos['token'];
    final double targetPrice = 2.0 * buyPrice;
    final double triggerPrice = targetPrice + _exitTriggerBuffer;
    final String qty = pos['netqty'].toString(); // Should be positive for LONG
    
    // Safety check: ensure we are selling
    if (double.parse(qty) <= 0) return; 

    // Place SL-LMT Order
    // Price: 2.0 * BuyPrice
    // Trigger: Price + Buffer
    // Qty: Open Qty
    
    final result = await _apiService.placeOrder(
      userId: uid,
      exchange: pos['exch'],
      tradingSymbol: pos['tsym'],
      quantity: qty,
      price: targetPrice.toStringAsFixed(2),
      triggerPrice: triggerPrice.toStringAsFixed(2),
      transactionType: 'S',
      productType: 'M', // Margin/NRML as per strategy
      orderType: 'SL-LMT',
    );

    if (result['stat'] == 'Ok') {
      final String orderNo = result['norenordno'] ?? '';
      print('ExitStrategyService: Exit Order Placed. OrderNo: $orderNo');
      
      _activeExits[token] = {
        'isExitPlaced': true,
        'orderNo': orderNo,
        'savedPrice': currentLc, // Save CURRENT MARKET PRICE as savedPrice
        'buyPrice': buyPrice,
        'currentOrderPrice': targetPrice, // Store initial order price
      };
    } else {
      print('ExitStrategyService: Failed to place exit order: ${result['emsg']}');
    }
  }

  Future<void> _checkAndTrailing(Map<String, dynamic> pos, Map<String, dynamic> tracker, double currentLp) async {
    final String token = pos['token'];
    final String orderNo = tracker['orderNo'];
    final double savedPrice = tracker['savedPrice'];
    final String exch = pos['exch'] ?? '';
    final String tsym = pos['tsym'] ?? '';

    if (orderNo.isEmpty) return;

    bool shouldModify = false;
    double modificationAmount = 0.0; // Amount to increase Price by

    // NIFTY: If LTP >= SavedPrice + Step -> Modify + Increment
    if (tsym.startsWith('NIFTY')) {
      if (currentLp >= (savedPrice + _niftyTrailingStep)) {
        shouldModify = true;
        modificationAmount = _niftyTrailingIncrement;
      }
    } 
    // SENSEX: If LTP >= SavedPrice + Step -> Modify + Increment
    else if (tsym.startsWith('SENSEX')) {
      if (currentLp >= (savedPrice + _sensexTrailingStep)) {
        shouldModify = true;
        modificationAmount = _sensexTrailingIncrement;
      }
    }

    if (shouldModify) {
      print('ExitStrategyService: Trailing Condition Met for $tsym. (LTP: $currentLp, Saved: $savedPrice). Modifying...');
      
      // Fetch current order details to get current Price? 
      // Plan says: Modify Order Price +8/+14. 
      // We need to know the CURRENT ORDER PRICE. 
      // We can track it, or fetch it. Tracking is faster.
      // But wait... we rely on "SavedPrice" for the Trigger condition, but modify "Order Price".
      // Let's assume we need to fetch the order book to get the current price to be safe, 
      // OR we can store 'lastOrderPrice' in our tracker. 
      // Initial Order Price was 2.0 * BuyPrice.
      
      // Let's enhance tracker to store `currentOrderPrice`
      double currentOrderPrice = tracker['currentOrderPrice'] ?? (2.0 * tracker['buyPrice']);
      
      // New Price
      double newOrderPrice = currentOrderPrice + modificationAmount;
      double newTriggerPrice = newOrderPrice + _exitTriggerBuffer;

      final String? uid = await _storageService.getUid();
      if (uid == null) return;

      final result = await _apiService.modifyOrder(
        userId: uid,
        norenordno: orderNo,
        exchange: exch,
        tradingSymbol: tsym,
        quantity: pos['netqty'].toString(), // Assume full qty
        price: newOrderPrice.toStringAsFixed(2),
        triggerPrice: newTriggerPrice.toStringAsFixed(2),
        orderType: 'SL-LMT',
        productType: 'M',
      );

      if (result['stat'] == 'Ok') {
        print('ExitStrategyService: Order Modified Successfully. New Price: $newOrderPrice');
        
        // Update Tracker
        _activeExits[token]!['savedPrice'] = currentLp; // Update SavedPrice to New LTP
        _activeExits[token]!['currentOrderPrice'] = newOrderPrice;
      } else {
         print('ExitStrategyService: Modification Failed: ${result['emsg']}');
      }
    }
  }

  void stop() {
    _pnlService.positions.removeListener(_onPositionsUpdate);
    _positionSubscription?.cancel();
    _isMonitoring = false;
  }
}
