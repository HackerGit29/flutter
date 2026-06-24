const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const {
      messages,
      temperature = 0.2,
      max_tokens = 600,
    }: {
      messages?: ChatMessage[];
      temperature?: number;
      max_tokens?: number;
    } = await req.json();

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return jsonResponse({ error: "messages is required" }, 400);
    }

    const endpoint = requireEnv("AZURE_OPENAI_ENDPOINT");
    const apiKey = requireEnv("AZURE_OPENAI_API_KEY");
    const deployment = requireEnv("AZURE_OPENAI_DEPLOYMENT");
    const apiVersion =
      Deno.env.get("AZURE_OPENAI_API_VERSION") ?? "2024-10-21";

    const url =
      `${endpoint.replace(/\/$/, "")}` +
      `/openai/deployments/${encodeURIComponent(deployment)}` +
      `/chat/completions?api-version=${encodeURIComponent(apiVersion)}`;

    const azureResponse = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": apiKey,
      },
      body: JSON.stringify({
        messages,
        temperature,
        max_tokens,
      }),
    });

    const raw = await azureResponse.text();

    if (!azureResponse.ok) {
      console.error("[Azure Phi error]", raw);

      return jsonResponse(
        {
          error: "Azure model request failed",
          status: azureResponse.status,
          details: safeJson(raw),
        },
        azureResponse.status,
      );
    }

    const data = JSON.parse(raw);

    const content =
      data?.choices?.[0]?.message?.content ??
      data?.choices?.[0]?.text ??
      null;

    return jsonResponse({
      success: true,
      content,
      raw: data,
    });
  } catch (error) {
    console.error("[ai-chat] Error:", error);

    return jsonResponse(
      {
        error: "Internal server error",
        message: String(error),
      },
      500,
    );
  }
});

function requireEnv(name: string): string {
  const value = Deno.env.get(name);

  if (!value) {
    throw new Error(`${name} is required`);
  }

  return value;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function safeJson(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}
