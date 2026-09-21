import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';

class RealtimeSyncManager {
  RealtimeSyncManager._();
  static final RealtimeSyncManager instance = RealtimeSyncManager._();

  RealtimeChannel? _billsChannel;
  RealtimeChannel? _customersChannel;
  RealtimeChannel? _productsChannel;

  void subscribe({
    required VoidCallback onBillsChanged,
    required VoidCallback onCustomersChanged,
    required VoidCallback onProductsChanged,
  }) {
    try {
      final client = SupabaseConfig.client;

      // 1. Bills & Bill Items Channel
      _billsChannel = client.channel('public:bills_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bills',
          callback: (payload) {
            debugPrint('Realtime: Bills change detected: ');
            onBillsChanged();
          },
        )
        ..subscribe();

      // 2. Customers Channel
      _customersChannel = client.channel('public:customers_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          callback: (payload) {
            debugPrint('Realtime: Customers change detected: ');
            onCustomersChanged();
          },
        )
        ..subscribe();

      // 3. Products Channel
      _productsChannel = client.channel('public:products_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            debugPrint('Realtime: Products change detected: ');
            onProductsChanged();
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('[RealtimeSyncManager] Error establishing realtime subscription: $e');
    }
  }

  void unsubscribe() {
    try {
      _billsChannel?.unsubscribe();
      _customersChannel?.unsubscribe();
      _productsChannel?.unsubscribe();
    } catch (_) {}
    _billsChannel = null;
    _customersChannel = null;
    _productsChannel = null;
  }
}