# SimpleBilling Post-Handoff Remediation Backlog

The following action items are recommended for the receiving engineer / team during subsequent sprint cycles:

---

### Priority 1: Supabase RLS Migration
- [ ] Run the SQL migration scripts in [security-status.md](file:///c:/Dev/simplebilling_mobile/security/security-status.md) on your Supabase production instance to verify that Row Level Security is active on all operational tables.
- [ ] Verify that `sequences` and `get_next_sequence` PostgreSQL RPC function are properly defined.

### Priority 2: APM & Crash Reporting Integration
- [ ] Connect `sentry_flutter` or `firebase_crashlytics` inside [app_logger.dart](file:///c:/Dev/simplebilling_mobile/lib/core/utils/app_logger.dart) `_reportToTelemetry()` method.
- [ ] Configure `SENTRY_DSN` in CI/CD pipeline variables.

### Priority 3: Offline Sync Queue Hardening
- [ ] Add exponential backoff retry policy to `SyncQueueManager.processQueue()` for unstable network environments.
- [ ] Implement conflict resolution strategy for concurrent updates to customer records between web and mobile clients.
