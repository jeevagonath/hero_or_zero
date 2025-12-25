import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../services/pnl_service.dart';
import 'package:intl/intl.dart';

class StrategyPage extends StatefulWidget {
  const StrategyPage({super.key});

  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final WebSocketService _wsService = WebSocketService();

  String _currentTime = '';
  String? _capturedSpotPrice;
  DateTime? _capturedAt;
  bool _isStrategyDay = false;
  String _targetIndex = 'NIFTY'; // NIFTY or SENSEX
  bool _isResolving = false;
  
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _strikes = [];
  bool _isLoading = true;
  Timer? _timer;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndInit();
    _startClock();
    _startWsBinding();
  }

  void _startWsBinding() {
    _wsSubscription = _wsService.messageStream.listen((message) {
      if (message['t'] == 't' && message['lp'] != null) {
        final token = message['tk'];
        final lp = message['lp'];
        _updateStrikePrice(token, lp);
      }
    });
  }

  void _updateStrikePrice(String token, String lp) {
    bool updated = false;
    for (var strike in _strikes) {
      if (strike['token'] == token) {
        if (strike['lp'] != lp) {
          strike['lp'] = lp;
          updated = true;
        }
      }
    }
    if (updated) {
      setState(() {});
    }
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(now);
      });
      _checkStrategyCondition(now);
    });
  }

  Future<void> _loadSettingsAndInit() async {
    final settings = await _storageService.getStrategySettings();
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);

    setState(() {
      _settings = settings;
      if (dayName == settings['niftyDay']) {
        _isStrategyDay = true;
        _targetIndex = 'NIFTY';
      } else if (dayName == settings['sensexDay']) {
        _isStrategyDay = true;
        _targetIndex = 'SENSEX';
      } else {
        _isStrategyDay = false;
      }
      _isLoading = false;
    });
  }

  void _checkStrategyCondition(DateTime now) async {
    if (!_isStrategyDay || _capturedSpotPrice != null) return;

    // Target time: 13:15 (1:15 PM)
    if (now.hour == 13 && now.minute == 15 && now.second == 0) {
      _captureSpotPrice();
    }
  }

  void _captureSpotPrice() async {
    try {
      final String uid = _apiService.userId ?? '';
      final String exchange = _targetIndex == 'NIFTY' ? 'NSE' : 'BSE';
      final String token = _targetIndex == 'NIFTY' ? '26000' : '1';

      final quote = await _apiService.getQuote(userId: uid, exchange: exchange, token: token);
      
      if (quote['stat'] == 'Ok') {
        final double spot = double.tryParse(quote['lp']?.replaceAll(',', '') ?? '0') ?? 0;
        if (spot > 0) {
          setState(() {
            _capturedSpotPrice = spot.toStringAsFixed(2);
            _capturedAt = DateTime.now();
          });
          _generateAndResolveStrikes(spot);
        }
      }
    } catch (e) {
      print('Error capturing spot price: $e');
    }
  }

  Future<void> _generateAndResolveStrikes(double spot) async {
    setState(() => _isResolving = true);
    final double interval = _targetIndex == 'NIFTY' ? 50 : 100;
    double baseStrike = (spot / interval).floorToDouble() * interval;

    final List<Map<String, dynamic>> tempStrikes = [];
    
    // PE Options
    tempStrikes.add({'strike': baseStrike, 'type': 'P'});
    tempStrikes.add({'strike': baseStrike - interval, 'type': 'P'});

    // CE Options
    tempStrikes.add({'strike': baseStrike + interval, 'type': 'C'});
    tempStrikes.add({'strike': baseStrike + (interval * 2), 'type': 'C'});

    final String exchange = _targetIndex == 'NIFTY' ? 'NFO' : 'BFO';
    final String uid = _apiService.userId ?? '';

    List<Map<String, dynamic>> resolvedStrikes = [];

    for (var s in tempStrikes) {
      // Search for something like "NIFTY25DEC26650PE" or similar
      // Actually, Shoonya search usually needs just the strike and instrument
      final String searchText = '${_targetIndex} ${s['strike'].toInt()} ${s['type']}';
      
      try {
        final results = await _apiService.searchScrip(userId: uid, searchText: searchText);
        if (results['stat'] == 'Ok' && results['values'] != null) {
          // Filter for the specific exchange (NFO/BFO) and ensure it's the correct strike/type
          final List values = results['values'];
          var bestMatch = values.firstWhere(
            (v) => v['exch'] == exchange && 
                   v['tsym'].toString().endsWith('${s['type']}'),
            orElse: () => null
          );

          if (bestMatch != null) {
            resolvedStrikes.add({
              'strike': s['strike'],
              'type': s['type'] == 'P' ? 'PE' : 'CE',
              'token': bestMatch['token'],
              'tsym': bestMatch['tsym'],
              'exch': bestMatch['exch'],
              'selected': true,
              'lp': '...',
            });
            // Subscribe via WebSocket
            _wsService.subscribeTouchline(exchange, bestMatch['token']);
          }
        }
      } catch (e) {
        print('Error resolving strike $searchText: $e');
      }
    }

    setState(() {
      _strikes = resolvedStrikes;
      _isResolving = false;
    });
  }

  Future<void> _placeOrders() async {
    final String uid = _apiService.userId ?? '';
    final int lotSize = _targetIndex == 'NIFTY' ? _settings['niftyLotSize'] : _settings['sensexLotSize'];

    int successCount = 0;
    final List<Map<String, dynamic>> selectedStrikes = _strikes.where((s) => s['selected']).toList();

    if (selectedStrikes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No strikes selected')));
        return;
    }

    for (var strike in selectedStrikes) {
      try {
        final response = await _apiService.placeOrder(
          userId: uid,
          exchange: strike['exch'],
          tradingSymbol: strike['tsym'],
          quantity: lotSize.toString(),
          price: '0', // Market order
          transactionType: 'B',
          productType: 'M', // MIS
          orderType: 'MKT',
          ret: 'DAY',
        );

        if (response['stat'] == 'Ok') {
          successCount++;
        }
      } catch (e) {
        print('Error placing order for ${strike['tsym']}: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully placed $successCount orders')),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSubscription?.cancel();
    // Unsubscribe from strikes
    final String exchange = _targetIndex == 'NIFTY' ? 'NFO' : 'BFO';
    for (var strike in _strikes) {
      if (strike['token'] != null) {
        _wsService.unsubscribeTouchline(exchange, strike['token']);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildExitPlanSection(),
          const SizedBox(height: 32),
          if (_capturedSpotPrice != null) ...[
            if (_isResolving)
              const Center(child: Text('Resolving specific contracts...', style: TextStyle(color: Colors.blueGrey)))
            else ...[
              _buildStrikesSection(),
              const SizedBox(height: 32),
              _buildPlaceOrderButton(),
            ]
          ] else
            _buildWaitingSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Strategy: $_targetIndex Recovery',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              Text(
                _currentTime,
                style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Strategy Day', _isStrategyDay ? 'TODAY' : 'Not Active', isHighlighted: _isStrategyDay),
          _buildInfoRow('Capture Time', '13:15:00'),
          if (_capturedSpotPrice != null)
            _buildInfoRow('Spot Captured', '₹$_capturedSpotPrice', isHighlighted: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          Text(
            value,
            style: TextStyle(
              color: isHighlighted ? Colors.greenAccent : Colors.white,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingSection() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.timer_outlined, size: 64, color: Colors.blueGrey),
          const SizedBox(height: 16),
          Text(
            _isStrategyDay 
                ? 'Waiting for 1:15 PM capture...' 
                : 'Strategy inactive. Next run on ${_settings['niftyDay']}/${_settings['sensexDay']}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
          if (_settings['showTestButton'] ?? true) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _captureSpotPrice,
              child: const Text('Test Capture Now'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStrikesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Strike Prices',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ...List.generate(_strikes.length, (index) {
          final s = _strikes[index];
          final isCall = s['type'] == 'CE';
          return CheckboxListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${s['tsym'] ?? (s['strike'].toString() + ' ' + s['type'])}',
                  style: TextStyle(
                    color: isCall ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${s['lp'] ?? '0.00'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            value: s['selected'],
            onChanged: (val) => setState(() => _strikes[index]['selected'] = val),
            activeColor: Colors.blueAccent,
            subtitle: Text(
              isCall ? 'OTM Call Option' : 'OTM Put Option',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExitPlanSection() {
    final PnLService pnlService = PnLService();

    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: pnlService.exitStatus,
      builder: (context, statusMap, child) {
        final activeTokens = statusMap.keys.toList();
        if (activeTokens.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Strategy Exit Plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive grid: 1 column for mobile, 2 for tablet/larger
                int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
                double childAspectRatio = constraints.maxWidth > 600 ? 2.5 : 3.0;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: activeTokens.length,
                  itemBuilder: (context, index) {
                    final token = activeTokens[index];
                    final status = statusMap[token];
                    return _buildExitCard(status);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildExitCard(Map<String, dynamic> status) {
    final tsl = status['tslPerLot'] ?? -999999.0;
    final peak = status['peakProfitPerLot'] ?? 0.0;
    final tsym = status['tsym'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tsym,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildExitStat('Peak Profit', '₹${peak.toStringAsFixed(2)}'),
              _buildExitStat(
                'Trailing SL', 
                tsl == -999999.0 ? 'Pending' : '₹${tsl.toStringAsFixed(2)}',
                color: tsl == -999999.0 ? Colors.blueGrey : Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExitStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _placeOrders,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'PLACE ORDER',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
