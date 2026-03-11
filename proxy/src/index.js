export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    if (request.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders() });
    }

    // Read raw body for signature verification
    const rawBody = await request.text();

    // Verify HMAC signature
    const timestamp = request.headers.get("X-Timestamp");
    const signature = request.headers.get("X-Signature");

    if (!timestamp || !signature) {
      return Response.json({ error: "Unauthorized" }, { status: 401, headers: corsHeaders() });
    }

    // Reject if timestamp is more than 5 minutes old
    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - parseInt(timestamp, 10)) > 300) {
      return Response.json({ error: "Unauthorized" }, { status: 401, headers: corsHeaders() });
    }

    const valid = await verifySignature(env.SIGNING_SECRET, timestamp, rawBody, signature);
    if (!valid) {
      return Response.json({ error: "Unauthorized" }, { status: 401, headers: corsHeaders() });
    }

    let payload;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400, headers: corsHeaders() });
    }

    const { mode, apiKey, messages, model, output_config } = payload;
    const key = (mode === "byok" && apiKey) ? apiKey : env.CLAUDE_API_KEY;

    const body = {
      model: model || "claude-sonnet-4-5-20250929",
      max_tokens: 2048,
      messages,
    };
    if (output_config) {
      body.output_config = output_config;
    }

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": key,
        "content-type": "application/json",
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });

    const result = new Response(response.body, {
      status: response.status,
      headers: corsHeaders(),
    });
    return result;
  },
};

async function verifySignature(secret, timestamp, body, signature) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(`${timestamp}.${body}`));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  // Constant-time comparison
  if (expected.length !== signature.length) return false;
  let mismatch = 0;
  for (let i = 0; i < expected.length; i++) {
    mismatch |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return mismatch === 0;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-Timestamp, X-Signature",
    "Content-Type": "application/json",
  };
}
