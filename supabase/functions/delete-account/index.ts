// Deletes the signed-in person's account (App Store rule: accounts made in
// the app can be deleted in the app). Tables that belong to a user cascade
// from auth.users, so their rows go with it.
//
// Deployed with verify_jwt off: the function checks the caller's session
// itself with getUser, which works with Supabase's newer signing keys.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
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
