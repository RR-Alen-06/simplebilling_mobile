# SimpleBilling & PrintPro ERP Mobile App (Flutter)

A native cross-platform Flutter mobile application (iOS, Android, macOS, Windows) for retail billing, Xerox, printing shops, customer ledgers, and inventory management.

> **Note**: This repository is an independent, standalone Flutter mobile application that connects to and shares the same Supabase PostgreSQL backend as the separate **SimpleBilling** Next.js web application repository.

---

## Environment Variables Setup

Create a .env file at the root of the repository (or copy from .env.example):

`env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
`

You can also pass them during compilation or CI/CD via --dart-define:
`ash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-key
`

---

## How to Run

1. **Install dependencies**:
   `ash
   flutter pub get
   `

2. **Run tests**:
   `ash
   flutter test
   `

3. **Launch the application**:
   `ash
   flutter run
   `

---

## Features & Modules Included

1. **Auth**: Supabase Auth session listener with user-scoped cache clearing on sign-out.
2. **Dashboard**: Live metrics (Today''s sales, Monthly sales, Income vs Expense, Net profit, Customer dues).
3. **POS & Xerox Billing**: Single-tap Xerox presets, custom print job calculator, loyalty tier discounts, customer advance deduction, and split payment (Cash + UPI).
4. **Manage Bills**: Historical bills lookup and native ESC/POS 80mm thermal receipt & A4 invoice printing.
5. **Customers & Ledger**: Customer directory with debt and advance balance badges, plus instant onboarding.
6. **Products & Inventory**: Catalog management with category filtering and real-time price updates.
7. **Expenses**: Shop operational expense logging (Rent, Electricity, Supplies, Others).
8. **Reports & Analytics**: Tabbed Daily Sales, Monthly Sales, and Customer Dues breakdown.
9. **Audit Trail**: Security and financial mutation audit trail.
10. **Settings**: Store profile editor (Business Name, Phone, Address, GSTIN) and session management.
