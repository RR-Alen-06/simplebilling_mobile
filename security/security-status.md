# SimpleBilling Security Status & RLS Architecture

**Status Date**: September 2026  
**Application**: SimpleBilling & PrintPro ERP Mobile App (Flutter)  
**Backend**: Supabase PostgreSQL

---

## 1. Authentication & Session Architecture

* **Client Engine**: `SupabaseConfig` ([supabase_client.dart](file:///c:/Dev/simplebilling_mobile/lib/core/network/supabase_client.dart))
* **Session Persistence**: Built-in GoTrue secure key-value token storage.
* **Offline / Guest Sandbox**: Pure local sandbox with isolated in-memory or user-scoped SharedPreferences queue (`printpro_sync_queue_<uid>`).

---

## 2. Row Level Security (RLS) PostgreSQL Policies

To enforce multi-tenant segregation, all database tables must have Row Level Security enabled with `auth.uid()` checks in Supabase:

```sql
-- 1. Enable RLS on all operational tables
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE sequences ENABLE ROW LEVEL SECURITY;

-- 2. Tenant Isolation Policies (user_id = auth.uid())
CREATE POLICY "Users can only view their own bills"
ON bills FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert their own bills"
ON bills FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only view their own customers"
ON customers FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert and update their own customers"
ON customers FOR ALL
USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own payments"
ON payments FOR ALL
USING (auth.uid() = user_id);

CREATE POLICY "Users can only access their own expenses"
ON expenses FOR ALL
USING (auth.uid() = user_id);

-- 3. Atomic Sequence RPC Generator Function
CREATE OR REPLACE FUNCTION get_next_sequence(p_key TEXT)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_padding INT;
  v_val INT;
  v_res TEXT;
BEGIN
  SELECT prefix, padding, current_val + 1
  INTO v_prefix, v_padding, v_val
  FROM sequences
  WHERE key = UPPER(p_key) AND user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    v_prefix := SUBSTRING(p_key FROM 1 FOR 3);
    v_padding := 6;
    v_val := 1;
    INSERT INTO sequences(key, prefix, padding, current_val, user_id)
    VALUES (UPPER(p_key), v_prefix, v_padding, v_val, auth.uid());
  ELSE
    UPDATE sequences
    SET current_val = v_val, updated_at = NOW()
    WHERE key = UPPER(p_key) AND user_id = auth.uid();
  END IF;

  v_res := v_prefix || '-' || LPAD(v_val::TEXT, v_padding, '0');
  RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 3. Secret Management Standard

* **Environment Variables**: Never commit `.env` with production keys or bundle `.env` in `pubspec.yaml` assets.
* **Release Compilation**: Supply publishable keys and API endpoints at compile time using `--dart-define`:
  ```bash
  flutter build apk --release \
    --dart-define=SUPABASE_URL=https://your-instance.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
  ```
