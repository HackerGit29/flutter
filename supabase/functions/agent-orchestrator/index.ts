import { createAdminClient, getAuthenticatedUser } from "./auth.ts";
import { corsHeaders, jsonError, sseHeaders, writeSse } from "./stream.ts";
import { detectToolOrAnswer, streamFinalAnswer } from "./azure_openai.ts";
import {
  resolveApplianceByName,
  checkDeviceActionPolicy,
} from "./policy.ts";
import {
  enqueueDeviceCommand,
  getRealtimeConsumption,
  getDeviceStatus,
  getEnergyHistory,
} from "./actions.ts";
import { audit } from "./audit.ts";
import { searchUserRag } from "./rag.ts";
import type { ChatRequest, ToolCall } from "./types.ts";
import { SYSTEM_PROMPT } from "./tools.ts";

/**
 * Construit le contexte opérationnel de l'utilisateur :
 * liste de ses appareils et abonnement.
 */
async function buildOperationalContext(supabase: any, requesterId: string) {
  try {
    const { data: appliances, error } = await supabase
      .from("appliances")
      .select("name, location, is_on, relay_index")
      .eq("user_id", requesterId)
      .limit(20);

    if (error) throw error;

    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("type, is_active")
      .eq("user_id", requesterId)
      .single();

    return {
      available_appliances: appliances?.map((a: any) => ({
        name: a.name,
        location: a.location,
        is_on: a.is_on,
      })) ?? [],
      subscription_type: subscription?.type ?? "free",
      subscription_active: subscription?.is_active ?? false,
    };
  } catch (error) {
    console.error("Build operational context error:", error);
    return {
      available_appliances: [],
      subscription_type: "free",
      subscription_active: false,
    };
  }
}

/**
 * Exécute un tool call retourné par le LLM.
 * Chaque action est validée par le Policy Engine avant exécution.
 */
async function handleToolCall(params: {
  controller: ReadableStreamDefaultController<Uint8Array>;
  supabase: any;
  requesterId: string;
  toolCall: ToolCall;
}) {
  const name = params.toolCall.function.name;
  const args = JSON.parse(params.toolCall.function.arguments || "{}");

  // --- Device control tools ---
  if (name === "turn_on_appliance" || name === "turn_off_appliance") {
    const action = name === "turn_on_appliance" ? "on" : "off";
    const actionLabel = action === "on" ? "Allumage" : "Extinction";

    await writeSse(params.controller, "tool_pending", {
      tool: name,
      label: `${actionLabel} de ${args.appliance_name}`,
    });

    const resolved = await resolveApplianceByName({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceName: args.appliance_name,
    });

    if (!resolved) {
      await audit({
        supabase: params.supabase,
        requesterId: params.requesterId,
        action: name,
        targetType: "appliance",
        status: "blocked",
        details: {
          reason: "appliance_not_found_or_ambiguous",
          appliance_name: args.appliance_name,
        },
      });

      await writeSse(params.controller, "tool_result", {
        tool: name,
        success: false,
        reason: "appliance_not_found_or_ambiguous",
      });

      return {
        role: "tool" as const,
        tool_call_id: params.toolCall.id,
        content: JSON.stringify({
          success: false,
          reason:
            "Aucun appareil unique correspondant n'a été trouvé pour cet utilisateur.",
        }),
      };
    }

    const decision = await checkDeviceActionPolicy({
      supabase: params.supabase,
      requesterId: params.requesterId,
      resolved,
      action,
    });

    if (!decision.allowed) {
      await audit({
        supabase: params.supabase,
        requesterId: params.requesterId,
        action: name,
        targetType: "appliance",
        targetId: resolved.appliance_id,
        status: "blocked",
        details: {
          reason: decision.reason,
        },
      });

      await writeSse(params.controller, "tool_result", {
        tool: name,
        success: false,
        reason: decision.reason,
      });

      return {
        role: "tool" as const,
        tool_call_id: params.toolCall.id,
        content: JSON.stringify({
          success: false,
          reason: decision.reason === "rate_limit_exceeded"
            ? "Limite de commandes dépassée. Veuillez attendre une minute."
            : "Action non autorisée.",
        }),
      };
    }

    const command = await enqueueDeviceCommand({
      supabase: params.supabase,
      requesterId: params.requesterId,
      resolved,
      action,
    });

    await audit({
      supabase: params.supabase,
      requesterId: params.requesterId,
      action: name,
      targetType: "appliance",
      targetId: resolved.appliance_id,
      status: "allowed",
      details: {
        command_id: command.id,
        action,
        box_uid: resolved.box_uid,
      },
    });

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: true,
      status: "queued",
      command_id: command.id,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({
        success: true,
        status: "queued",
        appliance_name: resolved.appliance_name,
        action,
      }),
    };
  }

  // --- Lecture consommation temps réel ---
  if (name === "get_realtime_consumption") {
    await writeSse(params.controller, "tool_pending", {
      tool: name,
      label: "Lecture de la consommation en temps réel",
    });

    let applianceId: string | undefined;

    if (args.appliance_name) {
      const resolved = await resolveApplianceByName({
        supabase: params.supabase,
        requesterId: params.requesterId,
        applianceName: args.appliance_name,
      });

      if (!resolved) {
        await writeSse(params.controller, "tool_result", {
          tool: name,
          success: false,
          reason: "appliance_not_found_or_ambiguous",
        });

        return {
          role: "tool" as const,
          tool_call_id: params.toolCall.id,
          content: JSON.stringify({
            success: false,
            reason: "Appareil introuvable ou ambigu.",
          }),
        };
      }

      applianceId = resolved.appliance_id;
    }

    const consumption = await getRealtimeConsumption({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceId,
    });

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: true,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({
        success: true,
        consumption,
      }),
    };
  }

  // --- État appareil ---
  if (name === "get_device_status") {
    await writeSse(params.controller, "tool_pending", {
      tool: name,
      label: `Vérification de l'état de ${args.appliance_name}`,
    });

    const status = await getDeviceStatus({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceName: args.appliance_name,
    });

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: !!status,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({
        success: !!status,
        status,
      }),
    };
  }

  // --- Historique consommation ---
  if (name === "get_energy_history") {
    await writeSse(params.controller, "tool_pending", {
      tool: name,
      label: "Récupération de l'historique de consommation",
    });

    let applianceId: string | undefined;

    if (args.appliance_name) {
      const resolved = await resolveApplianceByName({
        supabase: params.supabase,
        requesterId: params.requesterId,
        applianceName: args.appliance_name,
      });

      if (resolved) {
        applianceId = resolved.appliance_id;
      }
    }

    const history = await getEnergyHistory({
      supabase: params.supabase,
      requesterId: params.requesterId,
      applianceId,
      period: args.period ?? "day",
    });

    await writeSse(params.controller, "tool_result", {
      tool: name,
      success: true,
    });

    return {
      role: "tool" as const,
      tool_call_id: params.toolCall.id,
      content: JSON.stringify({
        success: true,
        history,
        period: args.period ?? "day",
      }),
    };
  }

  // Tool inconnu
  return {
    role: "tool" as const,
    tool_call_id: params.toolCall.id,
    content: JSON.stringify({
      success: false,
      reason: "unknown_tool",
    }),
  };
}

