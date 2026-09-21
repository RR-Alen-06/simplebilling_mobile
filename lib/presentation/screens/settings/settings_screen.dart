import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onSignOut;
  const SettingsScreen({super.key, required this.onSignOut});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: Shop Details
  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _gstCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _footerMessageCtrl = TextEditingController();
  final TextEditingController _upiIdCtrl = TextEditingController();

  // Tab 2: Billing Config
  final TextEditingController _billPrefixCtrl = TextEditingController(text: 'BILL');
  final TextEditingController _currencyCtrl = TextEditingController(text: 'Rs.');
  String _roundingMethod = 'None';
  String _printerSize = '80mm';
  bool _gstEnabled = false;
  final TextEditingController _gstRateCtrl = TextEditingController(text: '18');

  // Tab 3: Sequence Management
  List<SequenceConfigModel> _sequences = [];
  bool _loadingSequences = false;

  // Tab 4: Loyalty Engine
  bool _loyaltyEnabled = true;
  final TextEditingController _pointsRequiredCtrl = TextEditingController(text: '10');
  final TextEditingController _discountValueCtrl = TextEditingController(text: '5');
  List<LoyaltyRedemptionRule> _redemptionRules = [];
  List<LoyaltyRule> _earningRules = [];

  // Tab 5: EmailJS & WhatsApp Integration
  bool _emailEnabled = false;
  final TextEditingController _emailServiceIdCtrl = TextEditingController();
  final TextEditingController _emailTemplateIdCtrl = TextEditingController();
  final TextEditingController _emailPublicKeyCtrl = TextEditingController();
  bool _whatsAppSharingEnabled = true;

  // Tab 6: Security & Super Admin Controls
  final TextEditingController _adminPinCtrl = TextEditingController(text: '1234');

  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadInitialValues();
    _fetchAuxiliarySettings();
  }

  void _loadInitialValues() {
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      // Shop
      _shopNameCtrl.text = settings.shop.shopName;
      _phoneCtrl.text = settings.shop.phone;
      _emailCtrl.text = settings.shop.email;
      _gstCtrl.text = settings.shop.gstNumber;
      _addressCtrl.text = settings.shop.address;
      _footerMessageCtrl.text = settings.shop.footerMessage;
      _upiIdCtrl.text = settings.shop.upiId;

      // Billing
      _billPrefixCtrl.text = settings.billing.billPrefix;
      _currencyCtrl.text = settings.billing.currencySymbol;
      _roundingMethod = settings.billing.roundingMethod;
      _printerSize = settings.billing.defaultPrinterSize;
      _gstEnabled = settings.billing.gstEnabled;
      _gstRateCtrl.text = settings.billing.gstRate.toStringAsFixed(0);

      // Loyalty
      _loyaltyEnabled = settings.loyalty.enabled;
      _pointsRequiredCtrl.text = settings.loyalty.pointsRequired.toStringAsFixed(0);
      _discountValueCtrl.text = settings.loyalty.discountValue.toStringAsFixed(0);

      // Email & Security
      _emailEnabled = settings.email.enabled;
      _emailServiceIdCtrl.text = settings.email.serviceId;
      _emailTemplateIdCtrl.text = settings.email.templateId;
      _emailPublicKeyCtrl.text = settings.email.publicKey;
      _adminPinCtrl.text = settings.security.adminPin;

      _isLoaded = true;
    }
  }

  Future<void> _fetchAuxiliarySettings() async {
    setState(() {
      _loadingSequences = true;
    });

    try {
      final seqs = await ApiRepository.getSequenceConfigs();
      final redRules = await ApiRepository.getLoyaltyRedemptionRules();
      final earnRules = await ApiRepository.getLoyaltyRules();

      if (mounted) {
        setState(() {
          _sequences = seqs;
          _redemptionRules = redRules;
          _earningRules = earnRules;
          _loadingSequences = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingSequences = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    _footerMessageCtrl.dispose();
    _upiIdCtrl.dispose();
    _billPrefixCtrl.dispose();
    _currencyCtrl.dispose();
    _gstRateCtrl.dispose();
    _pointsRequiredCtrl.dispose();
    _discountValueCtrl.dispose();
    _emailServiceIdCtrl.dispose();
    _emailTemplateIdCtrl.dispose();
    _emailPublicKeyCtrl.dispose();
    _adminPinCtrl.dispose();
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
        email: _emailCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        footerMessage: _footerMessageCtrl.text.trim(),
        upiId: _upiIdCtrl.text.trim(),
        logoUrl: current.shop.logoUrl,
      ),
      billing: BillingSettings(
        billPrefix: _billPrefixCtrl.text.trim().toUpperCase(),
        billFormat: '${_billPrefixCtrl.text.trim().toUpperCase()}-{SEQ}',
        defaultPaymentMethod: current.billing.defaultPaymentMethod,
        currencySymbol: _currencyCtrl.text.trim(),
        decimalPrecision: current.billing.decimalPrecision,
        gstEnabled: _gstEnabled,
        gstRate: double.tryParse(_gstRateCtrl.text.trim()) ?? 0.0,
        defaultPrinterSize: _printerSize,
        autoPrint: current.billing.autoPrint,
        roundingMethod: _roundingMethod,
      ),
      loyalty: LoyaltySettings(
        enabled: _loyaltyEnabled,
        pointsRequired: double.tryParse(_pointsRequiredCtrl.text.trim()) ?? 10.0,
        discountValue: double.tryParse(_discountValueCtrl.text.trim()) ?? 5.0,
      ),
      email: EmailSettings(
        enabled: _emailEnabled,
        serviceId: _emailServiceIdCtrl.text.trim(),
        templateId: _emailTemplateIdCtrl.text.trim(),
        publicKey: _emailPublicKeyCtrl.text.trim(),
      ),
      security: SecuritySettings(
        adminPin: _adminPinCtrl.text.trim().isNotEmpty ? _adminPinCtrl.text.trim() : '1234',
      ),
    );

    await ApiRepository.saveSettings(updated);
    await ApiRepository.saveLoyaltyRedemptionRules(_redemptionRules);
    await ApiRepository.saveLoyaltyRules(_earningRules);

    ref.invalidate(settingsProvider);

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Settings and Rules saved successfully! ⚙️')),
      );
    }
  }

  // --- High Risk Purge Dialog ---
  Future<void> _showPurgeDataModal() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final expectedPin = _adminPinCtrl.text.trim().isNotEmpty ? _adminPinCtrl.text.trim() : '1234';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pastelCoral,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.deepCoral),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.deepCoral, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Purge Business Data',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepCoral, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete all Invoices, Payments, Expenses, and Customer Ledger Histories while preserving your Products catalog & Settings.',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Enter Super Admin PIN', Icons.lock_outline_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                decoration: _inputDecoration('Type "DELETE" to confirm', Icons.delete_forever_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (pinCtrl.text.trim() != expectedPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Super Admin PIN! Access denied.')),
                );
                return;
              }
              if (confirmCtrl.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Confirmation phrase must be "DELETE" in uppercase.')),
                );
                return;
              }

              Navigator.pop(ctx);
              final success = await ApiRepository.purgeBusinessData();
              if (!mounted) return;
              if (success) {
                ref.invalidate(billsListProvider);
                ref.invalidate(customersProvider);
                ref.invalidate(settingsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Business transactions successfully purged! 🧹')),
                );
              }
            },
            child: const Text('Purge Database', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // --- Backup Export Handler ---
  Future<void> _handleBackupExport() async {
    final backupData = await ApiRepository.exportDatabaseBackup();
    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final filename = 'simplebilling_backup_$dateStr.json';

    await CsvExporter.downloadCsv(filename: filename, csvContent: jsonString);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Portable JSON Backup exported ($filename)! 📦')),
    );
  }



  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (prev, next) {
      if (!_isLoaded && next.hasValue && next.value != null) {
        _loadInitialValues();
        setState(() {});
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'System Settings & Loyalty',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.deepLavender,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.deepLavender,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded, size: 16), text: 'Shop Details'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 16), text: 'Billing Config'),
            Tab(icon: Icon(Icons.format_list_numbered_rounded, size: 16), text: 'Sequences'),
            Tab(icon: Icon(Icons.card_giftcard_rounded, size: 16), text: 'Loyalty Engine'),
            Tab(icon: Icon(Icons.mark_email_read_rounded, size: 16), text: 'WhatsApp & Email'),
            Tab(icon: Icon(Icons.security_rounded, size: 16), text: 'Security & Purge'),
            Tab(icon: Icon(Icons.backup_rounded, size: 16), text: 'Backup & Restore'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Shop Details
          _buildShopDetailsTab(),

          // Tab 2: Billing Config
          _buildBillingConfigTab(),

          // Tab 3: Sequence Management
          _buildSequenceTab(),

          // Tab 4: Loyalty Engine
          _buildLoyaltyEngineTab(),

          // Tab 5: WhatsApp & Email
          _buildEmailWhatsAppTab(),

          // Tab 6: Security & Purge
          _buildSecurityPurgeTab(),

          // Tab 7: Backup & Restore
          _buildBackupRestoreTab(),
        ],
      ),
    );
  }

  // --- 1. Shop Details Tab ---
  Widget _buildShopDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _buildSectionCard(
        title: 'Shop Information & Branding',
        subtitle: 'Configures shop identity printed across thermal receipts & shared invoices',
        icon: Icons.storefront_rounded,
        iconBg: AppColors.pastelAmber,
        iconColor: AppColors.deepAmber,
        children: [
          TextField(
            controller: _shopNameCtrl,
            decoration: _inputDecoration('Shop / Business Name (*)', Icons.badge_outlined),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  decoration: _inputDecoration('Contact Phone', Icons.phone_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  decoration: _inputDecoration('Support Email', Icons.email_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gstCtrl,
                  decoration: _inputDecoration('GST Number (Optional)', Icons.receipt_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _upiIdCtrl,
                  decoration: _inputDecoration('Store UPI ID (e.g. store@okaxis)', Icons.qr_code_2_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: _inputDecoration('Shop Address (Printed on receipts)', Icons.location_on_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _footerMessageCtrl,
            decoration: _inputDecoration('Receipt Footer Message', Icons.message_outlined),
          ),
        ],
      ),
    );
  }

  // --- 2. Billing Config Tab ---
  Widget _buildBillingConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _buildSectionCard(
        title: 'Billing Rules & Rounding',
        subtitle: 'Defines default POS checkout behavior, printer layouts, and tax engine',
        icon: Icons.receipt_long_rounded,
        iconBg: AppColors.pastelSky,
        iconColor: AppColors.deepSky,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _billPrefixCtrl,
                  decoration: _inputDecoration('Bill Prefix (e.g. BILL)', Icons.tag_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _currencyCtrl,
                  decoration: _inputDecoration('Currency Symbol', Icons.currency_rupee_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: ['None', 'Normal', 'RoundUp', 'RoundDown'].contains(_roundingMethod) ? _roundingMethod : 'None',
            decoration: _inputDecoration('Default Rounding Method', Icons.calculate_outlined),
            items: const [
              DropdownMenuItem(value: 'None', child: Text('No Rounding (Exact Paise)')),
              DropdownMenuItem(value: 'Normal', child: Text('Standard Rounding (Nearest ₹1.00)')),
              DropdownMenuItem(value: 'RoundUp', child: Text('Round Up / Ceil (₹1.00)')),
              DropdownMenuItem(value: 'RoundDown', child: Text('Round Down / Floor (₹1.00)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _roundingMethod = val);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Default Printer Layout:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              ChoiceChip(
                label: const Text('Thermal POS (80mm)', style: TextStyle(fontWeight: FontWeight.w700)),
                selected: _printerSize == '80mm',
                selectedColor: AppColors.pastelSky,
                side: const BorderSide(color: AppColors.neoBorder),
                onSelected: (val) {
                  if (val) setState(() => _printerSize = '80mm');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Standard A4 Tax Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
                selected: _printerSize == 'A4',
                selectedColor: AppColors.pastelSky,
                side: const BorderSide(color: AppColors.neoBorder),
                onSelected: (val) {
                  if (val) setState(() => _printerSize = 'A4');
                },
              ),
            ],
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable GST Tax Calculation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            subtitle: Text(_gstEnabled ? 'Active default rate: ${_gstRateCtrl.text}%' : 'Disabled for billing terminal', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            value: _gstEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: (val) => setState(() => _gstEnabled = val),
          ),
          if (_gstEnabled) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _gstRateCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Default GST Rate (%)', Icons.percent_rounded),
            ),
          ],
        ],
      ),
    );
  }

  // --- 3. Sequence Management Tab ---
  Widget _buildSequenceTab() {
    if (_loadingSequences) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final sampleEntities = ['BILL', 'PAYMENT', 'EXPENSE', 'PRODUCT', 'CUSTOMER', 'AUDIT'];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildSectionCard(
          title: 'Atomic Sequence Counters',
          subtitle: 'Controls sequential numbering patterns and padding lengths for all business entities',
          icon: Icons.format_list_numbered_rounded,
          iconBg: AppColors.pastelLavender,
          iconColor: AppColors.deepLavender,
          children: [
            ...sampleEntities.map((key) {
              final seq = _sequences.firstWhere(
                (s) => s.key == key,
                orElse: () => SequenceConfigModel(key: key, prefix: key, padding: 6, currentVal: 1),
              );

              final preview = '${seq.prefix}-${seq.currentVal.toString().padLeft(seq.padding, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Entity: $key', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Preview: $preview',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, fontFamily: 'monospace', color: AppColors.deepLavender),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: seq.prefix,
                            decoration: _inputDecoration('Prefix', Icons.short_text_rounded),
                            onChanged: (val) {
                              final idx = _sequences.indexWhere((s) => s.key == key);
                              final updated = SequenceConfigModel(
                                key: key,
                                prefix: val.trim().toUpperCase(),
                                padding: seq.padding,
                                currentVal: seq.currentVal,
                              );
                              if (idx >= 0) {
                                _sequences[idx] = updated;
                              } else {
                                _sequences.add(updated);
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: [4, 6, 8].contains(seq.padding) ? seq.padding : 6,
                            decoration: _inputDecoration('Padding', Icons.format_shapes_rounded),
                            items: const [
                              DropdownMenuItem(value: 4, child: Text('4 Digits (0001)')),
                              DropdownMenuItem(value: 6, child: Text('6 Digits (000001)')),
                              DropdownMenuItem(value: 8, child: Text('8 Digits (00000001)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                final idx = _sequences.indexWhere((s) => s.key == key);
                                final updated = SequenceConfigModel(
                                  key: key,
                                  prefix: seq.prefix,
                                  padding: val,
                                  currentVal: seq.currentVal,
                                );
                                if (idx >= 0) {
                                  _sequences[idx] = updated;
                                } else {
                                  _sequences.add(updated);
                                }
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.save_rounded, color: AppColors.deepLavender),
                          tooltip: 'Save Sequence Config',
                          onPressed: () async {
                            final curSeq = _sequences.firstWhere((s) => s.key == key, orElse: () => seq);
                            await ApiRepository.saveSequenceConfig(curSeq);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sequence config for $key saved! 🔢')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // --- 4. Loyalty Engine Tab ---
  Widget _buildLoyaltyEngineTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildSectionCard(
          title: 'Loyalty Rewards Program',
          subtitle: 'Configure dynamic point-to-cash redemption tiers and bracket earning rules',
          icon: Icons.card_giftcard_rounded,
          iconBg: AppColors.pastelMint,
          iconColor: AppColors.deepMint,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Customer Loyalty Points', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(_loyaltyEnabled ? 'Reward points accrual & redemption active' : 'Loyalty system disabled store-wide', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              value: _loyaltyEnabled,
              activeThumbColor: AppColors.deepMint,
              onChanged: (val) => setState(() => _loyaltyEnabled = val),
            ),
            if (_loyaltyEnabled) ...[
              const Divider(height: 20),
              const Text('Point Redemption Discount Tiers:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
              ..._redemptionRules.asMap().entries.map((e) {
                final idx = e.key;
                final r = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.stars_rounded, size: 16, color: AppColors.deepMint),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${r.pointsRequired.toStringAsFixed(0)} Points = ${Formatters.currency(r.discountAmount)} Discount',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: r.enabled,
                        activeThumbColor: AppColors.deepMint,
                        onChanged: (val) {
                          setState(() {
                            _redemptionRules[idx] = LoyaltyRedemptionRule(
                              id: r.id,
                              pointsRequired: r.pointsRequired,
                              discountAmount: r.discountAmount,
                              enabled: val,
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.deepCoral),
                        onPressed: () {
                          setState(() {
                            _redemptionRules.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.deepMint, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final ptsCtrl = TextEditingController(text: '50');
                  final discCtrl = TextEditingController(text: '15');

                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Add Redemption Tier', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: ptsCtrl, keyboardType: TextInputType.number, decoration: _inputDecoration('Points Required', Icons.stars_rounded)),
                          const SizedBox(height: 10),
                          TextField(controller: discCtrl, keyboardType: TextInputType.number, decoration: _inputDecoration('Discount Amount (₹)', Icons.savings_outlined)),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepMint, foregroundColor: Colors.white),
                          onPressed: () {
                            final pts = double.tryParse(ptsCtrl.text.trim()) ?? 0.0;
                            final disc = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                            if (pts > 0 && disc > 0) {
                              setState(() {
                                _redemptionRules.add(LoyaltyRedemptionRule(
                                  id: 'red-${DateTime.now().millisecondsSinceEpoch}',
                                  pointsRequired: pts,
                                  discountAmount: disc,
                                  enabled: true,
                                ));
                              });
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Text('Add Tier'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.deepMint),
                label: const Text('Add Redemption Tier', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepMint)),
              ),

              const Divider(height: 24),
              const Text('Point Earning Rules (Bill Tier Engine):', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
              ..._earningRules.asMap().entries.map((e) {
                final idx = e.key;
                final r = e.value;
                final maxStr = r.maxBillAmount != null ? Formatters.currency(r.maxBillAmount!) : 'Above';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.pastelSky,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.loyalty_rounded, size: 16, color: AppColors.deepSky),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bill: ${Formatters.currency(r.minBillAmount)} - $maxStr = ${r.pointsEarned.toStringAsFixed(0)} ⭐ Pts',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: r.enabled,
                        activeThumbColor: AppColors.deepSky,
                        onChanged: (val) {
                          setState(() {
                            _earningRules[idx] = LoyaltyRule(
                              id: r.id,
                              ruleName: r.ruleName,
                              minBillAmount: r.minBillAmount,
                              maxBillAmount: r.maxBillAmount,
                              pointsEarned: r.pointsEarned,
                              enabled: val,
                              sortOrder: r.sortOrder,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ],
    );
  }

  // --- 5. WhatsApp & Email Integration Tab ---
  Widget _buildEmailWhatsAppTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Social & Instant Receipt Sharing',
            subtitle: 'Enable or disable digital invoice dispatch via WhatsApp, Telegram, and SMS',
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: AppColors.pastelMint,
            iconColor: AppColors.deepMint,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Instant WhatsApp Receipt Sharing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Allows sending receipt text & UPI payment links directly to customer WhatsApp', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _whatsAppSharingEnabled,
                activeThumbColor: const Color(0xFF25D366),
                onChanged: (val) => setState(() => _whatsAppSharingEnabled = val),
              ),
              const Divider(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Telegram Receipt Sharing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Enables Telegram dispatch shortcut on invoice modal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: true,
                activeThumbColor: AppColors.deepSky,
                onChanged: (val) {},
              ),
              const Divider(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable SMS / Text Receipt Prompt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Enables native SMS receipt messaging fallback', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: true,
                activeThumbColor: AppColors.deepAmber,
                onChanged: (val) {},
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'EmailJS Client-Side PDF Delivery',
            subtitle: 'Send generated invoice PDFs directly to customer emails without requiring a mail server',
            icon: Icons.mark_email_read_rounded,
            iconBg: AppColors.pastelSky,
            iconColor: AppColors.deepSky,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable EmailJS Invoice Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text(_emailEnabled ? 'Email dispatch active' : 'Email dispatch disabled', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _emailEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setState(() => _emailEnabled = val),
              ),
              if (_emailEnabled) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _emailServiceIdCtrl,
                  decoration: _inputDecoration('EmailJS Service ID', Icons.dns_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailTemplateIdCtrl,
                  decoration: _inputDecoration('EmailJS Template ID', Icons.article_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailPublicKeyCtrl,
                  decoration: _inputDecoration('EmailJS Public Key / User ID', Icons.key_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- 6. Security & Super Admin Controls Tab ---
  Widget _buildSecurityPurgeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Super Admin Security PIN',
            subtitle: 'Authorization PIN required for discount overrides, ledger edits, and data purges',
            icon: Icons.security_rounded,
            iconBg: AppColors.pastelAmber,
            iconColor: AppColors.deepAmber,
            children: [
              TextField(
                controller: _adminPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Super Admin PIN (Default: 1234)', Icons.lock_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'High-Risk Business Data Purge',
            subtitle: 'Wipes transactional records (bills, payments, expenses, customer ledger history) while preserving products & settings',
            icon: Icons.delete_forever_rounded,
            iconBg: AppColors.pastelCoral,
            iconColor: AppColors.deepCoral,
            children: [
              const Text(
                'Caution: This action cannot be undone. Requires dual authorization (Super Admin PIN + "DELETE" uppercase confirmation phrase).',
                style: TextStyle(fontSize: 12, color: AppColors.deepCoral, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepCoral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showPurgeDataModal,
                  icon: const Icon(Icons.warning_rounded, size: 18),
                  label: const Text('Purge Transactional Data', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Logout Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderCoral, width: 1.5),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pastelCoral,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.deepCoral, size: 20),
              ),
              title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepCoral)),
              subtitle: const Text('Clear local session cache and log out of the POS terminal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              onTap: () async {
                await ApiRepository.signOut();
                widget.onSignOut();
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 7. Backup & Restore Tab ---
  Widget _buildBackupRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Portable Database Snapshot',
            subtitle: 'Export and download complete database snapshot (settings, sequences, catalog, ledger, bills, and audit logs)',
            icon: Icons.backup_rounded,
            iconBg: AppColors.pastelLavender,
            iconColor: AppColors.deepLavender,
            children: [
              const Text(
                'The Portable JSON Snapshot contains complete store records including Shop Settings, Billing Rules, Master Products, Customer Directory, Historical Invoices, Expenses, and Immutable Audit Trail Logs.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepLavender,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _handleBackupExport,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Database Backup (JSON)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.neoBorder, width: 1.2),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
