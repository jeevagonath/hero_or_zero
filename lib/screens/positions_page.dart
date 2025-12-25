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
          final color = totalPnL >= 0 ? Colors.greenAccent : Colors.redAccent;
          return Column(
            children: [
              const Text(
                'Total Unrealized M2M',
                style: TextStyle(color: Colors.blueGrey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${totalPnL.toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Positions', _pnlService.positions.value.length.toString()),
                  _buildMiniStat('Realized P&L', '₹${_calculateTotalRealized().toStringAsFixed(2)}'),
                ],
              ),
            ],
          );
        },
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

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
