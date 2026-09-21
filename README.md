# SimpleBilling & PrintPro ERP Mobile App (Flutter)

A native cross-platform Flutter application (iOS, Android, macOS, Windows) for retail billing, Xerox & photocopy centers, customer credit ledgers, and inventory management.

> **Architecture Note**: This mobile repository connects to the shared Supabase PostgreSQL backend used by the SimpleBilling Next.js web application.

---

## 🏛️ System Architecture & Data Flow

```
[ User Action: POS Checkout / Payment Collection / Expense Entry ]
                             │
                             ▼
              [ Riverpod Providers Layer ]
              - CartNotifier (StateNotifier)
              - AsyncValue Providers (billsListProvider, customersProvider)
                             │
                             ▼
               [ Domain & Repository Layer ]
              - CustomerCalculator (Dues & Balances Engine)
              - RoundingEngine (Nearest / Up / Down)
              - ApiRepository (Supabase Client Gateway)
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
   [ Supabase PostgreSQL ]         [ SyncQueueManager (Offline) ]
   - Row Level Security (RLS)      - Local SharedPreferences Queue
   - Atomic Sequence RPC           - Background Retry Engine
              │
              ▼
   [ RealtimeSyncManager ] ──> [ UI Invalidation & Auto-Refresh ]
```

---

## 🔐 Environment Variables & Security Setup

### Local Development
Create a `.env` file at the root of the repository (or copy from `.env.example`):
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
```

### Production Release Compilation
For production and CI/CD builds, supply keys via `--dart-define` rather than bundling `.env` into the application binary:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-key
```

---

## 🚀 How to Run & Test

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run test suite**:
   ```bash
   flutter test
   ```

3. **Run static analysis**:
   ```bash
   flutter analyze
   ```

4. **Launch application**:
   ```bash
   flutter run
   ```

---

## 📦 Features & Modules Included

1. **Auth & Security**: Supabase Auth with secure token storage and offline sandbox mode.
2. **Dashboard**: Today's sales, Monthly sales, Income vs. Expense, Net profit, and Customer debt totals.
3. **POS Terminal**: Quick Xerox presets, loyalty tier discount calculation, customer advance deduction, and split payment (Cash + UPI).
4. **Thermal Printing & PDF Invoicing**: Native ESC/POS 58mm/80mm thermal receipt generator and A4 tax invoice PDF layout.
5. **Customer Ledger**: Running balance calculations (`totalBilled`, `totalPaid`, `balanceDue`), credit receipts, and consolidated customer statement generation.
6. **Product Catalog**: Inventory management with category filtering and barcode scanning.
7. **Expense Tracker**: Operational expense logging with payment mode breakdown.
8. **Offline Queue**: Automatic background synchronization queue when network is intermittent.

---

## 🛡️ Security & Handoff References
- [Security Status & RLS Policies](file:///c:/Dev/simplebilling_mobile/security/security-status.md)
- [Risk Register](file:///c:/Dev/simplebilling_mobile/security/risk-register.md)
- [Remediation Backlog](file:///c:/Dev/simplebilling_mobile/security/remediation-backlog.md)
