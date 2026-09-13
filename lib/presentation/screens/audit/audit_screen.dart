import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/data/models/audit_log_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/supabase_banner.dart';

final auditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  return await ApiRepository.getAuditLogs();
});

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'BILLING',
    'CUSTOMERS',
    'PRODUCTS',
    'SETTINGS',
    'EXPENSES',
    'SECURITY',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesCategory(String action, String category) {
    if (category == 'ALL') return true;
    final act = action.toUpperCase();
    switch (category) {
      case 'BILLING':
        return act.contains('BILL') || act.contains('PAYMENT') || act.contains('DISCOUNT');
      case 'CUSTOMERS':
        return act.contains('CUSTOMER') || act.contains('LEDGER') || act.contains('ADVANCE');
      case 'PRODUCTS':
        return act.contains('PRODUCT') || act.contains('PRICE') || act.contains('CATALOG');
      case 'SETTINGS':
        return act.contains('SETTING') || act.contains('SEQUENCE') || act.contains('LOYALTY');
      case 'EXPENSES':
        return act.contains('EXPENSE');
      case 'SECURITY':
        return act.contains('PURGE') || act.contains('BACKUP') || act.contains('RESTORE') || act.contains('PIN');
      default:
        return true;
    }
  }

  String _formatIstTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return isoString.length >= 16 ? isoString.substring(0, 16) : isoString;
    }
  }

  Color _getActionBgColor(String action) {
    final act = action.toUpperCase();
    if (act.contains('DELETE') || act.contains('PURGE') || act.contains('CANCEL')) {
      return AppColors.pastelCoral;
    } else if (act.contains('CREATE') || act.contains('ADD') || act.contains('RECORD')) {
      return AppColors.pastelMint;
    } else if (act.contains('UPDATE') || act.contains('EDIT')) {
      return AppColors.pastelSky;
    } else if (act.contains('BACKUP') || act.contains('EXPORT')) {
      return AppColors.pastelLavender;
    }
    return AppColors.pastelAmber;
  }

  Color _getActionTextColor(String action) {
    final act = action.toUpperCase();
    if (act.contains('DELETE') || act.contains('PURGE') || act.contains('CANCEL')) {
      return AppColors.deepCoral;
    } else if (act.contains('CREATE') || act.contains('ADD') || act.contains('RECORD')) {
      return AppColors.deepMint;
    } else if (act.contains('UPDATE') || act.contains('EDIT')) {
      return AppColors.deepSky;
    } else if (act.contains('BACKUP') || act.contains('EXPORT')) {
      return AppColors.deepLavender;
    }
    return AppColors.deepAmber;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Audit Trail & Activity Log',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Audit Trail',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(auditLogsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Supabase Live Connection Banner
          const SupabaseBanner(),

          // 2. Search & Category Filter Bar
          _buildFilterBar(),

          // 3. Detailed Audit Log Table / Feed
          Expanded(
            child: logsAsync.when(
              data: (allLogs) {
                final filtered = allLogs.where((log) {
                  final matchesCat = _matchesCategory(log.action, _selectedCategory);
                  if (!matchesCat) return false;

                  if (_searchTerm.isEmpty) return true;
                  final term = _searchTerm.toLowerCase();
                  final act = log.action.toLowerCase();
                  final ent = log.entity.toLowerCase();
                  final usr = log.userName.toLowerCase();
                  final num = log.auditNumber.toLowerCase();
                  final nVal = (log.newValue ?? '').toLowerCase();

                  return act.contains(term) ||
                      ent.contains(term) ||
                      usr.contains(term) ||
                      num.contains(term) ||
                      nVal.contains(term);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.pastelSky,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderSky, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            size: 48,
                            color: AppColors.deepSky,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No audit logs match current filters',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        if (_searchTerm.isNotEmpty || _selectedCategory != 'ALL') ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchCtrl.clear();
                                _searchTerm = '';
                                _selectedCategory = 'ALL';
                              });
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    if (isDesktop) {
                      return _buildDesktopAuditTable(filtered);
                    }
                    return _buildMobileAuditList(filtered);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, s) => Center(child: Text('Error loading audit log: $err', style: const TextStyle(color: AppColors.textSecondary))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchTerm = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search by Action, Entity, User (e.g. UPDATE_SETTINGS, Rahul, BILL-001)...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchTerm = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            ),
          ),
          const SizedBox(height: 8),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 11,
                        color: isSelected ? AppColors.deepLavender : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.pastelLavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.deepLavender : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAuditTable(List<AuditLogModel> logs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowLight, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DataTable(
            columnSpacing: 14,
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 11.5),
            dataTextStyle: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
            columns: const [
              DataColumn(label: Text('Log Seq ID')),
              DataColumn(label: Text('Timestamp (IST)')),
              DataColumn(label: Text('User / Actor')),
              DataColumn(label: Text('Action Type')),
              DataColumn(label: Text('Entity / Target Context')),
              DataColumn(label: Text('Previous State')),
              DataColumn(label: Text('Applied Update')),
            ],
            rows: logs.map((log) {
              final bgCol = _getActionBgColor(log.action);
              final textCol = _getActionTextColor(log.action);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      log.auditNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 11, color: AppColors.deepSky),
                    ),
                  ),
                  DataCell(Text(_formatIstTimestamp(log.createdAt))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.pastelLavender,
                          child: Icon(Icons.person_rounded, size: 12, color: AppColors.deepLavender),
                        ),
                        const SizedBox(width: 6),
                        Text(log.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bgCol,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: textCol.withOpacity(0.5), width: 1),
                      ),
                      child: Text(
                        log.action.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, color: textCol),
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(log.entity, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  DataCell(
                    Text(
                      log.previousValue ?? '—',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: log.previousValue != null ? AppColors.textSecondary : AppColors.textMuted),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        log.newValue ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAuditList(List<AuditLogModel> logs) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: logs.length,
      separatorBuilder: (c, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final log = logs[idx];
        final bgCol = _getActionBgColor(log.action);
        final textCol = _getActionTextColor(log.action);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          log.auditNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 10.5, color: AppColors.deepSky),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgCol,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.action.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: textCol),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatIstTimestamp(log.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Target: ${log.entity}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
              ),
              if (log.newValue != null && log.newValue!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    log.newValue!,
                    style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppColors.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 8,
                        backgroundColor: AppColors.pastelLavender,
                        child: Icon(Icons.person_rounded, size: 10, color: AppColors.deepLavender),
                      ),
                      const SizedBox(width: 4),
                      Text(log.userName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (log.previousValue != null)
                    Text('Prev: ${log.previousValue}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
