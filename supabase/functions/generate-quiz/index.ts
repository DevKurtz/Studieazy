const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MODELS = ["gemini-3.8-flash", "gemini-3.5-flash-lite"];
const MAX_PARTS = 20;
const MAX_REQUEST_BYTES = 15_500_000;
const MAX_TEXT_CHARS = 200_000;
const MAX_INLINE_DATA_CHARS = 14_000_000;
const FIREBASE_PROJECT_ID = "self-study-app-66c44";
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

type FirebaseJwk = JsonWebKey & { kid?: string; alg?: string; use?: string };
let cachedFirebaseKeys: FirebaseJwk[] = [];
let firebaseKeysExpireAt = 0;
let lastForcedKeyRefreshAt = 0;

function decodeBase64Url(value: string): Uint8Array {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "=".repeat((4 - base64.length % 4) % 4);
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

async function getFirebasePublicKeys(forceRefresh = false): Promise<FirebaseJwk[]> {
  if (!forceRefresh && cachedFirebaseKeys.length > 0 && Date.now() < firebaseKeysExpireAt) {
    return cachedFirebaseKeys;
  }
  if (forceRefresh && cachedFirebaseKeys.length > 0 &&
    Date.now() - lastForcedKeyRefreshAt < 60_000) {
    return cachedFirebaseKeys;
  }
  if (forceRefresh) lastForcedKeyRefreshAt = Date.now();
  const response = await fetch(FIREBASE_JWKS_URL);
  if (!response.ok) throw new Error("Could not load Firebase signing keys.");
  const body = await response.json();
  if (!Array.isArray(body.keys)) throw new Error("Firebase signing keys response was invalid.");
  cachedFirebaseKeys = body.keys as FirebaseJwk[];
  const cacheControl = response.headers.get("cache-control") ?? "";
  const maxAge = Number(cacheControl.match(/max-age=(\d+)/i)?.[1] ?? 3600);
  firebaseKeysExpireAt = Date.now() + Math.max(60, maxAge) * 1000;
  return cachedFirebaseKeys;
}

async function verifyFirebaseIdToken(token: string): Promise<string | null> {
  if (token.length > 8_192) return null;
  const segments = token.split(".");
  if (segments.length !== 3) return null;

  let header: { alg?: string; kid?: string };
  let claims: {
    aud?: string;
    exp?: number;
    iat?: number;
    auth_time?: number;
    iss?: string;
    sub?: string;
  };
  try {
    header = JSON.parse(new TextDecoder().decode(decodeBase64Url(segments[0])));
    claims = JSON.parse(new TextDecoder().decode(decodeBase64Url(segments[1])));
  } catch {
    return null;
  }
  if (header.alg !== "RS256" || !header.kid) return null;

  let keys = await getFirebasePublicKeys();
  let jwk = keys.find((key) => key.kid === header.kid && key.alg === "RS256");
  if (!jwk) {
    keys = await getFirebasePublicKeys(true);
    jwk = keys.find((key) => key.kid === header.kid && key.alg === "RS256");
  }
  if (!jwk) return null;

  let validSignature = false;
  try {
    const publicKey = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    validSignature = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      decodeBase64Url(segments[2]),
      new TextEncoder().encode(`${segments[0]}.${segments[1]}`),
    );
  } catch {
    return null;
  }
  if (!validSignature) return null;

  const now = Math.floor(Date.now() / 1000);
  if (
    claims.aud !== FIREBASE_PROJECT_ID ||
    claims.iss !== FIREBASE_ISSUER ||
    typeof claims.sub !== "string" || claims.sub.length === 0 ||
    typeof claims.exp !== "number" || claims.exp <= now ||
    typeof claims.iat !== "number" || claims.iat > now + 60 ||
    typeof claims.auth_time !== "number" || claims.auth_time > now + 60
  ) return null;

  return claims.sub;
}

function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Access-Control-Expose-Headers": "Retry-After",
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

async function readJsonBody(
  request: Request,
): Promise<{ ok: true; value: unknown } | { ok: false; tooLarge: boolean }> {
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
    return { ok: false, tooLarge: true };
  }

  if (!request.body) return { ok: false, tooLarge: false };
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > MAX_REQUEST_BYTES) {
      await reader.cancel();
      return { ok: false, tooLarge: true };
    }
    chunks.push(value);
  }

  const bodyBytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bodyBytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return {
      ok: true,
      value: JSON.parse(new TextDecoder().decode(bodyBytes)),
    };
  } catch {
    return { ok: false, tooLarge: false };
  }
}

