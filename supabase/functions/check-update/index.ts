import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-app-version",
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
    (a: any) => a.name === "app-release.apk",
  );

  // Client reports its current version (e.g. "1.3.0+1") via header.
  // Compare to tag_name so we only return updateAvailable=true when newer.
  const remoteTag = (release.tag_name ?? "v0").replace(/^v/, "");
  const remoteVer = parseSemver(remoteTag);
  const clientRaw = req.headers.get("x-app-version") ?? "0.0.0+0";
  const clientVer = parseSemver(clientRaw.split("+")[0]);
  const newer = compareSemver(remoteVer, clientVer) > 0;

  return new Response(JSON.stringify({
    updateAvailable: newer && !!apkAsset?.browser_download_url,
    version: remoteTag,
    buildNumber: release.id,
    apkUrl: apkAsset?.browser_download_url ?? null,
    releaseNotes: "",
    forceUpdate: false,
    releaseDate: release.published_at,
  }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

function parseSemver(input: string): [number, number, number] {
  const m = String(input).trim().match(/^(\d+)\.(\d+)(?:\.(\d+))?/);
  return [
    Number(m?.[1] ?? 0),
    Number(m?.[2] ?? 0),
    Number(m?.[3] ?? 0),
  ];
}

function compareSemver(
  a: [number, number, number],
  b: [number, number, number],
): number {
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) return a[i] - b[i];
  }
  return 0;
}
