import 'package:flutter/material.dart';
import '../services/pnl_service.dart';

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  final PnLService _pnlService = PnLService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPnLOverview(),
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _pnlService.positions,
            builder: (context, posList, child) {
              if (posList.isEmpty) {
                return const Center(
                  child: Text(
                    'No open positions',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: posList.length,
                itemBuilder: (context, index) {
                  return _buildPositionCard(posList[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPnLOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: _pnlService.totalPnL,
        builder: (context, totalPnL, child) {
          final pnlColor = totalPnL >= 0 ? Colors.greenAccent : Colors.redAccent;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Positions', _pnlService.positions.value.length.toString()),
                  _buildMiniStat(
                    'Total M2M', 
                    '₹${totalPnL.toStringAsFixed(2)}',
                    valueColor: pnlColor,
                  ),
                  _buildMiniStat('Realized', '₹${_calculateTotalRealized().toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmAllDialog(context),
                  icon: const Icon(Icons.close_fullscreen, size: 18, color: Colors.white),
                  label: const Text('CLOSE ALL POSITIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Close All Positions?', style: TextStyle(color: Colors.white)),
        content: const Text('This will place market orders to exit all open positions.', style: TextStyle(color: Colors.blueGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pnlService.squareOffAll('Manual Close All');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('CLOSE ALL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  double _calculateTotalRealized() {
    double total = 0.0;
    for (var pos in _pnlService.positions.value) {
      total += double.tryParse(pos['rpnl']?.toString() ?? '0') ?? 0.0;
    }
    return total;
  }

  Widget _buildMiniStat(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value, 
          style: TextStyle(
            color: valueColor ?? Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> pos) {
    final double netqty = double.tryParse(pos['netqty']?.toString() ?? '0') ?? 0.0;
    final double lp = double.tryParse(pos['lp']?.toString() ?? '0') ?? 0.0;
    final double avg = double.tryParse(pos['netavgprc']?.toString() ?? '0') ?? 0.0;
    final double prcftr = double.tryParse(pos['prcftr']?.toString() ?? '1') ?? 1.0;
    final double rpnl = double.tryParse(pos['rpnl']?.toString() ?? '0') ?? 0.0;
    
    final double urmtom = netqty * (lp - avg) * prcftr;
    final double totalPnL = rpnl + urmtom;
    final pnlColor = totalPnL >= 0 ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pos['tsym'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pos['exch']} | ${pos['prd']}',
                      style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${totalPnL.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: pnlColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'P&L',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDataPoint('Qty', netqty.toInt().toString()),
              _buildDataPoint('Avg', avg.toStringAsFixed(2)),
              _buildDataPoint('LTP', lp.toStringAsFixed(2), color: Colors.blueAccent),
            ],
          ),
          if (netqty != 0) ...[
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Divider(color: Colors.white10, height: 1),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showConfirmSingleDialog(context, pos),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('CLOSE POSITION', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showConfirmSingleDialog(BuildContext context, Map<String, dynamic> position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Close ${position['tsym']}?', style: const TextStyle(color: Colors.white)),
        content: const Text('This will place a market order to exit this position.', style: TextStyle(color: Colors.blueGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pnlService.squareOffSingle(position);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPoint(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
