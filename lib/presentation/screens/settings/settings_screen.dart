import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onSignOut;
  const SettingsScreen({super.key, required this.onSignOut});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _gstCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      _shopNameCtrl.text = settings.shop.shopName;
      _phoneCtrl.text = settings.shop.phone;
      _addressCtrl.text = settings.shop.address;
      _gstCtrl.text = settings.shop.gstNumber;
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final current = ref.read(settingsProvider).value ?? AllSettings(
      shop: ShopSettings(),
      billing: BillingSettings(),
      loyalty: LoyaltySettings(),
    );

    final updated = AllSettings(
      shop: ShopSettings(
        shopName: _shopNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim(),
        email: current.shop.email,
        footerMessage: current.shop.footerMessage,
      ),
      billing: current.billing,
      loyalty: current.loyalty,
    );

    await ApiRepository.saveSettings(updated);
    ref.invalidate(settingsProvider);

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shop & ERP Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏪 Store Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _shopNameCtrl,
                      decoration: const InputDecoration(labelText: 'Shop / Business Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Shop Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _gstCtrl,
                      decoration: const InputDecoration(labelText: 'GSTIN Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: const Text('Save Profile Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Account & Logout Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                subtitle: const Text('Clear local session cache and log out'),
                onTap: () async {
                  await ApiRepository.signOut();
                  widget.onSignOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
