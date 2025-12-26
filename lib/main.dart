import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/strategy_service.dart';
import 'services/pnl_service.dart';
import 'screens/settings_page.dart';
import 'screens/developer_settings_page.dart';

import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Map<String, dynamic>? userData;
  String? errorMessage;

  try {
    final apiService = ApiService();
    final storageService = StorageService();
    final strategyService = StrategyService();
    
    await apiService.initToken();
    await strategyService.init(); 
    
    final String? uid = await storageService.getUid();
    final String? token = apiService.userToken;
    
    // SESSION EXPIRY CHECK
    final String? lastLoginDate = await storageService.getLastLoginDate();
    final String today = DateTime.now().toString().split(' ')[0];

    if (token != null && uid != null) {
      if (lastLoginDate != today) {
         print('Session Expired: Last login $lastLoginDate, Today $today. Clearing session.');
         await storageService.clearAll();
         apiService.clearSession(); 
         userData = null;
      } else {
        try {
          // Add timeout to prevent indefinite hanging
          final response = await apiService.getUserDetails(userId: uid).timeout(const Duration(seconds: 10));
          if (response['stat'] == 'Ok') {
            userData = response;
          }
        } catch (e) {
          print('Network/API Error fetching user details: $e');
          // Don't crash, just proceed to login
        }
      }
    }
  } catch (e, stack) {
    print('Initialization Error: $e\n$stack');
    errorMessage = e.toString();
  }

  runApp(MyApp(initialUserData: userData, errorMessage: errorMessage));
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic>? initialUserData;
  final String? errorMessage;
  
  const MyApp({super.key, this.initialUserData, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
       return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text('Initialization Failed', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(errorMessage!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
       );
    }

    return MaterialApp(
      title: 'HeroZero Trade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4D96FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF161B22),
          primary: const Color(0xFF4D96FF),
          secondary: const Color(0xFF00D97E),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0D0F12),
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/settings': (context) => const SettingsPage(),
        '/developer-settings': (context) => const DeveloperSettingsPage(),
      },
      home: initialUserData != null 
          ? MainScreen(userData: initialUserData!) 
          : const LoginPage(),
    );
  }
}
