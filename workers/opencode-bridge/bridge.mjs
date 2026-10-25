#!/usr/bin/env node
/**
 * aricie — OpenCode bridge
 *
 * Expose le client OpenCode local (`opencode serve`) derrière une API
 * `POST /chat/completions` au format OpenAI, consommable par l'Edge Function
 * `agent-orchestrator`.
 *
 * Pourquoi ce pont : les modèles `*-free` d'OpenCode Zen refusent les appels
 * venant d'un serveur (`403 FreeTierError: can only be used from within
 * OpenCode`). En passant par `opencode serve`, c'est le client qui exécute la
 * requête → le free tier s'applique réellement.
 *
 * Contrepartie assumée : le chat ne répond que quand la machine est allumée.
 *
 * Aucune dépendance : Node >= 18 (fetch natif).
 *
 * Env :
 *   OPENCODE_URL       URL de `opencode serve`      (défaut http://127.0.0.1:4096)
 *   OPENCODE_PROVIDER  providerID OpenCode          (défaut opencode)
 *   OPENCODE_MODEL     modelID par défaut           (défaut deepseek-v4.1-flash-free)
 *   BRIDGE_PORT        port d'écoute du pont        (défaut 4097)
 *   BRIDGE_TOKEN       si défini, exige `Authorization: Bearer <token>`
 *   BRIDGE_TIMEOUT_MS  timeout d'un appel modèle    (défaut 240000)
 */

import { createServer } from "node:http";
import { spawn } from "node:child_process";

const OPENCODE_URL = (process.env.OPENCODE_URL ?? "http://127.0.0.1:4096").replace(/\/+$/, "");
const PROVIDER = process.env.OPENCODE_PROVIDER ?? "opencode";
const DEFAULT_MODEL = process.env.OPENCODE_MODEL ?? "deepseek-v4.1-flash-free";
const PORT = Number(process.env.BRIDGE_PORT ?? 4097);
const TOKEN = process.env.BRIDGE_TOKEN ?? "";
const TIMEOUT_MS = Number(process.env.BRIDGE_TIMEOUT_MS ?? 240_000);
const AUTO_SPAWN = (process.env.BRIDGE_AUTOSPAWN ?? "true").toLowerCase() === "true";

// ------------------------------------------------------------
// Protocole d'outils (shim OpenAI → texte)
// ------------------------------------------------------------
// L'API locale d'OpenCode n'expose pas `tools`/`tool_calls` au format OpenAI :
// on transmet donc les définitions dans le prompt et on attend un JSON
// strict, que l'on reconvertit en `tool_calls` OpenAI pour l'Edge Function.
const TOOL_PROTOCOL = [
  "=== PROTOCOLE DE RÉPONSE (IMPÉRATIF) ===",
  "1. Si un outil doit être appelé, réponds EXCLUSIVEMENT par ce JSON, sans texte,",
  '   sans balise et sans bloc de code : {"tool_calls":[{"name":"<outil>","arguments":{ ... }}]}',
  "2. Sinon, réponds en français, en texte simple.",
  "3. Les arguments reprennent les noms métier du contexte (jamais d'ID technique inventé).",
].join("\n");

function contentToText(content) {
  if (content == null) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        if (part && typeof part === "object") return part.text ?? "";
        return "";
      })
      .filter(Boolean)
      .join("\n");
  }
  return String(content);
}

function buildPrompt(body) {
  const messages = Array.isArray(body.messages) ? body.messages : [];
  const blocks = [];

  const systems = messages
    .filter((m) => m.role === "system")
    .map((m) => contentToText(m.content))
    .filter(Boolean);
  if (systems.length) {
    blocks.push("=== INSTRUCTIONS SYSTÈME ===");
    blocks.push(systems.join("\n\n"));
  }

  const tools = Array.isArray(body.tools) ? body.tools : [];
  if (tools.length) {
    blocks.push("");
    blocks.push("=== OUTILS DISPONIBLES ===");
    blocks.push(JSON.stringify(tools));
    blocks.push("");
    blocks.push(TOOL_PROTOCOL);
  }

  const turns = [];
  for (const m of messages) {
    if (!m || m.role === "system") continue;
    const text = contentToText(m.content);
    if (m.role === "user") {
      if (text) turns.push(`UTILISATEUR: ${text}`);
    } else if (m.role === "assistant") {
      const calls = Array.isArray(m.tool_calls) ? m.tool_calls : [];
      const lines = [];
      if (text) lines.push(text);
      for (const call of calls) {
        const name = call?.function?.name ?? "outil";
        const args = call?.function?.arguments ?? "{}";
        lines.push(`APPEL_OUTIL: ${name} ${args}`);
      }
      if (lines.length) turns.push(`ASSISTANT: ${lines.join("\n")}`);
    } else if (m.role === "tool") {
      const id = m.tool_call_id ?? "inconnu";
      turns.push(`RÉSULTAT_OUTIL (${id}): ${text}`);
    }
  }

  if (turns.length) {
    blocks.push("");
    blocks.push("=== CONVERSATION ===");
    blocks.push(turns.join("\n\n"));
  }

  if (tools.length) {
    blocks.push("");
    blocks.push("Réponds maintenant au dernier message UTILISATEUR.");
  }

  return blocks.join("\n").trim();
}

