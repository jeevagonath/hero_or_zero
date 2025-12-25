import 'package:flutter/material.dart';
import '../services/pnl_service.dart';
import '../widgets/glass_widgets.dart';
import 'dart:ui';

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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.blueGrey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'No Active Positions',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: _pnlService.totalPnL,
        builder: (context, totalPnL, child) {
          final pnlColor = totalPnL >= 0 ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);
          return Column(
            children: [
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                opacity: 0.05,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat('OPEN ROWS', _pnlService.positions.value.length.toString()),
                    _buildMiniStat(
                      'TOTAL UNREALIZED', 
                      '₹${totalPnL.toStringAsFixed(2)}',
                      valueColor: pnlColor,
                    ),
                    _buildMiniStat('REALIZED', '₹${_calculateTotalRealized().toStringAsFixed(2)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: NeonButton(
                  onPressed: () {
                    if (_pnlService.positions.value.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No Active Positions to Exit'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      return;
                    }
                    _showConfirmAllDialog(context);
                  },
                  icon: Icons.close_rounded,
                  label: 'EXIT ALL RUNNING POSITIONS',
                  color: const Color(0xFFFF5F5F),
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
      builder: (context) => GlassConfirmationDialog(
        title: 'Confirm Portfolio Exit',
        isDestructive: true,
        confirmLabel: 'CLOSE ALL',
        items: const [
          {'label': 'Action', 'value': 'SQUARE OFF ALL'},
          {'label': 'Order Type', 'value': 'MARKET'},
        ],
        onConfirm: () async {
          final int count = await _pnlService.squareOffAll('Manual Close All');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(count > 0 ? '$count Exit Orders Placed' : 'No Active Positions to Exit'),
                backgroundColor: count > 0 ? const Color(0xFF00D97E) : Colors.orangeAccent,
              ),
            );
          }
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

  Widget _buildMiniStat(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          value, 
          style: TextStyle(
            color: valueColor ?? Colors.white, 
            fontWeight: FontWeight.w900,
            fontSize: 14,
            fontFamily: 'monospace',
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
    final pnlColor = totalPnL >= 0 ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      opacity: 0.06,
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
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${pos['exch']} | ${pos['prd']}',
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: pnlColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalPnL.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: pnlColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'P&L',
                      style: TextStyle(color: pnlColor.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
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
              _buildDataPoint('QUANTITY', netqty.toInt().toString()),
              _buildDataPoint('AVG PRICE', '₹${avg.toStringAsFixed(2)}'),
              _buildDataPoint('PRICE NOW', '₹${lp.toStringAsFixed(2)}', color: const Color(0xFF4D96FF)),
            ],
          ),
          if (netqty != 0) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => _showConfirmSingleDialog(context, pos),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5F5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF5F5F).withOpacity(0.2)),
                  ),
                  child: const Text(
                    'EXIT POSITION', 
                    style: TextStyle(color: Color(0xFFFF5F5F), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showConfirmSingleDialog(BuildContext context, Map<String, dynamic> position) {
    final double netqty = double.tryParse(position['netqty']?.toString() ?? '0') ?? 0.0;
    final String action = netqty > 0 ? 'SELL' : 'BUY';

    showDialog(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Confirm Square Off',
        isDestructive: true,
        confirmLabel: 'CLOSE POSITION',
        items: [
          {'label': 'Scrip', 'value': position['tsym'] ?? ''},
          {'label': 'Action', 'value': action},
          {'label': 'Quantity', 'value': netqty.abs().toInt().toString()},
          {'label': 'Order Type', 'value': 'MARKET'},
        ],
        onConfirm: () async {
          final result = await _pnlService.squareOffSingle(position);
          if (mounted) {
            final bool isSuccess = result['stat'] == 'Ok';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isSuccess ? 'Exit Order Placed' : 'Order Failed: ${result['emsg']}'),
                backgroundColor: isSuccess ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDataPoint(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
