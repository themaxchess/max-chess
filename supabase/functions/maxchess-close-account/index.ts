import { createClient } from "npm:@supabase/supabase-js@2.58.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Sends the confirmation email through Resend when RESEND_API_KEY and MAIL_FROM
// are set as function secrets. Returns false (and the account is still closed)
// when email is not configured or the provider rejects the request.
async function sendClosedEmail(to: string | undefined, name: string): Promise<boolean> {
  const apiKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const from = Deno.env.get("MAIL_FROM") ?? "";
  if (!apiKey || !from || !to) return false;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [to],
        subject: "Your MaxChess account has been closed",
        text:
          `Hi ${name},\n\n` +
          "Your MaxChess account was closed at your request, and you can no longer sign in with it.\n\n" +
          "If you did not ask for this, please contact the MaxChess site owner.\n",
      }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return reply({ error: "Sign in first." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !publicKey || !serviceKey) {
    return reply({ error: "Server configuration is incomplete." }, 500);
  }

  const userClient = createClient(supabaseUrl, publicKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  // Privileged client: stays inside this function and is only used after the
  // caller has been verified and has typed the confirmation word.
  const serverClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const token = authHeader.slice("Bearer ".length);
    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    const user = userData?.user;
    if (userError || !user) return reply({ error: "Your sign-in has expired. Please sign in again." }, 401);

    const body = await req.json().catch(() => ({}));
    if (body?.confirm !== "CLOSE") return reply({ error: "Type CLOSE to confirm." }, 400);

    const name = String(user.user_metadata?.username ?? "player").slice(0, 60);

    // 1. End any active games as a loss for the closing player.
    const { data: active } = await serverClient
      .from("games")
      .select("id, white_player")
      .eq("status", "active")
      .or(`white_player.eq.${user.id},black_player.eq.${user.id}`);
    for (const g of active ?? []) {
      await serverClient
        .from("games")
        .update({ status: g.white_player === user.id ? "black_won" : "white_won" })
        .eq("id", g.id)
        .eq("status", "active");
    }

    // 2. Best-effort cleanup of social and queue data (errors are ignored on purpose).
    await Promise.allSettled([
      serverClient.from("matchmaking_queue").delete().eq("user_id", user.id),
      serverClient.from("friendships").delete().or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`),
      serverClient.from("tournament_players").delete().eq("user_id", user.id),
      serverClient.from("profiles").delete().eq("id", user.id),
    ]);

    // 3. Disable sign-in permanently. This is a ban, not a hard delete, so the
    //    account can still be restored from the Supabase dashboard if needed.
    const { error: banError } = await serverClient.auth.admin.updateUserById(user.id, {
      ban_duration: "876000h",
    });
    if (banError) return reply({ error: banError.message }, 400);

    try {
      await serverClient.auth.admin.signOut(token, "global");
    } catch {
      // The browser also signs out locally; nothing else to do.
    }

    const emailed = await sendClosedEmail(user.email, name);
    return reply({ ok: true, emailed });
  } catch (error) {
    return reply({ error: error instanceof Error ? error.message : "Could not close the account." }, 400);
  }
});