// ------------------------------------------------------------
// Extraction des tool_calls depuis la réponse texte du modèle
// ------------------------------------------------------------
function stripFences(text) {
  return text
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/i, "")
    .trim();
}

function extractJsonCandidate(text) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) return fenced[1].trim();
  const tagged = text.match(/<tool_call>\s*([\s\S]*?)\s*<\/tool_call>/i);
  if (tagged) return tagged[1].trim();
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start !== -1 && end > start) return text.slice(start, end + 1);
  return null;
}

function toToolCalls(candidate) {
  if (!candidate) return [];
  let parsed;
  try {
    parsed = JSON.parse(candidate);
  } catch {
    return [];
  }
  const raw = Array.isArray(parsed?.tool_calls)
    ? parsed.tool_calls
    : Array.isArray(parsed)
    ? parsed
    : parsed?.name
    ? [parsed]
    : [];

  const calls = [];
  for (const item of raw) {
    const name = item?.name ?? item?.function?.name;
    if (!name || typeof name !== "string") continue;
    let args = item?.arguments ?? item?.function?.arguments ?? {};
    if (typeof args === "string") {
      try {
        args = JSON.parse(args);
      } catch {
        args = { raw: args };
      }
    }
    if (args == null || typeof args !== "object") args = {};
    calls.push({
      id: `call_${calls.length}_${Math.random().toString(36).slice(2, 10)}`,
      type: "function",
      function: { name, arguments: JSON.stringify(args) },
    });
  }
  return calls;
}

function parseResponse(text) {
  const trimmed = text.trim();
  if (!trimmed) return { content: "", toolCalls: [] };

  const looksLikeJson = trimmed.startsWith("{") || trimmed.startsWith("[") ||
    trimmed.startsWith("```") || trimmed.startsWith("<tool_call>");

  if (looksLikeJson) {
    const calls = toToolCalls(extractJsonCandidate(trimmed) ?? stripFences(trimmed));
    if (calls.length) return { content: "", toolCalls: calls };
  }
  return { content: trimmed, toolCalls: [] };
}

// ------------------------------------------------------------
// Client OpenCode
// ------------------------------------------------------------
class BridgeError extends Error {
  constructor(message, status = 502, detail) {
    super(message);
    this.name = "BridgeError";
    this.status = status;
    this.detail = detail;
  }
}

async function opencodeFetch(path, init = {}) {
  let response;
  try {
    response = await fetch(`${OPENCODE_URL}${path}`, {
      ...init,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (error) {
    throw new BridgeError(
      `client OpenCode injoignable sur ${OPENCODE_URL}`,
      503,
      error?.message ?? String(error),
    );
  }
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new BridgeError(`OpenCode ${path} → HTTP ${response.status}`, 502, detail.slice(0, 500));
  }
  return response;
}

async function runPrompt(prompt, model) {
  const created = await opencodeFetch("/session", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "aricie-bridge" }),
  });
  const session = await created.json();
  const sessionId = session?.id;
  if (!sessionId) throw new BridgeError("OpenCode n'a pas renvoyé d'identifiant de session");

  try {
    const response = await opencodeFetch(`/session/${sessionId}/message`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: { providerID: PROVIDER, modelID: model },
        parts: [{ type: "text", text: prompt }],
      }),
    });
    const message = await response.json();
    const info = message?.info ?? {};
    if (info?.error) {
      const name = info.error?.name ?? "error";
      throw new BridgeError(`OpenCode: modèle ${model} refusé (${name})`, 502, JSON.stringify(info.error).slice(0, 500));
    }
    const text = (message?.parts ?? [])
      .filter((p) => p?.type === "text")
      .map((p) => p.text ?? "")
      .join("\n")
      .trim();
    return text;
  } finally {
    // Nettoyage best-effort : on ne veut pas accumuler les sessions.
    fetch(`${OPENCODE_URL}/session/${sessionId}`, { method: "DELETE" }).catch(() => {});
  }
}

