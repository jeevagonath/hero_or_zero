import 'package:flutter/material.dart';
import '../services/strategy_service.dart';
import '../services/pnl_service.dart';
import '../widgets/glass_widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:ui';

class StrategyPage extends StatefulWidget {
  const StrategyPage({super.key});

  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  final StrategyService _strategyService = StrategyService();

  @override
  void initState() {
    super.initState();
    // Listen for order status changes to show snackbars
    _strategyService.orderStatus.addListener(_onOrderStatusChanged);
  }

  void _onOrderStatusChanged() {
    final status = _strategyService.orderStatus.value;
    if (status != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status),
          backgroundColor: status.contains('Success') ? Colors.green : Colors.blueAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _strategyService.orderStatus.removeListener(_onOrderStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _strategyService.isCapturing, // Trigger rebuild on major state changes
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection(),
              const SizedBox(height: 24),
              _buildExitPlanSection(),
              const SizedBox(height: 32),
              ValueListenableBuilder<String?>(
                valueListenable: _strategyService.capturedSpotPrice,
                builder: (context, spot, _) {
                  if (spot != null) {
                    return Column(
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: _strategyService.statusMessage,
                          builder: (context, status, _) {
                            if (status == null || status.contains('ready')) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                status,
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: _strategyService.errorMessage,
                          builder: (context, error, _) {
                            if (error == null) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                              ),
                              child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                            );
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _strategyService.isResolving,
                          builder: (context, resolving, _) {
                            if (resolving) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Column(
                                    children: [
                                      SpinKitThreeBounce(color: Color(0xFF4D96FF), size: 30),
                                      SizedBox(height: 16),
                                      Text('Resolving optimal contracts...', style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return _buildStrikesSection();
                          },
                        ),
                        const SizedBox(height: 32),
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _strategyService.strikes,
                          builder: (context, strikes, _) {
                            if (strikes.any((s) => s['selected'])) {
                              return _buildPlaceOrderButton();
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    );
                  }
                  return _buildWaitingSection();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4D96FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFF4D96FF), size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Strategy Engine',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24),
          opacity: 0.05, // Slightly reduced opacity to match Exit Plan
          borderRadius: BorderRadius.circular(24), // Match Exit Plan border radius
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _strategyService.currentTime,
                builder: (context, time, _) => _buildInfoRow(Icons.schedule_rounded, 'System Clock', time, isHighlighted: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white10, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _strategyService.targetIndex,
                      builder: (context, index, _) => _buildInfoStat('Index', index, color: const Color(0xFF4D96FF)),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _strategyService.isStrategyDay,
                      builder: (context, active, _) => _buildInfoStat(
                        'Strategy Day', 
                        active ? 'ACTIVE' : 'INACTIVE', 
                        color: active ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F)
                      ),
                    ),
                  ),
                ],
              ),
               const SizedBox(height: 20), // Spacing between rows
              ListenableBuilder(
                listenable: Listenable.merge([_strategyService.currentTime, _strategyService.strategyTime, _strategyService.isStrategyDay]),
                builder: (context, _) {
                  final String current = _strategyService.currentTime.value;
                  final String target = _strategyService.strategyTime.value;
                  final bool isRunning = _strategyService.isStrategyDay.value && 
                                       current.isNotEmpty && 
                                       current.substring(0, 5).compareTo(target) >= 0;
                  return Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: _buildInfoStat(
                          'Engine Status', 
                          isRunning ? 'RUNNING' : 'IDLE', 
                          color: isRunning ? const Color(0xFF00D97E) : Colors.blueGrey
                        ),
                       ),
                       Expanded(
                         child: ValueListenableBuilder<String>(
                            valueListenable: _strategyService.strategyTime,
                            builder: (context, time, _) => _buildInfoStat('Trigger Time', '$time:00'),
                          ),
                       ),
                     ],
                  );
                },
              ),
              ValueListenableBuilder<String?>(
                valueListenable: _strategyService.capturedSpotPrice,
                builder: (context, spot, _) {
                  if (spot == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                       const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      _buildInfoRow(Icons.gps_fixed_rounded, 'Captured Spot', spot, isHighlighted: true),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method for grid-like stats (simpler than full row)
  Widget _buildInfoStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color ?? const Color(0xFF00D97E),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isHighlighted = false, Color? color}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.35), size: 18),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color ?? (isHighlighted ? const Color(0xFF00D97E) : Colors.white),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: (label.contains('Time') || label.contains('Clock')) ? 1 : null,
            fontFamily: (label.contains('Time') || label.contains('Clock')) ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingSection() {
    return Center(
      child: ListenableBuilder(
        listenable: Listenable.merge([_strategyService.isCapturing, _strategyService.isResolving, _strategyService.errorMessage, _strategyService.statusMessage, _strategyService.isStrategyDay]),
        builder: (context, _) => Column(
          children: [
            if (_strategyService.isCapturing.value || _strategyService.isResolving.value)
              const SpinKitDoubleBounce(color: Color(0xFF4D96FF), size: 80)
            else
              Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.blueGrey.withOpacity(0.3)),
            const SizedBox(height: 24),
            if (_strategyService.errorMessage.value != null)
              GlassCard(
                color: Colors.redAccent,
                opacity: 0.1,
                child: Text(
                  _strategyService.errorMessage.value!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF5F5F), fontWeight: FontWeight.w800),
                ),
              )
            else
              ValueListenableBuilder<String>(
                valueListenable: _strategyService.strategyTime,
                builder: (context, time, _) => Text(
                  _strategyService.statusMessage.value ?? (_strategyService.isStrategyDay.value 
                      ? 'Engine pre-warmed. Waiting for $time trigger...' 
                      : 'Strategy inactive. Next automated run scheduled.'), 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            if (_strategyService.errorMessage.value != null || (_strategyService.isStrategyDay.value && _strategyService.capturedSpotPrice.value == null)) ...[
              const SizedBox(height: 32),
              ValueListenableBuilder<bool>(
                valueListenable: _strategyService.showTestButton,
                builder: (context, show, _) {
                  if (!show && _strategyService.errorMessage.value == null) {
                    return const SizedBox.shrink();
                  }
                  return NeonButton(
                    onPressed: _strategyService.captureSpotPrice,
                    label: _strategyService.errorMessage.value != null ? 'Retry Sequence' : 'Manually Trigger Engine',
                    icon: Icons.play_arrow_rounded,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrikesSection() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _strategyService.strikes,
      builder: (context, strikes, _) {
        if (strikes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Strike Prices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...strikes.map((s) => _buildStrikeCard(s, isPut: s['type'] == 'PE')),
          ],
        );
      },
    );
  }

  Widget _buildStrikeCard(Map<String, dynamic> strike, {required bool isPut}) {
    final int index = _strategyService.strikes.value.indexOf(strike);
    final bool isSelected = strike['selected'] ?? false;
    final Color accentColor = isPut ? const Color(0xFFFF5F5F) : const Color(0xFF00D97E);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.05) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.05)
        ),
      ),
      child: InkWell(
        onTap: () => _strategyService.toggleStrikeSelection(index),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: accentColor,
              checkColor: Colors.black,
              side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              visualDensity: VisualDensity.compact,
              onChanged: (val) => _strategyService.toggleStrikeSelection(index),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${strike['strike']} ${strike['type']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        strike['exd'] ?? 'No Expiry',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${strike['lp'] ?? '0.00'}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPut ? 'PUT' : 'CALL',
                    style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _strategyService.deleteStrike(index),
              child: Icon(Icons.close, color: Colors.white.withOpacity(0.3), size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitPlanSection() {
    final PnLService pnlService = PnLService();

    return ListenableBuilder(
      listenable: Listenable.merge([pnlService.portfolioExitStatus, pnlService.totalPnL]),
      builder: (context, _) {
        final status = pnlService.portfolioExitStatus.value;
        final double totalPnL = pnlService.totalPnL.value;
        final double peak = status['peakProfit'] ?? 0.0;
        final tsl = status['tsl'] ?? -999999.0;
        final String exitTime = status['exitTime'] ?? '15:00';
        final double totalLots = status['totalLots'] ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.exit_to_app, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Portfolio Exit Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(24),
              opacity: 0.05,
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildExitStat('Total P&L', '₹${totalPnL.toStringAsFixed(2)}', 
                        color: totalPnL >= 0 ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F)),
                      _buildExitStat('Peak Profit', '₹${peak.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: Colors.white10),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildExitStat(
                        'Trigger TSL', 
                        tsl == -999999.0 ? (totalLots > 0 ? 'Target ₹${(200 * totalLots).toInt()}' : 'Pending') : '₹${tsl.toStringAsFixed(2)}',
                        color: tsl == -999999.0 ? Colors.blueGrey : Colors.orangeAccent,
                      ),
                      _buildExitStat('Exit Time', exitTime, color: const Color(0xFF4D96FF)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }



  Widget _buildExitStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color ?? const Color(0xFF00D97E),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return NeonButton(
      onPressed: _showOrderConfirmationDialog,
      label: 'INITIATE SEQUENCE',
      icon: Icons.rocket_launch_rounded,
    );
  }

  void _showOrderConfirmationDialog() {
    final selectedStrikes = _strategyService.strikes.value.where((s) => s['selected'] == true).toList();
    if (selectedStrikes.isEmpty) return;

    final List<Map<String, String>> items = selectedStrikes.map((s) {
      return {
        'label': '${s['strike']} ${s['type']}',
        'value': 'BUY @ MARKET',
      };
    }).toList();

    showDialog(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Confirm Execution',
        items: items,
        confirmLabel: 'EXECUTE ORDERS',
        onConfirm: _strategyService.placeOrders,
      ),
    );
  }
}
