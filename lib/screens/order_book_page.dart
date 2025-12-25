import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OrderBookPage extends StatefulWidget {
  const OrderBookPage({super.key});

  @override
  State<OrderBookPage> createState() => _OrderBookPageState();
}

class _OrderBookPageState extends State<OrderBookPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
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

    final result = await _apiService.getOrderBook(userId: uid);
    
    if (mounted) {
      setState(() {
        if (result['stat'] == 'Ok') {
          _orders = result['orders'] ?? [];
        } else if (result['emsg']?.toString().toLowerCase().contains('no data') ?? false) {
          _orders = [];
        } else {
          _errorMessage = result['emsg'] ?? 'Failed to fetch order book';
        }
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.blueGrey;
    final s = status.toLowerCase();
    if (s.contains('complete')) return Colors.greenAccent;
    if (s.contains('reject') || s.contains('cancel')) return Colors.redAccent;
    if (s.contains('trigger') || s.contains('open') || s.contains('pending')) return Colors.orangeAccent;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
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
                      onPressed: _fetchOrders,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _orders.isEmpty
              ? const Center(
                  child: Text(
                    'No orders in this session',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(_orders[index]);
                  },
                ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final statusColor = _getStatusColor(order['status']);
    final isBuy = order['trantype'] == 'B';
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
                    order['tsym'] ?? 'N/A',
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
                        '${order['exch']} | ${order['prd']}',
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order['status'] ?? 'UNKNOWN',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    order['ordenttm'] ?? '',
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
              _buildDataPoint('Qty', '${order['fillshares']}/${order['qty']}'),
              _buildDataPoint('Price', order['prc'] ?? '0'),
              _buildDataPoint('Avg. Price', order['avgprc'] ?? '0'),
            ],
          ),
          if (order['status'] == 'REJECTED' && order['rejreason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Reason: ${order['rejreason']}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
          ],
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
