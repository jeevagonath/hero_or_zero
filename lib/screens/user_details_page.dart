import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeader(context, userName, accountId),
          const SizedBox(height: 32),
          _buildInfoCard(
            title: 'CONNECTION CONFIGURATION',
            children: [
              _buildInfoRow('Terminal ID', accountId),
              _buildInfoRow('Broker Nexus', brokerName),
              _buildInfoRow('Session State', 'LIVE', isStatus: true),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            title: 'HOLDER IDENTITY',
            children: [
              _buildInfoRow('Full Name', userName),
              _buildInfoRow('Email Address', userData['email'] ?? 'N/A'),
              _buildInfoRow('Access Level', 'ALGO_TRADER', color: const Color(0xFF4D96FF)),
            ],
          ),
          const SizedBox(height: 48),
          NeonButton(
            onPressed: () => _handleLogout(context),
            label: 'TERMINATE SESSION',
            icon: Icons.power_settings_new_rounded,
            color: const Color(0xFFFF5F5F),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, String name, String id) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4D96FF), Color(0xFF00D97E)],
            ),
          ),
          child: CircleAvatar(
            radius: 28, // Reduced from 50
            backgroundColor: const Color(0xFF161B22),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white), // Reduced font size
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 20, // Reduced top name size
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D97E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ID: $id',
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00D97E),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.blueGrey, size: 24),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }


  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00D97E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LIVE CONNECTION',
                style: TextStyle(color: Color(0xFF00D97E), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            )
          else
            Expanded(
              flex: 3,
              child: Text(
                value, 
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color ?? Colors.white, 
                  fontWeight: FontWeight.w800, 
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
