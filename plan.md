# CyberShield Project Plan

This document outlines the comprehensive plan to build the CyberShield rural India fraud prevention SaaS app. It covers architecture, infrastructure, backend and frontend logic, environment configuration, file structures, feature breakdown, and development workflow.

---

## 1. Overview

CyberShield is a mobile-first application designed for rural Indian users to protect them against UPI/GPay payment fraud, phishing scams, Fake OTPs, and social engineering attacks. The backend uses Supabase and Railway, while the mobile client is built using React Native with Expo.

Key principles:
- Mobile-first, offline-capable, low bandwidth usage.
- Hindi as default language with regional support via i18n.
- Supabase for database, auth, storage, realtime.
- Railway for backend hosting with production and staging.
- TypeScript across the stack.
- RLS and DPDP compliance.

## 2. Infrastructure

### 2.1 Supabase Setup
- **Database:** PostgreSQL with RLS enabled on every table (use Supabase free tier).
- **Auth:** Phone number OTP login.
- **Storage:** For screenshots, reports.
- **Realtime:** Used to push alerts.
- **Edge Functions:** For lightweight serverless logic like score calculation, scraping, validation.

Tables:
```
users
fraud_numbers
fraud_reports
subscriptions
alerts
audit_logs
```
Each table will have appropriate columns and RLS policies (below in section 4).

### 2.2 Railway Setup
- Two projects: `cybershield-production` (main), `cybershield-staging` (dev).
- Deploy from GitHub on branch push.
- Environment variables: SUPABASE_URL, SUPABASE_KEY, RAZORPAY_KEY, etc.
- Use separate credentials for staging.

### 2.3 Environment Variables
```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
RAILWAY_API_KEY               # free-tier project
RAZORPAY_KEY_ID               # Razorpay has no monthly fees
RAZORPAY_KEY_SECRET
SANCHAR_SAATHI_API_KEY?       # use public scraping if API paid
TRAI_SPAM_API_KEY?            # free tier if available
NPCI_FRAUD_API_KEY?           # prioritize free access

# Mobile-specific
EXPO_PUSH_TOKEN?              # Expo free notifications quota
```

Add .env.example for both backend and mobile.

## 3. Backend Architecture

### 3.1 Folder Structure
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

Edge functions written in TypeScript using Supabase tools. Services interact with Supabase client.

### 3.2 Core Logic
- **Scoring service:** normalize input, query `fraud_numbers`, return score.
- **Sync service:** scheduled task or manual trigger to scrape government APIs, update table.
- **Report service:** validate user reports, upload screenshots, dedupe.
- **Subscription service:** handle Razorpay webhook verification and update subscription status.
- **Alert service:** publish to realtime and store in `alerts` table.
- **Auth middleware:** validate Supabase JWT.

### 3.3 API Routes Example
```
POST /api/score
POST /api/report
POST /api/subscribe
POST /api/webhook/razorpay
GET  /api/alerts
GET  /api/user
```

### 3.4 Validation
Use `zod` for payload schemas. Error handling with consistent response shape.

## 4. Database Schema & RLS

Define SQL migrations or initial SQL scripts.

### 4.1 Tables
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
  type text NOT NULL,
  source text,
  severity text,
  inserted_at timestamp with time zone DEFAULT now()
);

CREATE TABLE fraud_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  value text,
  type text,
  screenshot_url text,
  status text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  plan text,
  status text,
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

### 4.2 RLS Policies
- `users`: allow insert; select where `auth.uid = id`.
- `fraud_numbers`: insert via service role only; select for all (public read).
- `fraud_reports`: insert for authenticated; select where `user_id=auth.uid`.
- `subscriptions`: select where user_id matches; insert via service role.
- `alerts`: select where user_id matches; update to set seen only by user.
- `audit_logs`: insert via service role; select by admin only (if needed).

## 5. Mobile App Architecture

### 5.1 Folder Structure
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
  │   └─ App.tsx
  ├─ App.config.js
  ├─ package.json
  └─ tsconfig.json
```

### 5.2 Core Logic
- **Auth flow**: phone OTP via Supabase client.
- **Score check**: call backend `/api/score` on paste/scan.
- **Report form**: upload screenshot to Supabase Storage.
- **Alert listener**: subscribe to realtime updates.
- **Subscription**: Razorpay checkout integration; call backend to confirm.
- **Offline sync**: local DB (WatermelonDB/SQLite) to cache `fraud_numbers` and `alerts`.

### 5.3 i18n
- Use `react-i18next`, store JSON in `locales/en.json`, `locales/hi.json` etc.
- Wrap texts with `t('...')`.

### 5.4 State
- Use React Query for server data.
- Keep auth state in context.

### 5.5 Testing
- Unit tests with `jest` and `@testing-library/react-native` for components and services.

### 5.6 Permissions
- Request camera/contacts only if needed (e.g., scanning QR or calling number for reporting). Provide Hindi explanations.

## 6. Development Workflow

1. **Initialize repo**: create directories above, add .gitignore, README.
2. **Set up Supabase project**: create tables and RLS
3. **Bootstrap backend**: express/ts starting template, install supabase client, zod, jest.
4. **Create edge functions**: scoring, sync, webhook.
5. **Write unit tests** for logic and run locally with `npm test`.
6. **Set up Railway**: connect repo, configure env vars.
7. **Bootstrap mobile app**: `expo init`, configure supabase client.
8. **Implement core screens**: login, home with score indicator, report, alerts.
9. **Add offline caching**.
10. **Integrate push notifications**.
11. **Add monetization with Razorpay**.
12. **Prepare i18n and add regional language resources**.
13. **Conduct security audit: ensure RLS, DPDP compliance**.
14. **Write documentation**: README, API spec, deployment steps.
15. **Prepare CI**: linting, tests on GitHub Actions.

## 7. Environment Files
- **Backend**:
  - `.env` (local dev, gitignored)
  - `.env.example`
- **Mobile**:
  - `app.config.js` referencing process.env for keys.
  - `.env` with EXPO_ prefix (use `expo-constants`).

## 8. Monitoring & Logging
- Use Supabase logs and Railway’s logs.
- Capture errors in Sentry (optional) with prior consent.

## 9. Compliance and Data Handling
- Add consent screen storing acceptance flag on user record.
- Implement data retention cleanup cron: delete screenshots >30 days.
- Minimal telemetry for analytics; opt-in required.

## 10. Future Enhancements
- Add regional language audio explanations for alerts.
- Implement offline OCR of QR codes.
- Add AI/ML fraud pattern detection using user reports.
- Provide a web dashboard for admin to view reports.

---

This plan provides the roadmap to build, deploy and maintain CyberShield. Adjust according to evolving requirements and regulatory changes. Start with core fraud detection and user flows, and incrementally add integrations and features.