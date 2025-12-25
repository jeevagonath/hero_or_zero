import 'package:flutter/material.dart';
import 'dashboard_placeholder_page.dart';
import 'strategy_page.dart';
import 'positions_page.dart';
import 'order_book_page.dart';
import 'trade_book_page.dart';
import 'user_details_page.dart';
import '../services/pnl_service.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MainScreen({super.key, required this.userData});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PnLService _pnlService = PnLService();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPlaceholderPage(userData: widget.userData),
      const StrategyPage(),
      const PositionsPage(),
      const OrderBookPage(),
      const TradeBookPage(),
      UserDetailsPage(userData: widget.userData),
    ];
    
    // Initial fetch for positions
    _pnlService.fetchPositions();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh positions when hitting the positions tab or strategy tab
    if (index == 1 || index == 2) {
      _pnlService.fetchPositions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 24, right: 24, bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F12).withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(color: const Color(0xFF4D96FF).withOpacity(0.3)),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/logo.png'),
                            fit: BoxFit.contain, // Changed to contain to ensure logo is fully visible
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HERO ZERO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            _getTabName(),
                            style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
              ValueListenableBuilder<double>(
                valueListenable: _pnlService.totalPnL,
                builder: (context, pnl, child) {
                  final color = pnl >= 0 ? const Color(0xFF00D97E) : const Color(0xFFFF5F5F);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'DAY P&L',
                          style: TextStyle(fontSize: 8, color: color.withOpacity(0.8), fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        Text(
                          '₹${pnl.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12, // Reduced from 14
                            fontWeight: FontWeight.w900,
                            color: color,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0D0F12),
          selectedItemColor: const Color(0xFF4D96FF),
          unselectedItemColor: Colors.blueGrey.withOpacity(0.6),
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded, size: 22),
              activeIcon: Icon(Icons.grid_view_rounded, size: 22),
              label: 'Market',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt_rounded, size: 22),
              label: 'Strategy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_rounded, size: 22),
              label: 'Position',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_rounded, size: 22),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_edu_rounded, size: 22),
              label: 'Trades',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_rounded, size: 22),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  String _getTabName() {
    switch (_selectedIndex) {
      case 0: return 'WATCHLIST';
      case 1: return 'STRATEGY HUB';
      case 2: return 'ACTIVE POSITIONS';
      case 3: return 'ORDER BOOK';
      case 4: return 'TRADE HISTORY';
      case 5: return 'USER ACCOUNT';
      default: return 'TERMINAL';
    }
  }
}
