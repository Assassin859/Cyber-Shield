-- function to sync user's role into JWT via auth.admin.set_user_attributes
create or replace function public.set_custom_claims()
returns trigger as $$
begin
  perform
    auth.admin.set_user_attributes(
      auth.uid()::text,
      json_build_object(
        'role', new.role
      )
    );
  return new;
end;
$$ language plpgsql;

create trigger sync_jwt_role
  after insert or update on users
  for each row execute procedure public.set_custom_claims();

-- example admin-only policy for audit_logs (could be triggered later)
ALTER TABLE audit_logs
  ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_only ON audit_logs FOR SELECT USING (
  current_setting('request.jwt.claims.role', true) = 'admin'
);