function getSupabaseSecretKey(): string | null {
  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacyKey) return legacyKey;

  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return typeof keys.default === "string" ? keys.default : null;
  } catch {
    return null;
  }
}

async function consumeAiQuizQuota(userId: string): Promise<{
  allowed: boolean;
  limitKind: string;
  retryAfterSeconds: number;
  requestId: string | null;
} | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKey = getSupabaseSecretKey();
  if (!supabaseUrl || !secretKey) return null;

  let digest: ArrayBuffer;
  try {
    digest = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(userId),
    );
  } catch {
    return null;
  }
  const userKey = Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5_000);
  try {
    const response = await fetch(
      `${supabaseUrl}/rest/v1/rpc/consume_ai_quiz_quota`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: secretKey,
          Authorization: `Bearer ${secretKey}`,
        },
        body: JSON.stringify({ p_user_key: userKey }),
        signal: controller.signal,
      },
    );
    if (!response.ok) return null;
    const rows = await response.json();
    const row = Array.isArray(rows) ? rows[0] : null;
    if (!row || typeof row.allowed !== "boolean") return null;
    const requestId = row.request_id == null ? null : String(row.request_id);
    if (row.allowed && !requestId) return null;
    return {
      allowed: row.allowed,
      limitKind: typeof row.limit_kind === "string" ? row.limit_kind : "unknown",
      retryAfterSeconds: Number(row.retry_after_seconds) || 60,
      requestId,
    };
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

