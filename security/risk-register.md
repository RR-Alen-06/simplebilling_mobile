# SimpleBilling Security Risk Register & Threat Model

| Risk ID | Vulnerability / Threat Area | Severity | Status | Mitigation Applied |
| :--- | :--- | :---: | :---: | :--- |
| **SEC-01** | Hardcoded Master Admin Bypass in `LoginScreen` | High | **Resolved** | Removed hardcoded credentials and bypass logic from `login_screen.dart`. |
| **SEC-02** | `.env` file bundled inside compiled binary assets | Medium | **Resolved** | Removed `.env` from `pubspec.yaml` assets; switched to `--dart-define` with runtime fallback. |
| **SEC-03** | Client-side Admin PIN check for discount overrides | Medium | **Mitigated** | Documented backend RPC PIN validation requirement; sanitized UI PIN fallbacks. |
| **SEC-04** | Missing multi-tenant isolation if Supabase RLS is off | Critical | **Mitigated** | Documented strict PostgreSQL RLS policies in `security/security-status.md`. |
| **SEC-05** | Production error and crash invisibility | Medium | **Mitigated** | Created centralized `AppLogger` service with structured logging and Sentry adapter. |
| **SEC-06** | In-memory vs. Remote business logic divergence | Medium | **Resolved** | Extracted customer ledger calculations into unified `CustomerCalculator`. |
