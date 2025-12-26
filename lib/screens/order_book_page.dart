import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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
    if (s.contains('complete')) return const Color(0xFF00D97E);
    if (s.contains('reject') || s.contains('cancel')) return const Color(0xFFFF5F5F);
    if (s.contains('trigger') || s.contains('open') || s.contains('pending')) return Colors.orangeAccent;
    return Colors.blueGrey;
  }

  String _formatOrderTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'N/A';
    try {
      // Expected format: dd-MM-yyyy HH:mm:ss
      final parts = timeStr.split(' ');
      if (parts.length != 2) return timeStr;

      final dateParts = parts[0].split('-');
      if (dateParts.length != 3) return timeStr;

      final timeParts = parts[1].split(':');
      if (timeParts.length < 2) return timeStr;

      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = dateParts[2]; // Typically full year or last 2 digits

      final hh = int.parse(timeParts[0]);
      final mm = timeParts[1];
      
      final String amPm = hh >= 12 ? 'PM' : 'AM';
      final int displayHh = hh > 12 ? hh - 12 : (hh == 0 ? 12 : hh);

      return '$day ${months[month - 1]} \'$year, $displayHh:$mm $amPm';
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
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
                      onPressed: _fetchOrders,
                      label: 'Retry Fetch',
                      icon: Icons.refresh_rounded,
                    ),
                  ],
                ),
              )
            : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: Colors.blueGrey.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'Empty Session History',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(_orders[index]);
                  },
                ),
      ),
    );
  }

  Future<void> _cancelOrder(String norenordno) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Cancel Order?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to cancel this order?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO', style: TextStyle(color: Colors.blueGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES, CANCEL', style: TextStyle(color: Color(0xFFFF5F5F))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final String? uid = _apiService.userId;
    if (uid == null) return;

    setState(() => _isLoading = true);

    final result = await _apiService.cancelOrder(userId: uid, norenordno: norenordno);
    
    if (mounted) {
      if (result['stat'] == 'Ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order Cancelled Successfully')),
        );
        _fetchOrders(); // Refresh list
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: ${result['emsg'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final statusColor = _getStatusColor(order['status']);
    final isBuy = order['trantype'] == 'B';
    final typeColor = isBuy ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);
    
    final s = order['status']?.toString().toLowerCase() ?? '';
    final bool isCancellable = s.contains('open') || s.contains('pending') || s.contains('trigger');

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
                      order['tsym'] ?? 'N/A',
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
                          '${order['exch']} | ${order['prd']}',
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order['status'] ?? 'UNKNOWN',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatOrderTime(order['norentm']),
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
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
              _buildDataPoint('QUANTITY', '${order['fillshares'] ?? '0'}/${order['qty']}'),
              _buildDataPoint('PRICE', order['prc'] ?? '0'),
              _buildDataPoint('AVG. PRICE', order['avgprc'] ?? '0'),
            ],
          ),
          if (order['status'] == 'REJECTED' && order['rejreason'] != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5F5F).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF5F5F).withOpacity(0.1)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFFF5F5F)),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                        'Reason: ${order['rejreason']}',
                        style: const TextStyle(color: Color(0xFFFF5F5F), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                   ),
                ],
              ),
            ),
          ],
          if (isCancellable) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _cancelOrder(order['norenordno'] ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5F5F).withOpacity(0.1),
                  foregroundColor: const Color(0xFFFF5F5F),
                  elevation: 0,
                  side: BorderSide(color: const Color(0xFFFF5F5F).withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('CANCEL ORDER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
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
