// Deletes the signed-in person's account (App Store rule: accounts made in
// the app can be deleted in the app). Tables that belong to a user cascade
// from auth.users, so their rows go with it.
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

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    data.user.id,
  );
  if (deleteError) {
    console.error("deleteUser failed", deleteError.message);
    return json(500, { error: "Couldn't delete the account" });
  }
  return json(200, { deleted: true });
});
