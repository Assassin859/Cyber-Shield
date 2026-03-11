# CyberShield — GitHub Copilot Instructions (AGENTS.md)

## 1. Project Summary
CyberShield is a mobile-first B2C SaaS app protecting rural Indian users from
UPI/GPay payment fraud, phishing, fake OTPs, and social engineering attacks.
The app detects fraudulent payment targets in real-time and warns users before
they complete a transaction.

**Solo developer. TypeScript across the full stack.**

Key principles:
- Mobile-first, offline-capable, low bandwidth usage
- Hindi as default language with regional support via i18n
- Supabase for database, auth, storage, realtime
- Railway for backend hosting (production + staging)
- RLS and DPDP Act compliance at all times

---

## 2. Infrastructure (Never suggest alternatives unless asked)

| Layer | Tool |
|---|---|
| Mobile | React Native + Expo (use free managed tier) |
| Backend Hosting | Railway free tier (staging + production on separate projects) |
| Database | Supabase free tier (PostgreSQL + RLS on every table) |
| Auth | Supabase Auth — Phone OTP only (no email, free) |
| Storage | Supabase Storage (screenshots, reports; free quota) |
| Realtime | Supabase Realtime (fraud alerts; free) |
| Edge Functions | Supabase Edge Functions (TypeScript; free up to limits) |
| Payments | Razorpay (UPI-native, India-first; no monthly fees) |
| Validation | Zod (all API payloads) |
| i18n | react-i18next (Hindi default, regional JSON files) |
| State / Data | React Query + React Context |
| Offline Cache | WatermelonDB or SQLite |
| Testing | Jest + @testing-library/react-native |

---

## 3. Environment Variables

### Backend (.env)
```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
RAILWAY_API_KEY
RAZORPAY_KEY_ID
RAZORPAY_KEY_SECRET
SANCHAR_SAATHI_API_KEY       # optional, if available
TRAI_SPAM_API_KEY            # optional, if available
NPCI_FRAUD_API_KEY           # optional, if available
```

### Mobile (.env with EXPO_ prefix, via expo-constants)
```
EXPO_PUBLIC_SUPABASE_URL
EXPO_PUBLIC_SUPABASE_ANON_KEY
EXPO_PUSH_TOKEN              # optional
```

Always provide `.env.example` for both backend and mobile. Never hardcode secrets.

---

## 4. Backend Architecture

### Folder Structure
```
/backend
  ├─ src
  │   ├─ controllers
  │   ├─ services
  │   ├─ routes
  │   ├─ utils
  │   ├─ middlewares
  │   ├─ types
  │   └─ index.ts
  ├─ edge-functions
  │   ├─ score.ts
  │   ├─ syncFraudData.ts
  │   └─ razorpayWebhook.ts
  ├─ tests
  └─ package.json
```

### API Routes
```
POST /api/score              # check UPI ID / phone / QR for fraud risk
POST /api/report             # user submits a fraud report
POST /api/subscribe          # handle subscription
POST /api/webhook/razorpay   # Razorpay webhook verification
GET  /api/alerts             # fetch user alerts
GET  /api/user               # fetch user profile
```

### Core Services
- **Scoring service:** normalize input → query `fraud_numbers` → return risk score (Safe / Suspicious / Dangerous)
- **Sync service:** scheduled task to pull from government APIs and update `fraud_numbers` table
- **Report service:** validate user reports, upload screenshots to Supabase Storage, deduplicate entries
- **Subscription service:** verify Razorpay webhook signature, update `subscriptions` table via service role
- **Alert service:** publish to Supabase Realtime + insert into `alerts` table
- **Auth middleware:** validate Supabase JWT on every protected route

### Validation
- Use `zod` for all request payload schemas
- All errors return a consistent shape: `{ success: false, error: string, code: string }`

---

## 5. Database Schema & RLS

### Tables
```sql
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text UNIQUE,
  name text,
  region text,
  fcm_token text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE fraud_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  value text NOT NULL,
  type text NOT NULL,       -- 'upi' | 'phone' | 'qr'
  source text,              -- 'sanchar_saathi' | 'trai' | 'user_report' etc.
  severity text,            -- 'low' | 'medium' | 'high'
  inserted_at timestamp with time zone DEFAULT now()
);

CREATE TABLE fraud_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  value text,
  type text,
  screenshot_url text,
  status text,              -- 'pending' | 'verified' | 'rejected'
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  plan text,                -- 'free' | 'premium'
  status text,              -- 'active' | 'expired' | 'cancelled'
  start timestamp with time zone,
  end timestamp with time zone
);

CREATE TABLE alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  fraud_number_id uuid REFERENCES fraud_numbers(id),
  message text,
  seen boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  action text,
  table_name text,
  record_id uuid,
  timestamp timestamp with time zone DEFAULT now()
);
```

### RLS Policies
- `users`: allow insert; select only where `auth.uid() = id`
- `fraud_numbers`: insert via service role only; public read allowed
- `fraud_reports`: insert for authenticated users; select where `user_id = auth.uid()`
- `subscriptions`: select where `user_id = auth.uid()`; insert via service role only
- `alerts`: select where `user_id = auth.uid()`; update (seen flag) by user only
- `audit_logs`: insert via service role only; select by admin only

**Always enable RLS on every new table. Never skip this.**

---

## 6. Mobile App Architecture

