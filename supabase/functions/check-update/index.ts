import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Authorization required" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN");
  const headers: Record<string, string> = {
    Accept: "application/vnd.github.v3+json",
  };
  if (GITHUB_TOKEN) headers.Authorization = `Bearer ${GITHUB_TOKEN}`;

  const repo = Deno.env.get("GITHUB_REPO") ?? "HackerGit29/flutter";
  const response = await fetch(
    `https://api.github.com/repos/${repo}/releases/latest`,
    { headers },
  );

  if (!response.ok) {
    return new Response(JSON.stringify({
      updateAvailable: false,
      message: "Aucune mise à jour disponible",
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const release = await response.json();
  const apkAsset = release.assets?.find(
    (a: any) => a.name === "aricie-release.apk",
  );

  return new Response(JSON.stringify({
    updateAvailable: true,
    version: release.tag_name.replace(/^v/, ""),
    buildNumber: release.id,
    apkUrl: apkAsset?.browser_download_url ?? null,
    releaseNotes: release.body?.slice(0, 2048) ?? release.name ?? "",
    forceUpdate: false,
    releaseDate: release.published_at,
  }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
