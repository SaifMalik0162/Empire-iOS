import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

type NotificationEvent = {
  id: string;
  user_id: string;
  event_type: "like" | "comment" | "follow" | "meet";
  title: string;
  body: string;
  deep_link: string | null;
  payload: Record<string, unknown> | null;
};

type PushToken = {
  id: string;
  user_id: string;
  device_token: string;
  environment: string;
  bundle_id: string;
  is_active: boolean;
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const apnsTeamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const apnsKeyId = Deno.env.get("APNS_KEY_ID") ?? "";
const apnsPrivateKey = (Deno.env.get("APNS_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
const defaultBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.empireautoclub.empireconnect";

async function makeApnsJwt() {
  const key = await importPKCS8(apnsPrivateKey, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: apnsKeyId })
    .setIssuer(apnsTeamId)
    .setIssuedAt()
    .sign(key);
}

function apnsHost(environment: string) {
  return environment === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

async function deliverEventToToken(event: NotificationEvent, token: PushToken, jwt: string) {
  const response = await fetch(`${apnsHost(token.environment)}/3/device/${token.device_token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": token.bundle_id || defaultBundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: event.title,
          body: event.body,
        },
        sound: "default",
        badge: 1,
      },
      deep_link: event.deep_link,
      event_type: event.event_type,
      payload: event.payload ?? {},
    }),
  });

  if (response.ok) {
    return { ok: true as const };
  }

  const errorText = await response.text();

  if (response.status === 410 || errorText.includes("Unregistered") || errorText.includes("BadDeviceToken")) {
    await supabase
      .from("user_push_tokens")
      .update({ is_active: false })
      .eq("id", token.id);
  }

  return { ok: false as const, error: errorText || `APNs ${response.status}` };
}

Deno.serve(async () => {
  if (!apnsTeamId || !apnsKeyId || !apnsPrivateKey) {
    return new Response(JSON.stringify({
      error: "Missing APNS env configuration",
    }), { status: 500 });
  }

  const { data: events, error: eventsError } = await supabase
    .from("notification_events")
    .select("id, user_id, event_type, title, body, deep_link, payload")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(50);

  if (eventsError) {
    return new Response(JSON.stringify({ error: eventsError.message }), { status: 500 });
  }

  const pendingEvents = (events ?? []) as NotificationEvent[];
  if (pendingEvents.length === 0) {
    return new Response(JSON.stringify({ delivered: 0, failed: 0, skipped: 0 }), { status: 200 });
  }

  const userIds = [...new Set(pendingEvents.map((event) => event.user_id))];
  const { data: tokens, error: tokensError } = await supabase
    .from("user_push_tokens")
    .select("id, user_id, device_token, environment, bundle_id, is_active")
    .in("user_id", userIds)
    .eq("is_active", true);

  if (tokensError) {
    return new Response(JSON.stringify({ error: tokensError.message }), { status: 500 });
  }

  const tokensByUserId = new Map<string, PushToken[]>();
  for (const token of ((tokens ?? []) as PushToken[])) {
    const existing = tokensByUserId.get(token.user_id) ?? [];
    existing.push(token);
    tokensByUserId.set(token.user_id, existing);
  }

  const jwt = await makeApnsJwt();

  let delivered = 0;
  let failed = 0;
  let skipped = 0;

  for (const event of pendingEvents) {
    const userTokens = tokensByUserId.get(event.user_id) ?? [];

    if (userTokens.length === 0) {
      skipped += 1;
      await supabase
        .from("notification_events")
        .update({
          status: "failed",
          error_message: "No active push tokens for user",
        })
        .eq("id", event.id);
      continue;
    }

    const results = await Promise.all(userTokens.map((token) => deliverEventToToken(event, token, jwt)));
    const hasSuccess = results.some((result) => result.ok);

    if (hasSuccess) {
      delivered += 1;
      await supabase
        .from("notification_events")
        .update({
          status: "delivered",
          delivered_at: new Date().toISOString(),
          error_message: null,
        })
        .eq("id", event.id);
    } else {
      failed += 1;
      await supabase
        .from("notification_events")
        .update({
          status: "failed",
          error_message: results.map((result) => ("error" in result ? result.error : null)).filter(Boolean).join(" | "),
        })
        .eq("id", event.id);
    }
  }

  return new Response(JSON.stringify({ delivered, failed, skipped }), {
    headers: { "content-type": "application/json" },
  });
});
