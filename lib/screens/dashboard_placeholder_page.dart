import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../core/constants.dart';
import '../widgets/glass_widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:ui';

class DashboardPlaceholderPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardPlaceholderPage({super.key, required this.userData});

  @override
  State<DashboardPlaceholderPage> createState() => _DashboardPlaceholderPageState();
}

class _DashboardPlaceholderPageState extends State<DashboardPlaceholderPage> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final List<Map<String, dynamic>> _selectedScrips = [];

  Map<String, dynamic> _niftyData = {'lp': '0.00', 'pc': '0.00', 'c': '0.00', 'o': '0.00'};
  Map<String, dynamic> _sensexData = {'lp': '0.00', 'pc': '0.00', 'c': '0.00', 'o': '0.00'};

  // Status: CHECKING, LIVE, CLOSED
  String _marketStatus = 'CHECKING';
  DateTime? _lastWsUpdate;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initDashboard();
    _startStatusMonitor();
  }

  void _startStatusMonitor() {
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastWsUpdate != null) {
        final diff = DateTime.now().difference(_lastWsUpdate!);
        final isLive = diff.inSeconds < 3;
        final newStatus = isLive ? 'LIVE' : 'CLOSED';
        
        if (_marketStatus != newStatus) {
           setState(() => _marketStatus = newStatus);
        }
      } else {
        // If still 'CHECKING' after 5 seconds of no data, assume CLOSED
        if (_marketStatus == 'CHECKING' && timer.tick > 5) {
           setState(() => _marketStatus = 'CLOSED');
        } else if (_marketStatus == 'LIVE') {
           // Transition from LIVE to CLOSED if data stops
           setState(() => _marketStatus = 'CLOSED');
        }
      }
    });
  }

  Future<void> _initDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_apiService.userToken == null) {
        await _apiService.initToken();
      }
      
      final String uid = widget.userData['actid'] ?? _apiService.userId ?? '';
      final String token = _apiService.userToken ?? '';

      if (token.isEmpty || uid.isEmpty) {
        throw Exception('User authentication failed. Please log in again.');
      }

      // 1. Fetch initial quotes to get Open prices
      final niftyQuote = await _apiService.getQuote(userId: uid, exchange: 'NSE', token: '26000');
      final sensexQuote = await _apiService.getQuote(userId: uid, exchange: 'BSE', token: '1');

      setState(() {
        if (niftyQuote['stat'] == 'Ok') {
          _niftyData = {
            'lp': niftyQuote['lp'] ?? '0.00',
            'o': niftyQuote['o'] ?? '0.00',
            'c': niftyQuote['c'] ?? '0.00',
          };
          _updateCalculatedChange('NSE', '26000');
        }
        if (sensexQuote['stat'] == 'Ok') {
          _sensexData = {
            'lp': sensexQuote['lp'] ?? '0.00',
            'o': sensexQuote['o'] ?? '0.00',
            'c': sensexQuote['c'] ?? '0.00',
          };
          _updateCalculatedChange('BSE', '1');
        }
      });

      // 2. Connect WebSocket
      await _wsService.connect(
        userId: uid,
        userToken: token,
        accountId: uid,
      );

      // Subscribe to Nifty 50 and Sensex
      _wsService.subscribeTouchline('NSE', '26000');
      _wsService.subscribeTouchline('BSE', '1');

      // 3. Fetch Watchlist from Backend
      try {
        final mwResponse = await _apiService.getMarketWatch(userId: uid);
        if (mwResponse['stat'] == 'Ok' && mwResponse['values'] != null) {
          final List<dynamic> values = mwResponse['values'];
          
          // Clear existing local selection to avoid duplicates if any
          _selectedScrips.clear();

          for (var scrip in values) {
            final String exch = scrip['exch'] ?? '';
            final String token = scrip['token'] ?? '';
            
            if (exch.isNotEmpty && token.isNotEmpty) {
               // Initial placeholder
               final newScrip = {
                'exch': exch,
                'token': token,
                'tsym': scrip['tsym'] ?? '',
                'lp': '0.00',
                'o': '0.00',
                'c_calc': '0.00',
                'pc_calc': '0.00',
              };
              _selectedScrips.add(newScrip);
              
              // Subscribe immediately
              _wsService.subscribeTouchline(exch, token);

              // Fetch quote asynchronously to update detailed data (Open, etc.)
              _apiService.getQuote(userId: uid, exchange: exch, token: token).then((quote) {
                 if (mounted && quote['stat'] == 'Ok') {
                   setState(() {
                     final int idx = _selectedScrips.indexOf(newScrip);
                     if (idx != -1) {
                       _selectedScrips[idx]['lp'] = quote['lp'] ?? '0.00';
                       _selectedScrips[idx]['o'] = quote['o'] ?? '0.00';
                       _updateScripCalculation(idx);
                     }
                   });
                 }
              });
            }
          }
        }
      } catch (e) {
        print('Error fetching remote watchlist: $e');
      }

      // Listen for updates
      _wsSubscription = _wsService.messageStream.listen((data) {
        // Track ANY data packet to determine liveness
        _lastWsUpdate = DateTime.now();

        if (data['t'] == 'tk' || data['t'] == 'tf') {
          final String exchange = data['e'] ?? '';
          final String symToken = data['tk'] ?? '';
           // ... existing processing ...

          setState(() {
            if (exchange == 'NSE' && symToken == '26000') {
              _niftyData = {
                'lp': data['lp'] ?? _niftyData['lp'],
                'o': data['o'] ?? _niftyData['o'],
                'c': data['c'] ?? _niftyData['c'],
              };
              _updateCalculatedChange('NSE', '26000');
            } else if (exchange == 'BSE' && symToken == '1') {
              _sensexData = {
                'lp': data['lp'] ?? _sensexData['lp'],
                'o': data['o'] ?? _sensexData['o'],
                'c': data['c'] ?? _sensexData['c'],
              };
              _updateCalculatedChange('BSE', '1');
            } else {
              // Handle selected scrips
              final index = _selectedScrips.indexWhere(
                (s) => s['exch'] == exchange && s['token'] == symToken
              );
              if (index != -1) {
                _selectedScrips[index]['lp'] = data['lp'] ?? _selectedScrips[index]['lp'];
                _selectedScrips[index]['o'] = data['o'] ?? _selectedScrips[index]['o'];
                _updateScripCalculation(index);
              }
            }
          });
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateCalculatedChange(String exchange, String token) {
    var data = (exchange == 'NSE' && token == '26000') ? _niftyData : _sensexData;
    
    double lp = double.tryParse(data['lp']?.replaceAll(',', '') ?? '0') ?? 0;
    double open = double.tryParse(data['o']?.replaceAll(',', '') ?? '0') ?? 0;
    
    if (open > 0) {
      double absChange = lp - open;
      double pc = (absChange / open) * 100;
      
      data['c_calc'] = absChange.toStringAsFixed(2);
      data['pc_calc'] = pc.toStringAsFixed(2);
    } else {
      data['c_calc'] = '0.00';
      data['pc_calc'] = '0.00';
    }
  }

  void _updateScripCalculation(int index) {
    var data = _selectedScrips[index];
    double lp = double.tryParse(data['lp']?.replaceAll(',', '') ?? '0') ?? 0;
    double open = double.tryParse(data['o']?.replaceAll(',', '') ?? '0') ?? 0;
    
    if (open > 0) {
      double absChange = lp - open;
      double pc = (absChange / open) * 100;
      data['c_calc'] = absChange.toStringAsFixed(2);
      data['pc_calc'] = pc.toStringAsFixed(2);
    } else {
      data['c_calc'] = '0.00';
      data['pc_calc'] = '0.00';
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final String uid = widget.userData['actid'] ?? _apiService.userId ?? '';
      final response = await _apiService.searchScrip(
        userId: uid,
        searchText: query,
      );

      if (response['stat'] == 'Ok' && response['values'] != null) {
        setState(() {
          _searchResults = response['values'];
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _addScrip(dynamic scrip) async {
    final String exch = scrip['exch'];
    final String token = scrip['token'];
    final String tsym = scrip['tsym'];

    // Check if already added
    if (_selectedScrips.any((s) => s['exch'] == exch && s['token'] == token)) {
      _searchController.clear();
      setState(() => _searchResults = []);
      return;
    }

    final String uid = widget.userData['actid'] ?? _apiService.userId ?? '';
    
    // 1. Sync with Shoonya Backend
    try {
      final response = await _apiService.addMultiScripsToMW(
        userId: uid,
        scrips: '$exch|$token',
      );
      if (response['stat'] != 'Ok') {
        print('Backend sync failed for add: ${response['emsg']}');
      }
    } catch (e) {
      print('Error syncing add with backend: $e');
    }

    // 2. Fetch initial quote for Open price
    final quote = await _apiService.getQuote(userId: uid, exchange: exch, token: token);

    setState(() {
      final newScrip = {
        'exch': exch,
        'token': token,
        'tsym': tsym,
        'lp': quote['lp'] ?? '0.00',
        'o': quote['o'] ?? '0.00',
        'c_calc': '0.00',
        'pc_calc': '0.00',
      };
      _selectedScrips.add(newScrip);
      _updateScripCalculation(_selectedScrips.length - 1);
      
      _wsService.subscribeTouchline(exch, token);
      
      _searchController.clear();
      _searchResults = [];
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
    _debounce?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: SpinKitPulse(color: Color(0xFF4D96FF), size: 50),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorState()
                else ...[
                  _buildIndexCards(),
                  const SizedBox(height: 32),
                  _buildSearchBox(),
                  if (_searchResults.isNotEmpty) _buildSearchResultsList(),
                  const SizedBox(height: 32),
                  _buildWatchlist(),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Market Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (!_isLoading) _buildLiveIndicator(),
      ],
    );
  }

  Widget _buildLiveIndicator() {
    Color color;
    String text;

    switch (_marketStatus) {
      case 'LIVE':
        color = const Color(0xFF00D97E); // Green
        text = 'LIVE';
        break;
      case 'CHECKING':
        color = const Color(0xFFFFC107); // Amber/Yellow
        text = 'CHECKING';
        break;
      case 'CLOSED':
      default:
        color = const Color(0xFFFF5F5F); // Red
        text = 'CLOSED';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10, // Slightly smaller to fit "CHECKING"
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          TextButton(onPressed: _initDashboard, child: const Text('Retry'))
        ],
      ),
    );
  }

  Widget _buildIndexCards() {
    return Row(
      children: [
        Expanded(child: _buildIndexCard(title: 'NIFTY 50', data: _niftyData)),
        const SizedBox(width: 16),
        Expanded(child: _buildIndexCard(title: 'SENSEX', data: _sensexData)),
      ],
    );
  }

  Widget _buildSearchBox() {
    return GlassCard(
      padding: EdgeInsets.zero,
      opacity: 0.03,
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search Scrip (e.g. RELIANCE)',
          hintStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF4D96FF), size: 20),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4D96FF))),
                )
              : null,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
            itemBuilder: (context, index) {
              final scrip = _searchResults[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text(scrip['tsym'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(scrip['exch'] ?? '', style: const TextStyle(color: Colors.blueGrey, fontSize: 12, letterSpacing: 1)),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D96FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Color(0xFF4D96FF), size: 18),
                ),
                onTap: () => _addScrip(scrip),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWatchlist() {
    if (_selectedScrips.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Watchlist',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedScrips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final scrip = _selectedScrips[index];
            return _buildScripCard(scrip, index);
          },
        ),
      ],
    );
  }

  Widget _buildScripCard(Map<String, dynamic> scrip, int index) {
    final String change = scrip['pc_calc'] ?? '0.00';
    final bool isPositive = !change.startsWith('-');
    final Color changeColor = isPositive ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scrip['tsym'],
                  style: const TextStyle(
                    fontSize: 13, // Reduced from 16 to 13
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scrip['exch'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${scrip['lp']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$change%',
                style: TextStyle(
                  fontSize: 12,
                  color: changeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () async {
              final String uid = widget.userData['actid'] ?? _apiService.userId ?? '';
              final String scripName = scrip['tsym'] ?? 'Scrip';
              
              try {
                final result = await _apiService.deleteMultiMWScrips(
                  userId: uid,
                  scrips: '${scrip['exch']}|${scrip['token']}',
                );

                if (mounted) {
                  if (result['stat'] == 'Ok') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$scripName removed from Watchlist'),
                        backgroundColor: const Color(0xFF00D97E),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    setState(() {
                      _wsService.unsubscribeTouchline(scrip['exch'], scrip['token']);
                      _selectedScrips.remove(scrip);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to remove: ${result['emsg']}'),
                        backgroundColor: const Color(0xFFFF5F5F),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Network Error during deletion'),
                      backgroundColor: Color(0xFFFF5F5F),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                print('Error syncing delete with backend: $e');
              }
            },
            child: Icon(Icons.close, size: 18, color: Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexCard({required String title, required Map<String, dynamic> data}) {
    final String ltp = data['lp'] ?? '0.00';
    final String change = data['pc_calc'] ?? '0.00';
    final String absChange = data['c_calc'] ?? '0.00';
    final bool isPositive = !change.startsWith('-');
    final Color color = isPositive ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11, // Reduced from 13
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ltp,
            style: const TextStyle(
              fontSize: 18, // Reduced from 22
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 12, // Reduced from 14
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  '$absChange ($change%)',
                  style: TextStyle(
                    fontSize: 10, // Reduced from 12
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

