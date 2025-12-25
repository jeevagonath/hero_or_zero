import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/strategy_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storageService = StorageService();
  final StrategyService _strategyService = StrategyService();
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  
  String _niftyDay = 'Tuesday';
  String _sensexDay = 'Thursday';
  String _strategyTime = '13:15';
  final TextEditingController _niftyLotController = TextEditingController();
  final TextEditingController _sensexLotController = TextEditingController();
  bool _showTestButton = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _storageService.getStrategySettings();
    setState(() {
      _niftyDay = settings['niftyDay'];
      _sensexDay = settings['sensexDay'];
      _niftyLotController.text = settings['niftyLotSize'].toString();
      _sensexLotController.text = settings['sensexLotSize'].toString();
      _showTestButton = settings['showTestButton'];
      _strategyTime = settings['strategyTime'];
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _storageService.saveStrategySettings(
      niftyDay: _niftyDay,
      sensexDay: _sensexDay,
      niftyLotSize: int.tryParse(_niftyLotController.text) ?? 25,
      sensexLotSize: int.tryParse(_sensexLotController.text) ?? 10,
      showTestButton: _showTestButton,
      strategyTime: _strategyTime,
    );
    
    // Notify StrategyService to reload new settings
    await _strategyService.refreshSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Strategy Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('NIFTY Configuration'),
                  _buildDropdownRow('Trading Day', _niftyDay, (val) => setState(() => _niftyDay = val!)),
                  _buildTextFieldRow('Lot Size', _niftyLotController),
                  const SizedBox(height: 32),
                  _buildSectionHeader('SENSEX Configuration'),
                  _buildDropdownRow('Trading Day', _sensexDay, (val) => setState(() => _sensexDay = val!)),
                  _buildTextFieldRow('Lot Size', _sensexLotController),
                  const SizedBox(height: 32),
                  _buildSectionHeader('General Settings'),
                  _buildTimePickerRow('Strategy Trigger Time', _strategyTime),
                  _buildSwitchRow('Show Test Capture Button', _showTestButton, (val) => setState(() => _showTestButton = val)),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButton<String>(
              value: value,
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: onChanged,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          InkWell(
            onTap: () async {
              final timeParts = value.split(':');
              final initialTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: initialTime,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.blueAccent,
                        onPrimary: Colors.white,
                        surface: Color(0xFF1E293B),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedTime != null) {
                final formattedTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                setState(() => _strategyTime = formattedTime);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}
