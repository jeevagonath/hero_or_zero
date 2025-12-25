import 'package:flutter/material.dart';
import '../services/strategy_service.dart';
import '../services/pnl_service.dart';

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
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(color: Colors.blueAccent),
                                    SizedBox(height: 16),
                                    Text('Resolving contracts...', style: TextStyle(color: Colors.blueGrey)),
                                  ],
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.withOpacity(0.3),
            Colors.blueAccent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_outlined, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Strategy Monitor', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)
              ),
            ],
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<String>(
            valueListenable: _strategyService.currentTime,
            builder: (context, time, _) => _buildInfoRow(Icons.access_time, 'Current Clock', time, isHighlighted: true),
          ),
          const Divider(color: Colors.white10, height: 20),
          ValueListenableBuilder<String>(
            valueListenable: _strategyService.targetIndex,
            builder: (context, index, _) => _buildInfoRow(Icons.insights, 'Target Index', index, color: Colors.blueAccent),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: _strategyService.isStrategyDay,
            builder: (context, active, _) => _buildInfoRow(
              Icons.calendar_today, 
              'Strategy Day', 
              active ? 'TODAY' : 'Not Active', 
              color: active ? Colors.greenAccent : Colors.orangeAccent
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: Listenable.merge([_strategyService.currentTime, _strategyService.strategyTime, _strategyService.isStrategyDay]),
            builder: (context, _) {
              final String current = _strategyService.currentTime.value;
              final String target = _strategyService.strategyTime.value;
              final bool isRunning = _strategyService.isStrategyDay.value && 
                                   current.isNotEmpty && 
                                   current.substring(0, 5).compareTo(target) >= 0;
              return _buildInfoRow(
                Icons.bolt_outlined, 
                'Execution State', 
                isRunning ? 'RUNNING' : 'IDLE', 
                color: isRunning ? Colors.greenAccent : Colors.blueGrey
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _strategyService.strategyTime,
            builder: (context, time, _) => _buildInfoRow(Icons.schedule, 'Trigger Time', '$time:00'),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _strategyService.capturedSpotPrice,
            builder: (context, spot, _) {
              if (spot == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildInfoRow(Icons.my_location, 'Spot Captured', spot, isHighlighted: true),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isHighlighted = false, Color? color}) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color ?? (isHighlighted ? Colors.greenAccent : Colors.white),
            fontWeight: FontWeight.w700,
            fontSize: 14,
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
              const CircularProgressIndicator(color: Colors.blueAccent)
            else
              const Icon(Icons.timer_outlined, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            if (_strategyService.errorMessage.value != null)
              Text(
                _strategyService.errorMessage.value!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              )
            else
              ValueListenableBuilder<String>(
                valueListenable: _strategyService.strategyTime,
                builder: (context, time, _) => Text(
                  _strategyService.statusMessage.value ?? (_strategyService.isStrategyDay.value 
                      ? 'Waiting for $time capture...' 
                      : 'Strategy inactive. Next run on ...'), 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ),
            if (_strategyService.errorMessage.value != null || (_strategyService.isStrategyDay.value && _strategyService.capturedSpotPrice.value == null)) ...[
              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: _strategyService.showTestButton,
                builder: (context, show, _) {
                  if (!show && _strategyService.errorMessage.value == null) {
                    return const SizedBox.shrink();
                  }
                  return ElevatedButton(
                    onPressed: _strategyService.captureSpotPrice,
                    child: Text(_strategyService.errorMessage.value != null ? 'Retry Capture' : 'Test Capture Now'),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (strike['selected'] ?? false) 
              ? (isPut ? Colors.redAccent.withOpacity(0.6) : Colors.greenAccent.withOpacity(0.6))
              : Colors.white10,
          width: (strike['selected'] ?? false) ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => _strategyService.toggleStrikeSelection(index),
        child: Row(
          children: [
            Theme(
              data: ThemeData(unselectedWidgetColor: Colors.white24),
              child: Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: strike['selected'] ?? false,
                  activeColor: isPut ? Colors.redAccent : Colors.greenAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => _strategyService.toggleStrikeSelection(index),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strike['tsym']?.toString() ?? strike['strike'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPut ? 'OTM Put Option (PE)' : 'OTM Call Option (CE)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPut ? Colors.redAccent.withOpacity(0.8) : Colors.greenAccent.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Text('LTP', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => _strategyService.deleteStrike(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Text(
                  '₹${strike['lp'] ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 18,
                    color: isPut ? Colors.redAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        onPressed: _strategyService.placeOrders,
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
