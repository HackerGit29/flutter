import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-app-version, x-build-number",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ── Auth ──────────────────────────────────────────────────────────────
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

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Version client ────────────────────────────────────────────────────
  // x-app-version : "1.3.0"  (semver pur, sans build)
  // x-build-number: "1"      (buildNumber pubspec)
  const clientVersionRaw = req.headers.get("x-app-version") ?? "0.0.0";
  const clientBuildRaw = req.headers.get("x-build-number") ?? "0";
  const clientVer = parseSemver(clientVersionRaw.split("+")[0]);
  const clientBuild = parseInt(clientBuildRaw, 10) || 0;

  console.log(
    `[check-update] user=${user.id} clientVersion=${clientVersionRaw} clientBuild=${clientBuild}`,
  );

  // ── GitHub API ───────────────────────────────────────────────────────
  const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN");
  const ghHeaders: Record<string, string> = {
    Accept: "application/vnd.github.v3+json",
    "User-Agent": "aricie-update-checker",
  };
  if (GITHUB_TOKEN) ghHeaders.Authorization = `Bearer ${GITHUB_TOKEN}`;

  const repo = Deno.env.get("GITHUB_REPO") ?? "HackerGit29/flutter";
  const ghResponse = await fetch(
    `https://api.github.com/repos/${repo}/releases/latest`,
    { headers: ghHeaders },
  );

  if (!ghResponse.ok) {
    const ghBody = await ghResponse.text();
    console.error(`[check-update] GitHub ${ghResponse.status}: ${ghBody}`);
    return new Response(
      JSON.stringify({
        updateAvailable: false,
        message: "GitHub API indisponible",
        _debug: { githubStatus: ghResponse.status },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const release = await ghResponse.json();

  const remoteTag = String(release.tag_name ?? "v0.0.0");
  const remoteVersionStr = remoteTag.replace(/^v/, "");
  const remoteVer = parseSemver(remoteVersionStr);

  // buildNumber : lire version.json publié par le CI. Fallback = 0 (et NON
  // release.id) : un version.json absent/malformé ne doit pas déclencher une
  // fausse mise à jour pour tous les clients. release.id est un grand entier
  // GitHub qui ferait toujours croire à une build plus récente.
  const versionJsonAsset = release.assets?.find(
    (a: { name: string }) => a.name === "version.json",
  );
  let remoteBuild: number = 0;
  if (versionJsonAsset?.browser_download_url) {
    try {
      const vjRes = await fetch(versionJsonAsset.browser_download_url, { headers: ghHeaders });
      if (vjRes.ok) {
        const vj = await vjRes.json();
        if (typeof vj.buildNumber === "number") remoteBuild = vj.buildNumber;
      }
    } catch (_) { /* keep release.id */ }
  }

  const apkAsset = release.assets?.find(
    (a: { name: string }) => a.name === "app-release.apk",
  );

  // ── Comparaison semver + buildNumber ──────────────────────────────────
  // MAJ si : semver remote > local  OU  semver egal ET build remote > build local
  const semverCmp = compareSemver(remoteVer, clientVer);
  const isNewer = semverCmp > 0 || (semverCmp === 0 && remoteBuild > clientBuild);
  const updateAvailable = isNewer && !!apkAsset?.browser_download_url;

  console.log(
    `[check-update] remote=${remoteVersionStr}+${remoteBuild} client=${clientVersionRaw}+${clientBuild} cmp=${semverCmp} → updateAvailable=${updateAvailable}`,
  );

  // Notes de release reelles depuis GitHub (release.body, max 500 chars)
  const rawNotes = String(release.body ?? "").trim();
  const releaseNotes = rawNotes.length > 500
    ? rawNotes.slice(0, 497) + "..."
    : rawNotes || "Consultez les notes de version sur GitHub.";

  return new Response(
    JSON.stringify({
      updateAvailable,
      version: remoteVersionStr,
      buildNumber: remoteBuild,
      apkUrl: apkAsset?.browser_download_url ?? null,
      releaseNotes,
      forceUpdate: false,
      releaseDate: release.published_at ?? null,
      _debug: {
        clientVersion: clientVersionRaw,
        clientBuild,
        remoteVersion: remoteVersionStr,
        remoteBuild,
        semverCmp,
        apkFound: !!apkAsset,
      },
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});

function parseSemver(input: string): [number, number, number] {
  const m = String(input).trim().match(/^(\d+)\.(\d+)(?:\.(\d+))?/);
  return [Number(m?.[1] ?? 0), Number(m?.[2] ?? 0), Number(m?.[3] ?? 0)];
}

function compareSemver(a: [number, number, number], b: [number, number, number]): number {
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) return a[i] - b[i];
  }
  return 0;
}
