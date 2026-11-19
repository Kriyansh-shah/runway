// Deletes the signed-in person's account (App Store rule: accounts made in
// the app can be deleted in the app). Tables that belong to a user cascade
// from auth.users, so their rows go with it.
//
// Sign in with Apple accounts: Apple also asks apps to revoke their access
// to the Apple ID. The app sends a fresh authorization code from Apple
// ("apple_authorization_code"); it's swapped for a refresh token and that
// token is revoked. This needs four secrets (see docs/app-store-submission.md):
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (the .p8 contents),
//   APPLE_CLIENT_ID (the app's bundle ID, com.kriyanshshah.runway).
// If they're missing or Apple is unreachable, the account is still deleted;
// the failure is only logged, so a person is never stuck with an account.
//
// Deployed with verify_jwt off: the function checks the caller's session
// itself with getUser, which works with Supabase's newer signing keys.
//
// The web app calls this from another site (GitHub Pages), so the browser
// asks first (CORS). Only Runway's own site, and localhost while
// developing, get an answer; the phone apps don't send an Origin at all.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

// A client secret for Apple's token endpoints: a short-lived ES256 JWT
// signed with the Sign in with Apple key.
async function appleClientSecret(
  teamId: string,
  keyId: string,
  clientId: string,
  privateKeyPem: string,
): Promise<string> {
  const b64url = (bytes: Uint8Array) =>
    btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(
      /\//g,
      "_",
    ).replace(/=+$/, "");
  const text = (value: unknown) =>
    b64url(new TextEncoder().encode(JSON.stringify(value)));
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${text({ alg: "ES256", kid: keyId })}.${
    text({
      iss: teamId,
      iat: now,
      exp: now + 300,
      aud: "https://appleid.apple.com",
      sub: clientId,
    })
  }`;
  const der = Uint8Array.from(
    atob(
      // The key may arrive with real or escaped ("\\n") line breaks.
      privateKeyPem.replace(/-----[^-]+-----/g, "").replace(/\\n|\s+/g, ""),
    ),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  return `${unsigned}.${b64url(signature)}`;
}

// Swaps Apple's one-time authorization code for a refresh token and revokes
// it. Never throws: deletion goes ahead whatever happens here.
async function revokeApple(code: string): Promise<void> {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!teamId || !keyId || !privateKey || !clientId) {
    console.error("Apple revoke skipped: APPLE_* secrets aren't set");
    return;
  }
  try {
    const secret = await appleClientSecret(teamId, keyId, clientId, privateKey);
    const form = (fields: Record<string, string>) => ({
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(fields),
    });
    const tokenResponse = await fetch(
      "https://appleid.apple.com/auth/token",
      form({
        client_id: clientId,
        client_secret: secret,
        code,
        grant_type: "authorization_code",
      }),
    );
    const tokens = await tokenResponse.json();
    const token = tokens.refresh_token ?? tokens.access_token;
    if (!tokenResponse.ok || !token) {
      console.error("Apple token exchange failed", tokenResponse.status, tokens.error);
      return;
    }
    const revoke = await fetch(
      "https://appleid.apple.com/auth/revoke",
      form({
        client_id: clientId,
        client_secret: secret,
        token,
        token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
      }),
    );
    if (!revoke.ok) console.error("Apple revoke failed", revoke.status);
  } catch (error) {
    console.error("Apple revoke failed", String(error));
  }
}

const allowedOrigin = (origin: string | null) =>
  origin === "https://kriyansh-shah.github.io" ||
  (origin !== null && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin));

const corsHeaders = (origin: string | null): Record<string, string> =>
  allowedOrigin(origin)
    ? {
      "Access-Control-Allow-Origin": origin!,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Max-Age": "86400",
      "Vary": "Origin",
    }
    : { "Vary": "Origin" };

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
    });

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: allowedOrigin(origin) ? 204 : 403,
      headers: corsHeaders(origin),
    });
  }
  if (req.method !== "POST") return json(405, { error: "POST only" });

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json(401, { error: "Not signed in" });

  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return json(401, { error: "Not signed in" });

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    // No body: an older app version, or a Google account.
  }
  const appleCode = body["apple_authorization_code"];
  if (typeof appleCode === "string" && appleCode.length > 0) {
    await revokeApple(appleCode);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    data.user.id,
  );
  if (deleteError) {
    console.error("deleteUser failed", deleteError.message);
    return json(500, { error: "Couldn't delete the account" });
  }
  return json(200, { deleted: true });
});
