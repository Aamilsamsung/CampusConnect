# CampusConnect

CampusConnect is a responsive, cross-college social network MVP built with Next.js, TypeScript, Supabase, and custom-designed CSS.

## Current state
- **Preview mode:** when Supabase environment variables are missing, the website displays clearly marked, fictional demo content. Local demo posts/likes are temporary and not visible to other people. Messaging is disabled in preview.
- **Connected mode:** when Supabase is configured and the SQL schema has been installed, verified students can register, sign in, publish text posts, like posts, discover/follow students, create and join communities, and exchange direct messages.
- Planned, not yet implemented: media uploads, stories, events registration, marketplaces, comprehensive reporting/moderation, discovery rankings, and launch-grade abuse prevention.

This is a **closed-beta codebase**, not a production-ready public launch. Do not invite users until moderation, privacy controls, security review, and end-to-end testing are completed.

## Local setup
1. `npm install`
2. Copy `.env.example` to `.env.local` and set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` (public/publishable key only).
3. In Supabase SQL Editor, run `supabase/schema.sql`.
4. Add only domains that you have personally verified belong to a university and are issued to current students. Add rows to `public.college_domains` using the college IDs in `public.colleges`.
5. Configure email confirmation and Site URL in Supabase Auth.
6. `npm run dev` then open http://localhost:3000.
7. `npm run typecheck` and `npm run build` before merging.

## Deploy on Render
Create a Node web service connected to this repo, on the free plan in Singapore. Build: `npm install && npm run build`. Start: `npm run start`. Add both NEXT_PUBLIC_SUPABASE_* environment variables when your Supabase project is ready; redeploy because they are public client-side build variables. Do not add service-role secrets to NEXT_PUBLIC_*.

## Security
The SQL script enables RLS and verifies email domains in the database trigger. The verified college association cannot be edited by normal users. Never commit passwords, tokens or private configuration. There is no moderation/admin queue yet, so the app must not be treated as a publicly safe student community.
