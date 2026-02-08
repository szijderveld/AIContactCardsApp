export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    if (request.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders() });
    }

    let payload;
    try {
      payload = await request.json();
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

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json",
  };
}
