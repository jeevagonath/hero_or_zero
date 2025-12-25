import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class TradeBookPage extends StatefulWidget {
  const TradeBookPage({super.key});

  @override
  State<TradeBookPage> createState() => _TradeBookPageState();
}

class _TradeBookPageState extends State<TradeBookPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _trades = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrades();
  }

  Future<void> _fetchTrades() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String? uid = _apiService.userId;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User ID not found. Please log in again.';
      });
      return;
    }

    final result = await _apiService.getTradeBook(userId: uid);
    
    if (mounted) {
      setState(() {
        if (result['stat'] == 'Ok') {
          _trades = result['trades'] ?? [];
        } else if (result['emsg']?.toString().toLowerCase().contains('no data') ?? false) {
          _trades = [];
        } else {
          _errorMessage = result['emsg'] ?? 'Failed to fetch trade book';
        }
        _isLoading = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      body: RefreshIndicator(
        onRefresh: _fetchTrades,
        backgroundColor: const Color(0xFF161B22),
        color: const Color(0xFF4D96FF),
        child: _isLoading 
          ? const Center(child: SpinKitPulse(color: Color(0xFF4D96FF)))
          : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: const Color(0xFFFF5F5F).withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF5F5F), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    NeonButton(
                      onPressed: _fetchTrades,
                      label: 'Retry Fetch',
                      icon: Icons.refresh_rounded,
                    ),
                  ],
                ),
              )
            : _trades.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: Colors.blueGrey.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'No Trades Executed Today',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _trades.length,
                  itemBuilder: (context, index) {
                    return _buildTradeCard(_trades[index]);
                  },
                ),
      ),
    );
  }

  Widget _buildTradeCard(Map<String, dynamic> trade) {
    final isBuy = trade['trantype'] == 'B';
    final typeColor = isBuy ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trade['tsym'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isBuy ? 'BUY' : 'SELL',
                            style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${trade['exch']} | ${trade['prd']}',
                          style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D97E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'EXECUTED',
                      style: TextStyle(
                        color: Color(0xFF00D97E),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trade['fltm'] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDataPoint('FILLED QTY', trade['flqty'] ?? '0'),
              _buildDataPoint('FILL PRICE', trade['flprc'] ?? '0'),
              _buildDataPoint('ORDER ID', trade['norenordno'] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataPoint(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8), 
            fontSize: 14, 
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
