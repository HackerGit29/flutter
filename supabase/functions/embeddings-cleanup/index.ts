import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async () => {
  const { data, error } = await supabase
    .from("chat_embeddings")
    .delete("owner_id IN (SELECT id FROM users WHERE deleted_at IS NOT NULL)");

  if (error) {
    return new Response(JSON.stringify({ ok: false, error }), { status: 500 });
  }

  const { count } = await supabase
    .from("chat_embeddings")
    .delete("created_at < NOW() - INTERVAL '90 days'");

  return new Response(
    JSON.stringify({ ok: true, deletedOrphaned: data, deletedStale: count }),
    { headers: { "Content-Type": "application/json" } },
  );
});
