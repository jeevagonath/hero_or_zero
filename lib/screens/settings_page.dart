import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../services/strategy_service.dart';
import '../services/strategy_930_service.dart';
import '../services/pnl_service.dart';
import '../widgets/glass_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storageService = StorageService();
  final StrategyService _strategyService = StrategyService();
  final Strategy930Service _strategy930Service = Strategy930Service();
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  
  String _niftyDay = 'Tuesday';
  String _sensexDay = 'Thursday';
  String _strategyTime = '13:15';
  String _strategy930CaptureTime = '09:25';
  String _strategy930FetchTime = '09:30';
  String _exitTime = '15:00';
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
      _strategy930CaptureTime = settings['strategy930CaptureTime'] ?? '09:25';
      _strategy930FetchTime = settings['strategy930FetchTime'] ?? '09:30';
      _exitTime = settings['exitTime'] ?? '15:00';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    // Preserve existing values for keys not managed by this page
    final currentSettings = await _storageService.getStrategySettings();
    
    await _storageService.saveStrategySettings(
      niftyDay: _niftyDay,
      sensexDay: _sensexDay,
      niftyLotSize: int.tryParse(_niftyLotController.text) ?? 25,
      sensexLotSize: int.tryParse(_sensexLotController.text) ?? 10,
      showTestButton: _showTestButton,
      strategyTime: _strategyTime,
      strategy930CaptureTime: _strategy930CaptureTime,
      strategy930FetchTime: _strategy930FetchTime,
      exitTime: _exitTime,
      // Pass preserved values for trailing settings
      exitTriggerBuffer: currentSettings['exitTriggerBuffer'] ?? 0.5,
      niftyTrailingStep: currentSettings['niftyTrailingStep'] ?? 10.0,
      niftyTrailingIncrement: currentSettings['niftyTrailingIncrement'] ?? 8.0,
      sensexTrailingStep: currentSettings['sensexTrailingStep'] ?? 20.0,
      sensexTrailingIncrement: currentSettings['sensexTrailingIncrement'] ?? 15.0,
    );
    
    // Notify StrategyService and PnLService to reload new settings
    await _strategyService.refreshSettings();
    await _strategy930Service.refreshSettings();
    await PnLService().refreshSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully'),
          backgroundColor: const Color(0xFF00D97E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        title: Text('Strategy Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D0F12),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D96FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('NIFTY CONFIGURATION', Icons.bar_chart_rounded),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    opacity: 0.05,
                    child: Column(
                      children: [
                        _buildDropdownRow('Trading Day', _niftyDay, (val) => setState(() => _niftyDay = val!)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),
                        _buildTextFieldRow('Lot Size', _niftyLotController),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('SENSEX CONFIGURATION', Icons.show_chart_rounded),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    opacity: 0.05,
                    child: Column(
                      children: [
                        _buildDropdownRow('Trading Day', _sensexDay, (val) => setState(() => _sensexDay = val!)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),
                        _buildTextFieldRow('Lot Size', _sensexLotController),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('GENERAL SETTINGS', Icons.tune_rounded),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    opacity: 0.05,
                    child: Column(
                      children: [
                        _buildTimePickerRow('Strategy Trigger Time', _strategyTime, (val) => setState(() => _strategyTime = val)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),
                        _buildTimePickerRow('9:30 Strategy Capture Time', _strategy930CaptureTime, (val) => setState(() => _strategy930CaptureTime = val)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),
                        _buildTimePickerRow('9:30 Strategy Fetch Time', _strategy930FetchTime, (val) => setState(() => _strategy930FetchTime = val)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),
                        _buildTimePickerRow('Daily Exit Time (Hard Stop)', _exitTime, (val) => setState(() => _exitTime = val)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.white10)),
                        _buildSwitchRow('Show Test Capture Button', _showTestButton, (val) => setState(() => _showTestButton = val)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  NeonButton(
                    onPressed: _saveSettings,
                    label: 'SAVE CONFIGURATION',
                    icon: Icons.save_rounded,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4D96FF), size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.w900, 
            color: Colors.blueGrey,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow(String label, String value, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF4D96FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4D96FF).withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.outfit(color: Colors.white)))).toList(),
              onChanged: onChanged,
              dropdownColor: const Color(0xFF1E293B),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4D96FF), size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldRow(String label, TextEditingController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: const Color(0xFF00D97E), fontWeight: FontWeight.bold, fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF00D97E).withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerRow(String label, String value, ValueChanged<String> onSelected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
                      primary: Color(0xFF4D96FF),
                      onPrimary: Colors.white,
                      surface: Color(0xFF161B22),
                      onSurface: Colors.white,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF4D96FF)),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedTime != null) {
              final formattedTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
              onSelected(formattedTime);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4D96FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4D96FF).withOpacity(0.2)),
            ),
            child: Text(
              value,
              style: GoogleFonts.outfit(color: const Color(0xFF4D96FF), fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4D96FF),
          activeTrackColor: const Color(0xFF4D96FF).withOpacity(0.3),
          inactiveThumbColor: Colors.blueGrey,
          inactiveTrackColor: Colors.white10,
        ),
      ],
    );
  }
}
