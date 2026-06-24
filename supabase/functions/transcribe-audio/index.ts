const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const formData = await req.formData();
    const file = formData.get("audio") as File | null;

    if (!file) {
      return jsonResponse({ error: "audio file is required" }, 400);
    }

    const endpoint = requireEnv("AZURE_OPENAI_ENDPOINT");
    const apiKey = requireEnv("AZURE_OPENAI_API_KEY");

    const url =
      `${endpoint.replace(/\/$/, "")}` +
      `/openai/deployments/gpt-4o-transcribe-aricie` +
      `/audio/transcriptions?api-version=2024-10-21`;

    const audioBytes = await file.arrayBuffer();
    const audioBlob = new Blob([audioBytes], { type: file.type || "audio/wav" });

    const azureForm = new FormData();
    azureForm.append("file", audioBlob, file.name || "audio.wav");
    azureForm.append("model", "gpt-4o-transcribe");
    azureForm.append("language", "fr");

    const azureResponse = await fetch(url, {
      method: "POST",
      headers: {
        "api-key": apiKey,
      },
      body: azureForm,
    });

    if (!azureResponse.ok) {
      const errorText = await azureResponse.text();
      console.error("[transcribe] Azure error:", errorText);
      return jsonResponse(
        { error: "Transcription failed", details: errorText },
        azureResponse.status,
      );
    }

    const result = await azureResponse.json();
    const text = (result.text || "").trim();

    if (!text) {
      return jsonResponse({ error: "Empty transcription" }, 400);
    }

    return jsonResponse({ success: true, text });
  } catch (error) {
    console.error("[transcribe] Error:", error);
    return jsonResponse({ error: String(error) }, 500);
  }
});

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
