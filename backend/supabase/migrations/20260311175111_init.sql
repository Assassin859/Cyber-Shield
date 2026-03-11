-- initial schema for CyberShield project

-- users
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text UNIQUE,
  name text,
  region text,
  fcm_token text,
  created_at timestamptz DEFAULT now()
);

-- fraud_numbers
CREATE TABLE fraud_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  value text NOT NULL,
  type text NOT NULL,       -- 'upi' | 'phone' | 'qr'
  source text,              -- 'sanchar_saathi' | 'trai' | 'user_report' etc.
  severity text,            -- 'low' | 'medium' | 'high'
  inserted_at timestamptz DEFAULT now()
);

-- fraud_reports
CREATE TABLE fraud_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  value text,
  type text,
  screenshot_url text,
  status text,              -- 'pending' | 'verified' | 'rejected'
  created_at timestamptz DEFAULT now()
);

-- subscriptions
CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  plan text,                -- 'free' | 'premium'
  status text,              -- 'active' | 'expired' | 'cancelled'
  start_at timestamptz,
  end_at timestamptz
);

-- alerts
CREATE TABLE alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  fraud_number_id uuid REFERENCES fraud_numbers(id),
  message text,
  seen boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- audit_logs
CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  action text,
  table_name text,
  record_id uuid,
  created_at timestamptz DEFAULT now()
);

-- Indexes for FK columns (improves join/RLS performance)
CREATE INDEX ON fraud_reports(user_id);
CREATE INDEX ON subscriptions(user_id);
CREATE INDEX ON alerts(user_id);
CREATE INDEX ON alerts(fraud_number_id);

-- enable RLS and policies

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "self_select" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "insert_user" ON users FOR INSERT WITH CHECK (auth.uid() = id);

ALTER TABLE fraud_numbers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_read" ON fraud_numbers FOR SELECT USING (true);

ALTER TABLE fraud_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_read_reports" ON fraud_reports FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "owner_insert_reports" ON fraud_reports FOR INSERT WITH CHECK (user_id = auth.uid());

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_read_subs" ON subscriptions FOR SELECT USING (user_id = auth.uid());

ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_read_alerts" ON alerts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "owner_update_alerts" ON alerts FOR UPDATE USING (user_id = auth.uid());

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
-- only service role or admins will insert/select