async function finishAiQuizRequest(requestId: string | null): Promise<void> {
  if (!requestId) return;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKey = getSupabaseSecretKey();
  if (!supabaseUrl || !secretKey) return;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3_000);
  try {
    await fetch(`${supabaseUrl}/rest/v1/rpc/finish_ai_quiz_request`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: secretKey,
        Authorization: `Bearer ${secretKey}`,
      },
      body: JSON.stringify({ p_request_id: requestId }),
      signal: controller.signal,
    });
  } catch {
    // The lease expires automatically if the release call cannot reach Postgres.
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Use POST for quiz generation." }, 405);
  }

  // Firebase ID tokens are verified here because Supabase's gateway JWT
  // precheck only accepts Supabase-issued JWTs for this deployed function.
  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  if (!token) {
    return jsonResponse({ error: "Sign in before generating a quiz." }, 401);
  }
  let firebaseUid: string | null;
  try {
    firebaseUid = await verifyFirebaseIdToken(token);
  } catch {
    return jsonResponse({ error: "Could not verify your sign-in. Please try again." }, 401);
  }
  if (!firebaseUid) {
    return jsonResponse({ error: "Your sign-in expired or is invalid. Please sign in again." }, 401);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return jsonResponse({ error: "AI service is not configured yet." }, 503);
  }
  if (!request.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
    return jsonResponse({ error: "Send the quiz request as JSON." }, 415);
  }

  const body = await readJsonBody(request);
  if (!body.ok) {
    return body.tooLarge
      ? jsonResponse({ error: "This request is too large. Please use a smaller file." }, 413)
      : jsonResponse({ error: "Request body must be valid JSON." }, 400);
  }
  const payload = body.value as { parts?: unknown };

  if (!payload || typeof payload !== "object" || !Array.isArray(payload.parts)) {
    return jsonResponse({ error: "The request is missing document content. Please select a readable file and try again." }, 400);
  }
  if (payload.parts.length < 1) {
    return jsonResponse({ error: "No readable content was found in the selected file." }, 400);
  }
  if (payload.parts.length > MAX_PARTS) {
    return jsonResponse({ error: "Too many content parts. Please use fewer files." }, 400);
  }

  let textChars = 0;
  let inlineDataChars = 0;
  const parts: Array<Record<string, unknown>> = [];
  for (const value of payload.parts) {
    if (!value || typeof value !== "object") {
      return jsonResponse({ error: "A content part is invalid." }, 400);
    }
    const part = value as Record<string, unknown>;
    if (typeof part.text === "string") {
      textChars += part.text.length;
      if (textChars > MAX_TEXT_CHARS) {
        return jsonResponse({ error: "The document text is too large. Please use a smaller file." }, 413);
      }
      parts.push({ text: part.text });
      continue;
    }

    const inlineData = part.inlineData as Record<string, unknown> | undefined;
    if (inlineData && inlineData.mimeType === "application/pdf" &&
      typeof inlineData.data === "string") {
      inlineDataChars += inlineData.data.length;
      if (inlineDataChars > MAX_INLINE_DATA_CHARS) {
        return jsonResponse({ error: "The PDF is too large to send. Please use a smaller file." }, 413);
      }
      if (!/^[A-Za-z0-9+/]+={0,2}$/.test(inlineData.data)) {
        return jsonResponse({ error: "The PDF data is invalid." }, 400);
      }
      parts.push({
        inlineData: { mimeType: "application/pdf", data: inlineData.data },
      });
      continue;
    }

    return jsonResponse({ error: "Only text and PDF content are supported." }, 400);
  }

  // Fail closed if the database-backed limiter is not installed or reachable.
  const quota = await consumeAiQuizQuota(firebaseUid);
  if (!quota) {
    return jsonResponse({
      error: "AI service protection is temporarily unavailable. Please try again shortly.",
    }, 503);
  }
  if (!quota.allowed) {
    const waitMinutes = Math.max(1, Math.ceil(quota.retryAfterSeconds / 60));
    const message = quota.limitKind === "per_minute"
      ? `Please wait about ${waitMinutes} minute(s) before generating another quiz.`
      : quota.limitKind === "per_day"
      ? `You reached your daily AI quiz limit. Try again in about ${waitMinutes} minute(s).`
      : quota.limitKind === "concurrency"
      ? "AI is busy with other students right now. Please try again shortly."
      : "AI generation has reached today's shared capacity. Please try again later.";
    return jsonResponse({ error: message }, 429, {
      "Retry-After": String(quota.retryAfterSeconds),
    });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120_000);
  try {
    const requestBody = (model: string) => JSON.stringify({
      model,
      store: false,
      input: parts.map((part) => {
        if (typeof part.text === "string") {
          return { type: "text", text: part.text };
        }
        const inlineData = part.inlineData as {
          mimeType: string;
          data: string;
        };
        return {
          type: "document",
          mime_type: inlineData.mimeType,
          data: inlineData.data,
        };
      }),
      response_format: {
        type: "text",
        mime_type: "application/json",
      },
      generation_config: {
        thinking_level: "low",
        max_output_tokens: 8192,
      },
    });

    let result: Record<string, any> = {};
    let lastStatus = 502;
    let lastMessage = "Gemini could not generate the quiz. Please try again.";
    let succeeded = false;
    for (const model of MODELS) {
      const geminiResponse = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/interactions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
            "Api-Revision": "2026-05-20",
          },
          body: requestBody(model),
          signal: controller.signal,
        },
      );

      const responseText = await geminiResponse.text();
      try {
        result = JSON.parse(responseText);
      } catch {
        result = {};
      }
      if (geminiResponse.ok) {
        succeeded = true;
        break;
      }

      // Do not log or return the credential or submitted document content.
      lastStatus = geminiResponse.status;
      lastMessage = typeof result?.error?.message === "string"
        ? result.error.message
        : "Gemini could not generate the quiz. Please try again.";
      const isTemporaryFailure = [500, 502, 503, 504].includes(lastStatus) ||
        /high demand|temporar|overload|try again later/i.test(lastMessage);
      if (!isTemporaryFailure) {
        return jsonResponse({ error: lastMessage }, lastStatus === 429 ? 429 : 502);
      }
    }

    if (!succeeded) {
      return jsonResponse({
        error: "AI generation is temporarily unavailable. Please wait a little and try again.",
      }, 503);
    }

    const generatedText = result?.steps
      ?.filter((step: { type?: string }) => step.type === "model_output")
      ?.flatMap((step: { content?: Array<{ type?: string; text?: string }> }) =>
        step.content ?? [])
      ?.filter((content: { type?: string }) => content.type === "text")
      ?.map((content: { text?: string }) => content.text ?? "")
      .join("")
      .trim();
    if (!generatedText) {
      return jsonResponse({ error: "Gemini returned an empty response. Please try again." }, 502);
    }

    let quizResult: unknown;
    try {
      quizResult = JSON.parse(generatedText);
    } catch {
      return jsonResponse({ error: "Gemini returned an invalid quiz format. Please try again." }, 502);
    }
    return jsonResponse({ result: quizResult });
  } catch (error) {
    const message = error instanceof DOMException && error.name === "AbortError"
      ? "Quiz generation took too long. Please try a smaller file."
      : "Could not reach the AI service. Please try again.";
    return jsonResponse({ error: message }, 502);
  } finally {
    clearTimeout(timeout);
    await finishAiQuizRequest(quota.requestId);
  }
});