### Folder Structure
```
/app
  ├─ src
  │   ├─ components
  │   ├─ hooks
  │   ├─ screens
  │   ├─ services
  │   ├─ navigation
  │   ├─ assets
  │   ├─ locales
  │   │   ├─ en.json
  │   │   └─ hi.json
  │   └─ App.tsx
  ├─ App.config.js
  ├─ package.json
  └─ tsconfig.json
```

### Core Screens
- **Login** — phone OTP via Supabase Auth
- **Home** — risk score indicator (green/yellow/red) for UPI ID / phone / QR scan
- **Report** — upload screenshot, submit fraud report
- **Alerts** — realtime fraud alert feed
- **Subscription** — Razorpay checkout for premium plan

### Core Mobile Logic
- **Auth flow:** phone OTP login via Supabase client, store session in context
- **Score check:** call `POST /api/score` on paste or QR scan, display risk badge
- **Report form:** upload screenshot to Supabase Storage, submit to `POST /api/report`
- **Alert listener:** subscribe to Supabase Realtime channel for live alerts
- **Subscription:** Razorpay checkout → call backend to confirm → update local state
- **Offline sync:** cache `fraud_numbers` and `alerts` locally via WatermelonDB/SQLite

### i18n
- Use `react-i18next`, Hindi (`hi`) as default locale
- All UI strings wrapped in `t('key')` — never hardcode display text
- Store translations in `locales/hi.json` and `locales/en.json`

### State Management
- React Query for all server data fetching and caching
- React Context for auth session state only
- No Redux — keep it simple

### Permissions
- Request camera only for QR scanning
- Request contacts only if needed for number lookup
- Always show Hindi explanation before requesting any permission

---

## 7. Government API Integrations

Try to integrate in this priority order. If an API is unavailable, fall back to
syncing their publicly available fraud lists into `fraud_numbers` via cron:

| Source | Purpose | API / Resource (prioritize free/public) |
|---|---|---|
| Sanchar Saathi (DoT) | Fraud mobile number lookup | `sancharsaathi.gov.in` (public, free) |
| Cybercrime.gov.in (MHA) | National fraud registry | `cybercrime.gov.in` (public, free) |
| TRAI DND/Spam | Spam call/SMS detection | TRAI API (free tier) |
| RBI Fraud Registry | Banking fraud flags | If publicly available (no cost) |
| NPCI / UPI | UPI fraud flags | If accessible (aim for free API) |

When an API is unavailable, always suggest a fallback sync approach and flag it
clearly in comments.

---

## 8. Railway Deployment

- Two Railway projects: `cybershield-production` (main branch) and `cybershield-staging` (dev branch)
- Auto-deploy on push to respective branches
- All secrets stored as Railway environment variables — never in code
- Use separate Supabase projects and Razorpay keys for staging vs production

---

## 9. Compliance & Data Handling (DPDP Act)

- **Always** add a consent screen storing acceptance on the user record before collecting any data
- **Never** store UPI PINs, passwords, or payment credentials anywhere
- Screenshots older than 30 days must be deleted via a scheduled cron
- Minimal telemetry — analytics only with explicit opt-in
- When suggesting any data collection, remind about DPDP Act implications

---

## 10. Development Workflow

Follow this order when building features:

1. Initialize repo — add `.gitignore`, `README.md`, `.env.example`
2. Set up Supabase — create tables, enable RLS, write migration SQL
3. Bootstrap backend — Express/TS template, install Supabase client, Zod, Jest
4. Create edge functions — scoring, sync, Razorpay webhook
5. Write unit tests for all logic, run locally with `npm test`
6. Set up Railway — connect repo, configure env vars for staging + production
7. Bootstrap mobile app — `expo init`, configure Supabase client
8. Implement core screens — login, home, report, alerts
9. Add offline caching with WatermelonDB/SQLite
10. Integrate push notifications via FCM / Expo Notifications
11. Add Razorpay monetization — freemium gating via subscription status
12. Add i18n — Hindi default, English fallback, add regional languages
13. Security audit — verify RLS on all tables, check DPDP compliance
14. Write documentation — README, API spec, deployment steps
15. Set up CI — GitHub Actions for linting and tests on every PR

---

## 11. Monitoring & Logging
- Use Supabase dashboard logs for DB queries
- Use Railway logs for backend runtime errors
- Sentry (optional) — only with user consent, opt-in only

---

## 12. Future Enhancements (do not build yet, just be aware)
- Regional language audio explanations for alerts
- Offline OCR for QR code scanning
- AI/ML fraud pattern detection trained on user reports
- Web admin dashboard for viewing and managing reports

---

## 13. Copilot Behavioral Rules

When helping with this project, always:

1. **Use TypeScript** — never suggest plain JavaScript
2. **Rural user first** — assume low digital literacy, low-end Android, slow/no internet
3. **Check RLS** — every new Supabase table must have RLS enabled and policies defined
4. **Flag government API limits** — if an API is unavailable, always suggest a fallback
5. **DPDP compliance** — flag data privacy implications whenever user data is involved
6. **Offline-first thinking** — suggest caching strategies where internet may be unreliable
7. **Hindi UI** — all user-facing strings must go through `t('key')`, never hardcoded
8. **Consistent error handling** — all API responses use `{ success, data, error, code }` shape
9. **Zod validation** — validate every API request payload with a Zod schema
10. **Test coverage** — suggest unit tests for all fraud detection and scoring logic
11. **Simple over clever** — prefer battle-tested libraries, avoid over-engineering
12. **Freemium gating** — always check subscription status before serving premium features