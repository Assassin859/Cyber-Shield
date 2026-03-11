# Cyber-Shield

Mobile‑first rural India fraud prevention SaaS app.

## Getting Started

### Prerequisites
- Node.js 18+
- npm or yarn
- Expo CLI (`npm install -g expo-cli`)
- A Supabase project (use free tier)
- Railway account (free tier)

### Backend Setup

```bash
cd backend
cp .env.example .env      # fill in keys
npm install
npm run dev
```

### Mobile App Setup

```bash
cd app
cp .env.example .env      # set EXPO_PUBLIC_SUPABASE_* vars
npm install
npm start
```

### Directory Structure

- `/backend` – Express server, edge functions, services, tests
- `/app` – Expo React Native application with screens, hooks, translations
- `plan.md` – detailed project plan and architecture
- `Agent.md` – Copilot instructions and guidelines

## Development Workflow
Refer to [plan.md](./plan.md) for full roadmap and step-by-step instructions.
