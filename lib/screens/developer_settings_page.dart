import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  final StorageService _storageService = StorageService();
  
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _exitBufferController = TextEditingController(); 
  
  // Trailing Config Controllers
  final TextEditingController _niftyStepController = TextEditingController();
  final TextEditingController _niftyIncController = TextEditingController();
  final TextEditingController _sensexStepController = TextEditingController();
  final TextEditingController _sensexIncController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _storageService.getDevConfig();
    final strategySettings = await _storageService.getStrategySettings();
    
    if (mounted) {
      setState(() {
        _vendorController.text = config['vendorCode'] ?? '';
        _apiKeyController.text = config['apiKey'] ?? '';
        _imeiController.text = config['imei'] ?? '';
        
        // Load strategy settings for buffer
        _exitBufferController.text = (strategySettings['exitTriggerBuffer'] ?? 0.5).toString();
        _niftyStepController.text = (strategySettings['niftyTrailingStep'] ?? 10.0).toString();
        _niftyIncController.text = (strategySettings['niftyTrailingIncrement'] ?? 8.0).toString();
        _sensexStepController.text = (strategySettings['sensexTrailingStep'] ?? 20.0).toString();
        _sensexIncController.text = (strategySettings['sensexTrailingIncrement'] ?? 15.0).toString();

        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    await _storageService.saveDevConfig(
      vendorCode: _vendorController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      imei: _imeiController.text.trim(),
    );

    // Save Buffer - We need to preserve other strategy settings
    final currentStrat = await _storageService.getStrategySettings();
    await _storageService.saveStrategySettings(
      niftyDay: currentStrat['niftyDay'],
      sensexDay: currentStrat['sensexDay'],
      niftyLotSize: currentStrat['niftyLotSize'],
      sensexLotSize: currentStrat['sensexLotSize'],
      showTestButton: currentStrat['showTestButton'],
      strategyTime: currentStrat['strategyTime'], 
      strategy930CaptureTime: currentStrat['strategy930CaptureTime'] ?? '09:25',
      strategy930FetchTime: currentStrat['strategy930FetchTime'] ?? '09:30',
      exitTime: currentStrat['exitTime'],
      exitTriggerBuffer: double.tryParse(_exitBufferController.text) ?? 0.5,
      niftyTrailingStep: double.tryParse(_niftyStepController.text) ?? 10.0,
      niftyTrailingIncrement: double.tryParse(_niftyIncController.text) ?? 8.0,
      sensexTrailingStep: double.tryParse(_sensexStepController.text) ?? 20.0,
      sensexTrailingIncrement: double.tryParse(_sensexIncController.text) ?? 15.0,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shoonya API settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        title: const Text('SHOONYA API CONFIG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: SpinKitPulse(color: Color(0xFF4D96FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    opacity: 0.05,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'CREDENTIAL STORAGE',
                                style: TextStyle(
                                  color: Colors.orangeAccent, 
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: 1
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Configure your Shoonya API credentials here. These settings will persist across logouts.',
                          style: TextStyle(color: Colors.blueGrey, fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField('VENDOR CODE', _vendorController, icon: Icons.code_rounded),
                  const SizedBox(height: 24),
                  _buildTextField('API KEY', _apiKeyController, icon: Icons.vpn_key_rounded),
                  const SizedBox(height: 24),
                  _buildTextField('IMEI', _imeiController, icon: Icons.phone_android_rounded),

                  const SizedBox(height: 24),
                  _buildTextField('EXIT TRIGGER BUFFER', _exitBufferController, icon: Icons.tune_rounded),
                  const SizedBox(height: 32),
                  const Text('TRAILING SETTINGS', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('NIFTY STEP', _niftyStepController, icon: Icons.trending_up_rounded)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('NIFTY INC', _niftyIncController, icon: Icons.add_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('SENSEX STEP', _sensexStepController, icon: Icons.trending_up_rounded)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('SENSEX INC', _sensexIncController, icon: Icons.add_rounded)),
                    ],
                  ),

                  const SizedBox(height: 32),
                  NeonButton(
                    onPressed: _saveConfig,
                    label: 'SAVE CONFIGURATION',
                    icon: Icons.save_rounded,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4D96FF), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        ),
      ],
    );
  }
}
