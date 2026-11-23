# Supabase setup for Studieazy

The Flutter app keeps Firebase Authentication, but quiz/profile storage can use Supabase PostgreSQL. Supabase verifies each Firebase ID token; Row Level Security then limits a student to their own records.

## Dashboard steps

1. In Supabase, open **Authentication → Third-Party Auth** and add Firebase with project ID `self-study-app-66c44`.
2. Re-run the updated `supabase_schema.sql` in SQL Editor. It replaces the named owner policies to allow Firebase JWTs, which Supabase maps to its `anon` database role when they have no custom role claim. RLS still checks the Firebase UID.
3. Run `supabase_firebase_auth.sql`. It grants least-privilege Data API access, restricts access to this Firebase project issuer/audience, and protects profile roles. Its `DROP POLICY` statements only replace named policies; it does not delete rows or tables. If Supabase warns about destructive SQL, inspect that the query is this file before confirming.
4. In **Project Settings → API Keys**, copy the **publishable** key. Never use a secret/service-role key in Flutter.
5. In **Integrations → Data API**, ensure `app_users`, `quizzes`, `questions`, `support_tickets`, and `error_logs` in the `public` schema are exposed.

## Run the app against Supabase

From the project folder, run/build with the publishable key:

```powershell
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

For a web release:

```powershell
flutter build web --release --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The publishable key is intended for client-side use; RLS is the security boundary. Do not add a database password, secret key, service-role key, or Gemini key to the Flutter build.

## Enable AI quiz generation safely

The Gemini API key is used only inside `supabase/functions/generate-quiz` and is no longer read from Firestore or Flutter. The app uses the same Gemini API key; there is no separate key for each model. The function calls Gemini 3.8 Flash through Google's Interactions API, with Gemini 3.5 Flash-Lite as a capacity fallback.

Before deploying the protected version, run `supabase/migrations/202611170001_ai_quiz_rate_limit.sql` in **Supabase Dashboard → SQL Editor**. It creates a private-to-clients usage table and two service-role-only functions; it does not read or store uploaded documents. It enforces up to 2 requests per user per minute, 10 per user per rolling 24 hours, at most 10 concurrent generations, and 150 total generations per rolling 24 hours for this project. Adjust these conservative caps in the SQL if your class needs different limits.

1. In Google AI Studio, create a replacement Gemini key. Do not paste it into chat, Flutter, Firestore, or Git.
2. In the Supabase Dashboard, open **Edge Functions → Secrets** and add `GEMINI_API_KEY` with the replacement key as its value.
3. From the project folder, use the Supabase CLI through `npx`, sign in, then deploy:

   ```powershell
   npx supabase login
   npx supabase link --project-ref tqvpgvoxjmvmykzmakdj
   npx supabase functions deploy generate-quiz
   ```

4. The function's Supabase gateway JWT precheck is disabled because it rejects Firebase ID tokens before the handler runs. The handler itself verifies each Firebase ID token's RS256 signature against Google's public keys and checks the issuer, audience, expiry, issue time, and user ID for `self-study-app-66c44`; requests without a valid token are rejected.
5. Run the Flutter app with the Supabase publishable key as shown above, sign in, and try AI quiz generation with a small text or PDF file. Files are capped at 10 MB; the server also caps request-body and extracted-text size.

Never put the Gemini key into a client build. Supabase Edge Functions read it from project secrets at runtime. See [Supabase function secrets](https://supabase.com/docs/guides/functions/secrets) and [Firebase ID token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens).

On the first signed-in load for each device, the app copies that Firebase user's profile and quizzes/questions from Firestore to Supabase. It keeps the Firebase records as a fallback. New profile and quiz changes use Supabase when configured. Offline changes continue using the local cache and pending-operation queue.

## Current migration scope

Profiles, quizzes, questions, and study stats are wired to Supabase. The AI quiz request uses a Supabase Edge Function, validates the app's Firebase ID token server-side, and calls Gemini 3.8 Flash through the Interactions API with `store=false`. It needs an active Gemini key saved as a Supabase Function Secret and the latest function deployed. OTP verification, Firebase Auth, admin dashboard, support/admin operations, error logging, and backup/restore still use Firebase/Firestore and need separate migration work. Keep the Firebase project active until those flows are migrated and verified.
