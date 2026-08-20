import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/permission_policy.dart';
import '../providers/permission_providers.dart';

class AdminPermissionSettingsPage extends ConsumerStatefulWidget {
  const AdminPermissionSettingsPage({super.key});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<AdminPermissionSettingsPage> createState() => _AdminPermissionSettingsPageState();
}

class _AdminPermissionSettingsPageState extends ConsumerState<AdminPermissionSettingsPage> {
  final _dailyLimitController = TextEditingController();
  final _monthlyLimitController = TextEditingController();

  bool _requireApproval = true;
  bool _allowEmergency = true;
  bool _emergencyRequiresApproval = true;
  bool _allowMultiplePerDay = false;
  bool _allowPostDateEmergency = false;

  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _dailyLimitController.dispose();
    _monthlyLimitController.dispose();
    super.dispose();
  }

  void _populateFields(PermissionPolicy policy) {
    if (_isLoaded) return;
    _dailyLimitController.text = policy.dailyLimitHours.toStringAsFixed(2);
    _monthlyLimitController.text = policy.monthlyLimitHours.toStringAsFixed(2);
    _requireApproval = policy.requireApproval;
    _allowEmergency = policy.allowEmergency;
    _emergencyRequiresApproval = policy.emergencyRequiresApproval;
    _allowMultiplePerDay = policy.allowMultiplePerDay;
    _allowPostDateEmergency = policy.allowPostDateEmergency;
    _isLoaded = true;
  }

  Future<void> _saveSettings() async {
    final daily = double.tryParse(_dailyLimitController.text) ?? 1.0;
    final monthly = double.tryParse(_monthlyLimitController.text) ?? 3.0;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(permissionRepositoryProvider);
      final newPolicy = PermissionPolicy(
        dailyLimitHours: daily,
        monthlyLimitHours: monthly,
        requireApproval: _requireApproval,
        allowEmergency: _allowEmergency,
        emergencyRequiresApproval: _emergencyRequiresApproval,
        allowMultiplePerDay: _allowMultiplePerDay,
        allowPostDateEmergency: _allowPostDateEmergency,
      );

      await repo.updatePermissionPolicy(newPolicy);
      ref.invalidate(permissionPolicyProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission Policy updated successfully'),
          backgroundColor: AdminPermissionSettingsPage.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update policy: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyAsync = ref.watch(permissionPolicyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: policyAsync.when(
        data: (policy) {
          _populateFields(policy);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permission Policy Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AdminPermissionSettingsPage.darkNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure standard daily/monthly limits and emergency approval controls for all employees.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Allowance Settings Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Standard Hour Limits',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminPermissionSettingsPage.darkNeutral),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Permission Limit (Hours)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _dailyLimitController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    suffixText: 'Hours',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Monthly Permission Limit (Hours)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _monthlyLimitController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    suffixText: 'Hours',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Policy Control Switches Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Approval Rules & Emergency Exception',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminPermissionSettingsPage.darkNeutral),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _requireApproval,
                        activeColor: AdminPermissionSettingsPage.primaryGreen,
                        title: const Text('Require Approval for Normal Requests'),
                        subtitle: const Text('All permission requests require Admin/Manager review.'),
                        onChanged: (val) => setState(() => _requireApproval = val),
                      ),
                      const Divider(),
                      SwitchListTile(
                        value: _allowEmergency,
                        activeColor: AdminPermissionSettingsPage.primaryGreen,
                        title: const Text('Allow Emergency Permission'),
                        subtitle: const Text('Allow employees to request emergency exceptions when limit is exceeded.'),
                        onChanged: (val) => setState(() => _allowEmergency = val),
                      ),
                      const Divider(),
                      SwitchListTile(
                        value: _emergencyRequiresApproval,
                        activeColor: AdminPermissionSettingsPage.primaryGreen,
                        title: const Text('Emergency Requests Require Approval'),
                        subtitle: const Text('Emergency requests must be classified as Paid or LOP by Admin/Manager.'),
                        onChanged: (val) => setState(() => _emergencyRequiresApproval = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminPermissionSettingsPage.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Permission Settings',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Text('Error loading policy settings: $err'),
      ),
    );
  }
}
