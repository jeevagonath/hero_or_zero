import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../core/constants.dart';

class DashboardPlaceholderPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardPlaceholderPage({super.key, required this.userData});

  @override
  State<DashboardPlaceholderPage> createState() => _DashboardPlaceholderPageState();
}

class _DashboardPlaceholderPageState extends State<DashboardPlaceholderPage> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _niftyData = {'lp': '0.00', 'pc': '0.00', 'c': '0.00', 'o': '0.00'};
  Map<String, dynamic> _sensexData = {'lp': '0.00', 'pc': '0.00', 'c': '0.00', 'o': '0.00'};

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_apiService.userToken == null) {
        await _apiService.initToken();
      }
      
      final String uid = widget.userData['actid'] ?? '';
      final String token = _apiService.userToken ?? '';

      if (token.isEmpty || uid.isEmpty) {
        throw Exception('User authentication failed. Please log in again.');
      }

      // 1. Fetch initial quotes to get Open prices
      final niftyQuote = await _apiService.getQuote(userId: uid, exchange: 'NSE', token: '26000');
      final sensexQuote = await _apiService.getQuote(userId: uid, exchange: 'BSE', token: '1');

      setState(() {
        if (niftyQuote['stat'] == 'Ok') {
          _niftyData = {
            'lp': niftyQuote['lp'] ?? '0.00',
            'o': niftyQuote['o'] ?? '0.00',
            'c': niftyQuote['c'] ?? '0.00',
          };
          _updateCalculatedChange('NSE', '26000');
        }
        if (sensexQuote['stat'] == 'Ok') {
          _sensexData = {
            'lp': sensexQuote['lp'] ?? '0.00',
            'o': sensexQuote['o'] ?? '0.00',
            'c': sensexQuote['c'] ?? '0.00',
          };
          _updateCalculatedChange('BSE', '1');
        }
      });

      // 2. Connect WebSocket
      await _wsService.connect(
        userId: uid,
        userToken: token,
        accountId: uid,
      );

      // Subscribe to Nifty 50 and Sensex
      _wsService.subscribeTouchline('NSE', '26000');
      _wsService.subscribeTouchline('BSE', '1');

      // Listen for updates
      _wsSubscription = _wsService.messageStream.listen((data) {
        if (data['t'] == 'tk' || data['t'] == 'tf') {
          final String exchange = data['e'] ?? '';
          final String symToken = data['tk'] ?? '';

          setState(() {
            if (exchange == 'NSE' && symToken == '26000') {
              _niftyData = {
                'lp': data['lp'] ?? _niftyData['lp'],
                'o': data['o'] ?? _niftyData['o'],
                'c': data['c'] ?? _niftyData['c'],
              };
              _updateCalculatedChange('NSE', '26000');
            } else if (exchange == 'BSE' && symToken == '1') {
              _sensexData = {
                'lp': data['lp'] ?? _sensexData['lp'],
                'o': data['o'] ?? _sensexData['o'],
                'c': data['c'] ?? _sensexData['c'],
              };
              _updateCalculatedChange('BSE', '1');
            }
          });
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateCalculatedChange(String exchange, String token) {
    var data = (exchange == 'NSE' && token == '26000') ? _niftyData : _sensexData;
    
    double lp = double.tryParse(data['lp']?.replaceAll(',', '') ?? '0') ?? 0;
    double open = double.tryParse(data['o']?.replaceAll(',', '') ?? '0') ?? 0;
    
    if (open > 0) {
      double absChange = lp - open;
      double pc = (absChange / open) * 100;
      
      data['c_calc'] = absChange.toStringAsFixed(2);
      data['pc_calc'] = pc.toStringAsFixed(2);
    } else {
      data['c_calc'] = '0.00';
      data['pc_calc'] = '0.00';
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    // We don't disconnect WebSocket here as other pages might need it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Market Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Column(
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _initDashboard, child: const Text('Retry'))
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildIndexCard(
                      title: 'NIFTY 50',
                      data: _niftyData,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildIndexCard(
                      title: 'SENSEX',
                      data: _sensexData,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexCard({required String title, required Map<String, dynamic> data}) {
    final String ltp = data['lp'] ?? '0.00';
    final String change = data['pc_calc'] ?? '0.00';
    final String absChange = data['c_calc'] ?? '0.00';
    final bool isPositive = !change.startsWith('-');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ltp,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isPositive ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Text(
                '$absChange ($change%)',
                style: TextStyle(
                  fontSize: 12,
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: [
            _buildStatItem('Open Positions', '0', Icons.assessment_outlined),
            _buildStatItem('Today\'s P&L', '₹0.00', Icons.account_balance_wallet_outlined),
            _buildStatItem('Margin Used', '₹0.00', Icons.pie_chart_outline),
            _buildStatItem('Orders', '0', Icons.shopping_cart_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
