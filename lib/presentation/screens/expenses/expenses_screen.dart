import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/expense_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/sync_status_badge.dart';

final expensesListProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  return await ApiRepository.getExpenses();
});

final expenseCategories = [
  'Shop Expense',
  'Electricity',
  'Rent',
  'Other Expense',
];

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  SyncStatus _getExpenseSyncStatus(
    String? clientRef,
    String id,
    List<SyncTask> tasks,
  ) {
    for (final task in tasks) {
      if (task.action == 'create_expense') {
        if ((clientRef != null && task.clientRef == clientRef) ||
            task.id == id ||
            task.clientRef == id) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = expenseCategories[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Shop Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Expense Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (title.isEmpty || amount <= 0) return;

                final clientRef = const Uuid().v4();

                // Enqueue create_expense task with unique client_ref
                await SyncQueueManager.instance.enqueueTask('create_expense', {
                  'client_ref': clientRef,
                  'title': title,
                  'amount': amount,
                  'category': category,
                }, clientRef: clientRef);

                if (mounted) {
                  ref.invalidate(expensesListProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Shop Expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(expensesListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: ValueListenableBuilder<List<SyncTask>>(
        valueListenable: SyncQueueManager.instance.tasksNotifier,
        builder: (context, tasks, child) {
          return expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Center(child: Text('No expenses logged yet'));
              }

              final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Expenses Logged:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          Formatters.currency(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: expenses.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final e = expenses[idx];
                        final syncStatus = _getExpenseSyncStatus(
                          e.clientRef,
                          e.id,
                          tasks,
                        );

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceVariant,
                              child: const Icon(
                                Icons.receipt_outlined,
                                color: AppColors.error,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SyncStatusBadge(
                                  status: syncStatus,
                                  size: 15,
                                  onRetry: () =>
                                      SyncQueueManager.instance.processQueue(),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${e.category} • ${Formatters.parseAndFormatDate(e.createdAt)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Formatters.currency(e.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.error,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await ApiRepository.deleteExpense(e.id);
                                    ref.invalidate(expensesListProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, s) => Center(child: Text('Error: ')),
          );
        },
      ),
    );
  }
}
