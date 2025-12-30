import 'package:flutter/material.dart';
import '../services/strategy_930_service.dart';
import '../widgets/glass_widgets.dart';

class Strategy930Page extends StatefulWidget {
  const Strategy930Page({super.key});

  @override
  State<Strategy930Page> createState() => _Strategy930PageState();
}

class _Strategy930PageState extends State<Strategy930Page> {
  final Strategy930Service _service = Strategy930Service();

  @override
  void initState() {
    super.initState();
    _service.ensureTimerRunning();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('9:30 AM Strategy'),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00D97E),
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'NIFTY 50'),
              Tab(text: 'SENSEX'),
            ],
          ),
          actions: [
            // Dev Tools
            GestureDetector(
              onLongPress: () {
                 showDialog(context: context, builder: (_) => AlertDialog(
                   title: const Text('Dev Tools'),
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       ElevatedButton(onPressed: _service.manualCapture, child: const Text('Force Capture 9:25')),
                       ElevatedButton(onPressed: _service.manualFetch, child: const Text('Force Fetch 9:30')),
                       const Divider(),
                       ElevatedButton(
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                         onPressed: _service.resetDay, 
                         child: const Text('Reset Day (Clear State)', style: TextStyle(color: Colors.white)),
                       ),
                     ],
                   ),
                 ));
              },
              child: ValueListenableBuilder<String>(
                valueListenable: _service.currentTime,
                builder: (ctx, time, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          time.isEmpty ? '--:--:--' : time, // Fallback
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Status Bar
            ValueListenableBuilder<String?>(
              valueListenable: _service.statusMessage,
              builder: (ctx, status, _) {
                if (status == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Colors.blue.withOpacity(0.2),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.blueAccent),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            // Scheduled Times Display
            Container(
               width: double.infinity,
               color: Colors.black26,
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Text('Scheduled: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                   ValueListenableBuilder<String>(
                     valueListenable: _service.timeSpotCapture,
                     builder: (ctx, t, _) => Text('Capture@$t  ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                   ),
                   ValueListenableBuilder<String>(
                     valueListenable: _service.timeStrikeFetch,
                     builder: (ctx, t, _) => Text('Fetch@$t', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                   ),
                 ],
               ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _service.errorMessage,
              builder: (ctx, error, _) {
                if (error == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Colors.red.withOpacity(0.2),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            // Tab View
            Expanded(
              child: TabBarView(
                children: [
                  _buildIndexColumn(
                    title: 'NIFTY 50',
                    spotNotifier: _service.niftySpot,
                    strikesNotifier: _service.niftyStrikes,
                    color: Colors.blueAccent,
                  ),
                  _buildIndexColumn(
                    title: 'SENSEX',
                    spotNotifier: _service.sensexSpot,
                    strikesNotifier: _service.sensexStrikes,
                    color: Colors.purpleAccent,
                  ),
                ],
              ),
            ),
            
            // Bottom Action Bar
            GlassCard(
               padding: const EdgeInsets.all(16),
               child: SafeArea(
                 child: Row(
                   children: [
                     Expanded(
                       child: ElevatedButton(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF00D97E),
                           foregroundColor: Colors.black,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                         onPressed: () {
                           _initiateOrders();
                         },
                         child: const Text('INITIATE SELECTED ORDERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       ),
                     ),
                   ],
                 ),
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexColumn({
    required String title,
    required ValueNotifier<double?> spotNotifier,
    required ValueNotifier<List<Map<String, dynamic>>> strikesNotifier,
    required Color color,
  }) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
          ),
          child: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),

        // List
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: strikesNotifier,
            builder: (ctx, strikes, _) {
              if (strikes.isEmpty) {
                return Center(
                  child: Text(
                    'No Strikes Fetched',
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                );
              }
              return ListView.builder(
                itemCount: strikes.length,
                itemBuilder: (ctx, index) {
                  final strike = strikes[index];
                  // Determine color based on Type (CE Green, PE Red)
                  final isCE = strike['type'] == 'CE';
                  final typeColor = isCE ? const Color(0xFF00D97E) : const Color(0xFFFF4D4D);
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: strike['selected'] == true ? typeColor : Colors.transparent,
                        width: 1,
                      ),
                    ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Row(
                          children: [
                            // Checkbox
                             SizedBox(
                               width: 24,
                               height: 24,
                               child: Checkbox(
                                value: strike['selected'] == true,
                                activeColor: typeColor,
                                side: BorderSide(color: typeColor.withOpacity(0.5)),
                                onChanged: (val) {
                                  _service.toggleSelection(strikes, index);
                                },
                              ),
                             ),
                            const SizedBox(width: 8),
                            
                            // Info Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${strike['strike']}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    strike['type'],
                                    style: TextStyle(color: typeColor, fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Price Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  Text(
                                    strike['lp']?.toString() ?? '...',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final String? pcStr = strike['pc']?.toString();
                                      final String? lpStr = strike['lp']?.toString();
                                      
                                      if (pcStr != null && lpStr != null) {
                                        final double pc = double.tryParse(pcStr) ?? 0.0;
                                        final double lp = double.tryParse(lpStr) ?? 0.0;
                                        // Calculate approx difference: Diff = LTP - (LTP / (1 + pc/100))
                                        final double prevClose = lp / (1 + (pc / 100));
                                        final double diff = lp - prevClose;
                                        final Color color = pc >= 0 ? const Color(0xFF00D97E) : const Color(0xFFFF4D4D);
                                        final String sign = pc >= 0 ? '+' : '';
                                        
                                        return Text(
                                          '$sign${diff.toStringAsFixed(2)} ($sign${pc.toStringAsFixed(2)}%)',
                                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                // Status Badge (Mini)
                                ValueListenableBuilder<Map<String, String>>(
                                  valueListenable: _service.exitStatusMap,
                                  builder: (ctx, statusMap, _) {
                                    final status = statusMap[strike['token'].toString()];
                                    if (status == null || status.isEmpty) return const SizedBox.shrink();
                                    return Text(
                                      status, 
                                      style: TextStyle(fontSize: 10, color: status.contains('Hit') ? Colors.redAccent : Colors.amberAccent),
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ],
                            ),
                            
                            // Delete Action
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _service.removeStrike(strikes, index),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.close, color: Colors.white24, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                },
              );
            },
          ),
        ),

        // Bottom Spot Card
        ValueListenableBuilder<double?>(
          valueListenable: spotNotifier,
          builder: (ctx, spot, _) {
            if (spot == null) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Column(
                children: [
                  const Text('SPOT PRICE', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    spot.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
  
  void _initiateOrders() {
    // Gather all selected strikes
    final List<Map<String, dynamic>> allTargets = [];
    allTargets.addAll(_service.niftyStrikes.value.where((s) => s['selected']));
    allTargets.addAll(_service.sensexStrikes.value.where((s) => s['selected']));
    
    if (allTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No strikes selected')));
      return;
    }
    
    showDialog(
      context: context, 
      builder: (ctx) => GlassConfirmationDialog(
        title: 'Confirm 9:30 Strategy', 
        items: allTargets.map((t) => {
          'label': t['tsym'].toString(),
          'value': 'BUY MKT',
        }).toList(),
        onConfirm: () {
          // Dialog handles pop automatically
          _service.placeOrders(allTargets);
        }
      )
    );
  }
}
