import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/sms_service.dart';
import '../../../../core/theme/app_theme.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> with WidgetsBindingObserver {
  String _selectedMode = SmsService.modeDefaultApp;
  SimDeviceInfo _simInfo = const SimDeviceInfo();
  bool _isLoading = true;

  bool _isSmsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings({bool showFeedback = false}) async {
    // Proactively request phone state on Android to allow reading SubscriptionInfo
    if (Platform.isAndroid) {
      try {
        final phoneStatus = await Permission.phone.status;
        if (!phoneStatus.isGranted) {
          await Permission.phone.request();
        }
      } catch (_) {}
    }

    final mode = await SmsService.getSmsMode();
    final simInfo = await SmsService.getSimDeviceInfo();
    String effectiveMode = mode;

    // Check SMS permission status
    bool isSmsGranted = false;
    if (Platform.isAndroid) {
      try {
        isSmsGranted = await Permission.sms.isGranted;
      } catch (_) {}
    }

    // Safety fallback: if SIM 1 was selected previously but slot 0 is inactive
    if (effectiveMode == SmsService.modeAutoSim1 && !simInfo.isSlotActive(0)) {
      effectiveMode = simInfo.isSlotActive(1) ? SmsService.modeAutoSim2 : SmsService.modeDefaultApp;
      await SmsService.setSmsMode(effectiveMode);
    }

    // Safety fallback: if SIM 2 was selected previously but device is single-SIM or slot 2 is inactive
    if (effectiveMode == SmsService.modeAutoSim2 && (!simInfo.isSlotActive(1) || simInfo.isSingleSlotDevice)) {
      effectiveMode = simInfo.isSlotActive(0) ? SmsService.modeAutoSim1 : SmsService.modeDefaultApp;
      await SmsService.setSmsMode(effectiveMode);
    }

    if (mounted) {
      setState(() {
        _selectedMode = effectiveMode;
        _simInfo = simInfo;
        _isSmsPermissionGranted = isSmsGranted;
        _isLoading = false;
      });

      if (showFeedback) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SIM card status refreshed.'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    }
  }

  Future<void> _onSelectMode(String mode) async {
    if (_selectedMode == mode) return;

    // If selecting Auto SIM, check SMS permission
    if (Platform.isAndroid && (mode == SmsService.modeAutoSim1 || mode == SmsService.modeAutoSim2)) {
      try {
        final smsStatus = await Permission.sms.status;
        if (!smsStatus.isGranted) {
          final res = await Permission.sms.request();
          if (!res.isGranted) {
            setState(() {
              _isSmsPermissionGranted = false;
            });
            if (mounted) {
              _showPermissionGuideSheet();
            }
          } else {
            setState(() {
              _isSmsPermissionGranted = true;
            });
          }
        } else {
          setState(() {
            _isSmsPermissionGranted = true;
          });
        }
      } catch (_) {}
    }

    setState(() {
      _selectedMode = mode;
    });

    try {
      await SmsService.setSmsMode(mode);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS setting saved.'),
            duration: Duration(milliseconds: 1200),
            backgroundColor: Color(0xFF2B9348),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving setting: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine SIM 1 state
    final isSim1Active = _simInfo.isSlotActive(0);
    final sim1Carrier = _simInfo.getCarrierName(0);
    final sim1Title = isSim1Active && sim1Carrier != null && sim1Carrier.isNotEmpty
        ? 'Auto SMS - SIM 1 ($sim1Carrier)'
        : 'Auto SMS - SIM 1';

    // Determine SIM 2 state
    final isSingleSlot = _simInfo.isSingleSlotDevice;
    final isSim2Active = !isSingleSlot && _simInfo.isSlotActive(1);
    final sim2Carrier = _simInfo.getCarrierName(1);

    String sim2Title = 'Auto SMS - SIM 2';
    String sim2Subtitle = 'Sends SMS automatically in background via SIM 2 after fee collection.';
    String sim2Badge = 'Automatic';

    if (isSingleSlot) {
      sim2Subtitle = 'Not supported on single-SIM devices.';
      sim2Badge = 'No Slot';
    } else if (!isSim2Active) {
      sim2Subtitle = 'No SIM card detected in SIM 2 slot.';
      sim2Badge = 'No SIM';
    } else if (sim2Carrier != null && sim2Carrier.isNotEmpty) {
      sim2Title = 'Auto SMS - SIM 2 ($sim2Carrier)';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('SMS Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Setup Guide',
            onPressed: _showPermissionGuideSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh SIM status',
            onPressed: _isLoading ? null : () => _loadSettings(showFeedback: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fee Confirmation SMS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose how confirmation messages are sent after collecting fees.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Default App (No redundant small badge)
                  _buildOptionTile(
                    mode: SmsService.modeDefaultApp,
                    title: 'Phone SMS App (Default)',
                    subtitle: 'Opens your phone\'s messaging app so you can review and tap send.',
                    icon: Icons.chat_outlined,
                    iconColor: AppTheme.primaryColor,
                    badgeText: null,
                    enabled: true,
                  ),
                  const SizedBox(height: 12),

                  // Option 2: No SMS
                  _buildOptionTile(
                    mode: SmsService.modeNoSms,
                    title: 'No Messages',
                    subtitle: 'Turns off confirmation messages. No SMS will be sent.',
                    icon: Icons.sms_failed_outlined,
                    iconColor: Colors.grey,
                    badgeText: null,
                    enabled: true,
                  ),
                  const SizedBox(height: 12),

                  // Option 3: Auto SIM 1
                  _buildOptionTile(
                    mode: SmsService.modeAutoSim1,
                    title: sim1Title,
                    subtitle: isSim1Active
                        ? 'Sends SMS automatically in background via SIM 1 after fee collection.'
                        : 'No SIM card detected in SIM 1 slot.',
                    icon: Icons.sim_card_outlined,
                    iconColor: const Color(0xFF2B9348),
                    badgeText: isSim1Active ? 'Automatic' : 'No SIM',
                    enabled: isSim1Active,
                    disabledReason: 'No SIM card detected in SIM 1 slot.',
                  ),
                  const SizedBox(height: 12),

                  // Option 4: Auto SIM 2 (Handles single-slot or empty slot)
                  _buildOptionTile(
                    mode: SmsService.modeAutoSim2,
                    title: sim2Title,
                    subtitle: sim2Subtitle,
                    icon: Icons.sim_card_outlined,
                    iconColor: isSim2Active ? const Color(0xFF2B9348) : Colors.grey,
                    badgeText: sim2Badge,
                    enabled: isSim2Active,
                    disabledReason: isSingleSlot
                        ? 'This phone model only supports 1 SIM card.'
                        : 'No SIM card detected in SIM 2 slot.',
                  ),

                  // Status Card for Auto SIM mode
                  if (_selectedMode == SmsService.modeAutoSim1 || _selectedMode == SmsService.modeAutoSim2) ...[
                    if (!_isSmsPermissionGranted)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'SMS permission needed for Auto Send',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _showPermissionGuideSheet,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Enable',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto SMS ready (Offline via SIM)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 14),
                  // Auto-save informative hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your selection is saved automatically.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOptionTile({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? badgeText,
    bool enabled = true,
    String? disabledReason,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: enabled
          ? () => _onSelectMode(mode)
          : () {
              if (disabledReason != null) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(disabledReason),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected && enabled ? AppTheme.primaryColor : Colors.grey.shade200,
              width: isSelected && enabled ? 2 : 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected && enabled ? AppTheme.primaryColor : Colors.black87,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: !enabled
                                  ? Colors.grey.shade200
                                  : isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: !enabled
                                    ? Colors.grey.shade600
                                    : isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected && enabled ? AppTheme.primaryColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected && enabled
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionGuideSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_update_good_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Enable Auto SMS',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Simple 3-step setup to send SMS from your SIM',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.black45),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.offline_bolt_rounded, color: Color(0xFF16A34A), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sends messages using your regular SIM card pack. 100% offline, no internet required.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      step: '1',
                      title: 'Tap "Open Settings" below',
                      subtitle: 'Takes you directly to the app info page.',
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    _buildStepRow(
                      step: '2',
                      title: 'Tap 3 dots (⋮) in the top-right corner',
                      subtitle: 'Select "Allow restricted settings" & unlock phone.',
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    _buildStepRow(
                      step: '3',
                      title: 'Go to Permissions → SMS → "Allow"',
                      subtitle: 'Turn on SMS permission to finish setup.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'One-time setup: You only need to do this once on this phone.',
                      style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.grey.shade300),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Not Now',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await openAppSettings();
                      },
                      icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 16),
                      label: const Text(
                        'Open Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    height: 1.25,
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
