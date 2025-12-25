import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class UserDetailsPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserDetailsPage({super.key, required this.userData});

  Future<void> _handleLogout(BuildContext context) async {
    final ApiService apiService = ApiService();
    final StorageService storageService = StorageService();

    // 1. Clear session in API
    apiService.clearSession();
    
    // 2. Clear local storage
    await storageService.clearAll();

    // 3. Navigate back to login
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userName = userData['uname'] ?? 'User';
    final String accountId = userData['actid'] ?? 'N/A';
    final String brokerName = userData['brkname'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Details',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.blueAccent),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoCard(
            title: 'Account Information',
            children: [
              _buildInfoRow('Account ID', accountId),
              _buildInfoRow('Broker', brokerName),
              _buildInfoRow('Status', 'Connected', isStatus: true),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            title: 'Personal Info',
            children: [
              _buildInfoRow('Name', userName),
              _buildInfoRow('Email', userData['email'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'LOGOUT',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            )
          else
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
