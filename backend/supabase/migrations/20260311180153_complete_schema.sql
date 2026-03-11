-- augment users table
ALTER TABLE users
  ADD COLUMN consent_given boolean DEFAULT false,
  ADD COLUMN role text DEFAULT 'user';

-- an index on users.role for admin queries
CREATE INDEX ON users(role);

-- audit logging function and triggers
CREATE OR REPLACE FUNCTION log_audit() RETURNS trigger AS $$
BEGIN
  INSERT INTO audit_logs(user_id, action, table_name, record_id, timestamp)
  VALUES (
    current_setting('request.jwt.claims.user_id', true)::uuid,
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id)::uuid,
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- attach audit trigger to major tables
DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN (
    'users','fraud_numbers','fraud_reports','subscriptions','alerts'
  ) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS audit_%s ON %s;', tbl, tbl);
    EXECUTE format('CREATE TRIGGER audit_%s
      AFTER INSERT OR UPDATE OR DELETE ON %s
      FOR EACH ROW EXECUTE FUNCTION log_audit();', tbl, tbl);
  END LOOP;
END$$;

-- make sure service-role-only write is enforced at RLS level by adding USING
ALTER TABLE fraud_numbers FORCE ROW LEVEL SECURITY;
-- additional policies already allow public read; write via service role implicitly

-- create view for admin to inspect reports easily
CREATE OR REPLACE VIEW admin_fraud_reports AS
SELECT fr.*, u.phone as reporter_phone, u.region
FROM fraud_reports fr
LEFT JOIN users u ON fr.user_id = u.id;

-- RLS on views is unsupported; enforce admin check in application logic.

-- create roles table if later needed
CREATE TABLE IF NOT EXISTS roles (
  name text PRIMARY KEY,
  description text
);

-- insert baseline roles
INSERT INTO roles(name, description) VALUES
('user','regular authenticated user')
ON CONFLICT DO NOTHING;

INSERT INTO roles(name, description) VALUES
('admin','administrator with elevated access')
ON CONFLICT DO NOTHING;

