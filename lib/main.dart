import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  final storageService = StorageService();
  
  await apiService.initToken();
  final String? uid = await storageService.getUid();
  final String? token = apiService.userToken;

  Map<String, dynamic>? userData;
  if (token != null && uid != null) {
    final response = await apiService.getUserDetails(userId: uid);
    if (response['stat'] == 'Ok') {
      userData = response;
    }
  }

  runApp(MyApp(initialUserData: userData));
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic>? initialUserData;
  
  const MyApp({super.key, this.initialUserData});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hero or Zero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: initialUserData != null 
          ? MainScreen(userData: initialUserData!) 
          : const LoginPage(),
    );
  }
}