// ------------------------------------------------------------
// HTTP
// ------------------------------------------------------------
function json(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function openAiChunk({ id, created, model, delta, finishReason = null }) {
  return `data: ${JSON.stringify({
    id,
    object: "chat.completion.chunk",
    created,
    model,
    choices: [{ index: 0, delta, finish_reason: finishReason }],
  })}\n\n`;
}

function estimateTokens(text) {
  return Math.max(1, Math.ceil(String(text ?? "").length / 4));
}

function splitForStream(text) {
  // Découpage en petits groupes de mots pour un rendu progressif fluide.
  return text.match(/\S+\s*|\s+/g) ?? [];
}

async function handleChat(req, res, rawBody) {
  let body;
  try {
    body = JSON.parse(rawBody || "{}");
  } catch {
    return json(res, 400, { error: { message: "JSON invalide", type: "invalid_request_error" } });
  }

  const model = body.model || DEFAULT_MODEL;
  const prompt = buildPrompt(body);
  if (!prompt) {
    return json(res, 400, { error: { message: "messages vide", type: "invalid_request_error" } });
  }

  const startedAt = Date.now();
  const text = await runPrompt(prompt, model);
  const { content, toolCalls } = parseResponse(text);
  const id = `chatcmpl-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  const created = Math.floor(Date.now() / 1000);

  console.log(
    `[BRIDGE] ${model} • ${toolCalls.length} tool_call(s) • ${Date.now() - startedAt}ms`,
  );

  if (body.stream === true && toolCalls.length === 0) {
    res.writeHead(200, {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    });
    res.write(
      openAiChunk({ id, created, model, delta: { role: "assistant", content: "" } }),
    );
    for (const piece of splitForStream(content)) {
      res.write(openAiChunk({ id, created, model, delta: { content: piece } }));
    }
    res.write(openAiChunk({ id, created, model, delta: {}, finishReason: "stop" }));
    res.write("data: [DONE]\n\n");
    return res.end();
  }

  return json(res, 200, {
    id,
    object: "chat.completion",
    created,
    model,
    choices: [
      {
        index: 0,
        message: {
          role: "assistant",
          content: toolCalls.length ? null : content,
          ...(toolCalls.length ? { tool_calls: toolCalls } : {}),
        },
        finish_reason: toolCalls.length ? "tool_calls" : "stop",
      },
    ],
    usage: {
      prompt_tokens: estimateTokens(prompt),
      completion_tokens: estimateTokens(text),
      total_tokens: estimateTokens(prompt) + estimateTokens(text),
    },
  });
}

async function health() {
  const base = {
    bridge: "ok",
    provider: PROVIDER,
    default_model: DEFAULT_MODEL,
    opencode_url: OPENCODE_URL,
  };
  try {
    const response = await fetch(`${OPENCODE_URL}/config`, {
      signal: AbortSignal.timeout(4000),
    });
    return { ...base, opencode: response.ok ? "reachable" : `http ${response.status}` };
  } catch (error) {
    return { ...base, opencode: "unreachable", error: error?.message ?? String(error) };
  }
}

const server = createServer((req, res) => {
  const url = new URL(req.url ?? "/", `http://localhost:${PORT}`);

  if (req.method === "GET" && (url.pathname === "/health" || url.pathname === "/")) {
    return health().then((payload) => json(res, 200, payload));
  }

  if (req.method === "POST" && url.pathname === "/chat/completions") {
    if (TOKEN) {
      const auth = req.headers.authorization ?? "";
      if (auth !== `Bearer ${TOKEN}`) {
        return json(res, 401, { error: { message: "token invalide", type: "authentication_error" } });
      }
    }
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 4_000_000) req.destroy();
    });
    req.on("end", () => {
      handleChat(req, res, raw).catch((error) => {
        const status = error instanceof BridgeError ? error.status : 500;
        console.error("[BRIDGE]", error?.message ?? error, error?.detail ?? "");
        if (res.headersSent) return res.end();
        json(res, status, {
          error: {
            message: error?.message ?? "erreur bridge",
            type: "bridge_error",
            detail: error?.detail,
          },
        });
      });
    });
    return;
  }

  json(res, 404, { error: { message: "route inconnue", type: "invalid_request_error" } });
});

// ------------------------------------------------------------
// Démarrage
// ------------------------------------------------------------
function spawnOpencode() {
  if (!AUTO_SPAWN) return null;
  console.log(`[BRIDGE] démarrage de \`opencode serve --port ${new URL(OPENCODE_URL).port || 4096}\``);
  const child = spawn("opencode", ["serve", "--port", new URL(OPENCODE_URL).port || "4096"], {
    stdio: "inherit",
    shell: process.platform === "win32",
  });
  child.on("error", (error) => {
    console.error("[BRIDGE] impossible de lancer opencode :", error?.message ?? error);
    console.error("[BRIDGE] lance-le à la main : opencode serve --port 4096");
  });
  return child;
}

async function waitForOpencode(attempts = 20) {
  for (let i = 0; i < attempts; i++) {
    try {
      const response = await fetch(`${OPENCODE_URL}/config`, { signal: AbortSignal.timeout(2000) });
      if (response.ok) return true;
    } catch {
      // pas encore prêt
    }
    await new Promise((resolve) => setTimeout(resolve, 750));
  }
  return false;
}

const isReady = await waitForOpencode(1);
let child = null;
if (!isReady) {
  child = spawnOpencode();
  const ready = await waitForOpencode(20);
  if (!ready) {
    console.warn(
      `[BRIDGE] opencode ne répond pas sur ${OPENCODE_URL} — le pont démarre quand même (503 jusqu'à disponibilité).`,
    );
  }
}

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[BRIDGE] écoute sur http://127.0.0.1:${PORT}`);
  console.log(`[BRIDGE] modèle par défaut : ${PROVIDER}/${DEFAULT_MODEL}`);
  console.log(`[BRIDGE] auth : ${TOKEN ? "Bearer token requis" : "aucune (local uniquement)"}`);
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => {
    console.log(`\n[BRIDGE] ${signal} → arrêt`);
    if (child) child.kill();
    server.close(() => process.exit(0));
  });
}
