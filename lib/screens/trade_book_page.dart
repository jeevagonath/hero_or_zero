import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchTrades,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchTrades,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _trades.isEmpty
              ? const Center(
                  child: Text(
                    'No trades in this session',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
    final typeColor = isBuy ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trade['tsym'] ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isBuy ? 'BUY' : 'SELL',
                          style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${trade['exch']} | ${trade['prd']}',
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'FILLED',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    trade['fltm'] ?? '',
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDataPoint('Fill Qty', trade['flqty'] ?? '0'),
              _buildDataPoint('Fill Price', trade['flprc'] ?? '0'),
              _buildDataPoint('Order No', trade['norenordno'] ?? 'N/A'),
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
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
