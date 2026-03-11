-- recreate admin view without RLS requirement
DROP VIEW IF EXISTS admin_fraud_reports;

CREATE OR REPLACE VIEW admin_fraud_reports AS
SELECT fr.*, u.phone as reporter_phone, u.region
FROM fraud_reports fr
LEFT JOIN users u ON fr.user_id = u.id;

-- RLS is not supported on views; enforce admin check in backend or use a function