// ============================================================
// Entry point : Deno.serve
// ============================================================
Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  // 1. Authentification via JWT Supabase
  let authUser;
  try {
    authUser = await getAuthenticatedUser(req);
  } catch {
    return jsonError("Non authentifié. Fournissez un token Bearer valide.", 401);
  }

  // 2. Parse body
  let body: ChatRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError("Corps JSON invalide.", 400);
  }

  if (!body.message || typeof body.message !== "string") {
    return jsonError("Le champ 'message' est requis.", 400);
  }

  // 3. Création du client admin (service_role) pour les opérations internes
  const supabase = createAdminClient();

  // 4. Flux SSE
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      try {
        // Envoyer un premier event pour confirmer la connexion
        await writeSse(controller, "connected", {
          user_id: authUser.id,
        });

        // Contexte opérationnel (scope par user_id)
        const operationalContext = await buildOperationalContext(
          supabase,
          authUser.id,
        );

        // RAG : recherche contextuelle scope par owner
        const ragContext = await searchUserRag({
          supabase,
          requesterId: authUser.id,
          query: body.message,
        });

        // Premier appel Azure OpenAI : détection d'intention + tool calling
        const firstPass = await detectToolOrAnswer({
          message: body.message,
          operationalContext,
          ragContext,
        });

        // Si pas de tool call, réponse directe
        if (!firstPass.toolCalls.length) {
          // Si réponse directe (pas de streaming pour le premier tour)
          await writeSse(controller, "token", {
            content: firstPass.text,
          });

          await writeSse(controller, "done", {});
          controller.close();
          return;
        }

        // Exécution des tool calls
        const toolMessages = [];

        for (const toolCall of firstPass.toolCalls) {
          const toolMessage = await handleToolCall({
            controller,
            supabase,
            requesterId: authUser.id,
            toolCall,
          });

          toolMessages.push(toolMessage);
        }

        // Second appel streaming : génération de la réponse finale
        const messages = [
          {
            role: "system" as const,
            content: SYSTEM_PROMPT,
          },
          {
            role: "user" as const,
            content: body.message,
          },
          firstPass.assistantMessage,
          ...toolMessages,
        ];

        let fullResponse = "";
        await streamFinalAnswer({
          messages,
          onToken: async (token: string) => {
            fullResponse += token;
            await writeSse(controller, "token", {
              content: token,
            });
          },
        });

        await writeSse(controller, "done", {});
        controller.close();
      } catch (error) {
        console.error("Orchestrator error:", error);

        // Si Azure OpenAI n'est pas configuré, message explicite
        if (
          error instanceof Error &&
          error.message.includes("Azure OpenAI non configuré")
        ) {
          await writeSse(controller, "error", {
            message:
              "L'assistant IA n'est pas encore configuré. Veuillez déployer Azure OpenAI et définir les secrets Supabase.",
            code: "azure_not_configured",
          });
        } else {
          await writeSse(controller, "error", {
            message:
              "Une erreur est survenue pendant le traitement de votre demande.",
            code: "internal_error",
          });
        }

        await writeSse(controller, "done", {});
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: sseHeaders(),
  });
});
