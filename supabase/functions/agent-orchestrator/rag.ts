/**
 * Calcule un embedding via Azure OpenAI (text-embedding-3-small).
 */
export async function createEmbedding(input: string): Promise<number[]> {
  const endpoint = Deno.env.get("AZURE_OPENAI_ENDPOINT");
  const apiKey = Deno.env.get("AZURE_OPENAI_API_KEY");
  const deployment = Deno.env.get("AZURE_OPENAI_EMBEDDING_DEPLOYMENT") ??
    "text-embedding-3-small";
  const apiVersion = Deno.env.get("AZURE_OPENAI_API_VERSION") ?? "2024-10-21";

  if (!endpoint || !apiKey) {
    throw new Error("Azure OpenAI non configuré pour les embeddings.");
  }

  const url =
    `${endpoint}/openai/deployments/${deployment}/embeddings?api-version=${apiVersion}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "api-key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input,
    }),
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  const json = await response.json();
  return json.data[0].embedding;
}

/**
 * Recherche les embeddings pertinents pour un utilisateur.
 * Utilise la fonction RPC match_user_embeddings scope par owner_id.
 */
export async function searchUserRag(params: {
  supabase: any;
  requesterId: string;
  query: string;
}) {
  try {
    const embedding = await createEmbedding(params.query);

    const { data, error } = await params.supabase.rpc("match_user_embeddings", {
      query_embedding: embedding,
      requester_id: params.requesterId,
      match_count: 5,
    });

    if (error) throw error;

    return data ?? [];
  } catch (error) {
    console.error("RAG search error:", error);
    return [];
  }
}
