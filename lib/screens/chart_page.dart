import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../core/constants.dart';
import '../widgets/glass_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class ChartPage extends StatefulWidget {
  final String exchange;
  final String token;
  final String symbol;

  const ChartPage({
    super.key,
    required this.exchange,
    required this.token,
    required this.symbol,
  });

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  List<Candle> _candles = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedInterval = '1m'; // 1m, 3m, 5m, 15m

  Candle? _hoveredCandle;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String uid = _apiService.userId ?? await _storageService.getUid() ?? '';
      
      // Calculate start/end time based on interval to get enough data
      final DateTime now = DateTime.now();
      DateTime startTime;
      
      // Fetch more history for larger intervals
      switch (_selectedInterval) {
        case '15m':
          startTime = now.subtract(const Duration(days: 5)); 
          break;
        case '5m':
          startTime = now.subtract(const Duration(days: 2));
          break;
        case '3m':
          startTime = now.subtract(const Duration(days: 1));
          break;
        case '1m':
        default:
          startTime = now.subtract(const Duration(hours: 6)); // Last 6 hours for 1m
          break;
      }

      final String st = (startTime.millisecondsSinceEpoch ~/ 1000).toString();
      final String et = (now.millisecondsSinceEpoch ~/ 1000).toString();

      final result = await _apiService.getTPSeries(
        userId: uid,
        exchange: widget.exchange,
        token: widget.token,
        startTime: st,
        endTime: et,
      );

      if (result['stat'] == 'Ok' && result['values'] != null) { 
         List<dynamic> rawData = [];
         if (result['values'] is List) {
           rawData = result['values'];
         }

         // Parse 1m candles
         List<Candle> baseCandles = rawData.map((e) {
             final String timeStr = e['time'] ?? '';
             DateTime date = DateTime.now(); 
             try {
               final parts = timeStr.split(' ');
               final dateParts = parts[0].split('-');
               final timeParts = parts[1].split(':');
               date = DateTime(
                 int.parse(dateParts[2]),
                 int.parse(dateParts[1]),
                 int.parse(dateParts[0]),
                 int.parse(timeParts[0]),
                 int.parse(timeParts[1]),
                 int.parse(timeParts[2]),
               );
             } catch (_) {}

             return Candle(
               date: date,
               high: double.tryParse(e['inth'] ?? '0') ?? 0,
               low: double.tryParse(e['intl'] ?? '0') ?? 0,
               open: double.tryParse(e['into'] ?? '0') ?? 0,
               close: double.tryParse(e['intc'] ?? '0') ?? 0,
               volume: double.tryParse(e['v'] ?? '0') ?? 0,
             );
         }).toList();

         baseCandles.sort((a, b) => b.date.compareTo(a.date));

         if (_selectedInterval != '1m') {
            _candles = _resampleCandles(baseCandles, int.parse(_selectedInterval.replaceAll('m', '')));
         } else {
            _candles = baseCandles;
         }

         setState(() {
           _isLoading = false;
           if (_candles.isNotEmpty) {
             _hoveredCandle = _candles.first;
           }
         });
      } else {
         throw Exception(result['emsg'] ?? 'No data found');
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Basic resampling logic (Client-side)
  List<Candle> _resampleCandles(List<Candle> ones, int minutes) {
     if (ones.isEmpty) return [];
     // 1. Sort ascending for aggregation
     List<Candle> sorted = List.from(ones)..sort((a, b) => a.date.compareTo(b.date));
     
     List<Candle> aggregated = [];
     Candle? current;
     DateTime? bucketEndTime;

     for (var c in sorted) {
        final totalMinutes = c.date.hour * 60 + c.date.minute;
        final remainder = totalMinutes % minutes;
        final bucketLimit = c.date.subtract(Duration(minutes: remainder, seconds: c.date.second));
        final nextBucket = bucketLimit.add(Duration(minutes: minutes));

        if (bucketEndTime == null || c.date.isAtSameMomentAs(bucketEndTime!) || c.date.isAfter(bucketEndTime!)) {
           if (current != null) {
              aggregated.add(current);
           }
           bucketEndTime = nextBucket;
           current = Candle(
             date: bucketLimit, 
             high: c.high, 
             low: c.low, 
             open: c.open,
             close: c.close,
             volume: c.volume
           );
        } else {
           current = Candle(
             date: current!.date,
             high: c.high > current.high ? c.high : current.high,
             low: c.low < current.low ? c.low : current.low,
             open: current.open,
             close: c.close,
             volume: current.volume + c.volume, 
           );
        }
     }
     if (current != null) aggregated.add(current);

     return aggregated.reversed.toList();
  }

  Widget _buildOHLC(Candle candle) {
    final bool isUp = candle.close >= candle.open;
    final Color color = isUp ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);
    final TextStyle style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color);
    
    return Row(
      children: [
        Text('O: ${candle.open}', style: style),
        const SizedBox(width: 8),
        Text('H: ${candle.high}', style: style),
        const SizedBox(width: 8),
        Text('L: ${candle.low}', style: style),
        const SizedBox(width: 8),
        Text('C: ${candle.close}', style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.symbol, style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${widget.exchange} ${widget.token}', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
          ],
        ),
        backgroundColor: const Color(0xFF0D0F12),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildTimeSelector('1m'),
          _buildTimeSelector('3m'),
          _buildTimeSelector('5m'),
          _buildTimeSelector('15m'),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
         ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D96FF)))
         : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
            : Column(
                children: [
                  if (_hoveredCandle != null)
                    Container(
                      color: const Color(0xFF0D0F12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildOHLC(_hoveredCandle!),
                            const SizedBox(width: 16),
                            Text('Latest', style: GoogleFonts.inter(fontSize: 10, color: Colors.white24)),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Candlesticks(
                      candles: _candles,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildTimeSelector(String interval) {
    final bool isSelected = _selectedInterval == interval;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedInterval = interval);
        _fetchChartData();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4D96FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? const Color(0xFF4D96FF) : Colors.white24),
        ),
        child: Text(
          interval,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }
}
