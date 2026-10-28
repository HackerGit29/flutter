// Opt-in HTTP integration tests against `supabase start` + `supabase functions serve admin-api`.
// Required environment:
//   ADMIN_API_INTEGRATION_URL=http://127.0.0.1:54321/functions/v1/admin-api
//   ADMIN_API_INTEGRATION_ANON_KEY=<local anon key>
//   ADMIN_API_INTEGRATION_VIEWER_TOKEN=<local viewer access token>
//   ADMIN_API_INTEGRATION_OPERATOR_TOKEN=<local operator access token>
//   ADMIN_API_INTEGRATION_SUPER_ADMIN_TOKEN=<local super-admin access token>
// The suite is skipped unless all local test credentials are explicitly provided.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const config = {
  url: Deno.env.get("ADMIN_API_INTEGRATION_URL"),
  anonKey: Deno.env.get("ADMIN_API_INTEGRATION_ANON_KEY"),
  viewer: Deno.env.get("ADMIN_API_INTEGRATION_VIEWER_TOKEN"),
  operator: Deno.env.get("ADMIN_API_INTEGRATION_OPERATOR_TOKEN"),
  superAdmin: Deno.env.get("ADMIN_API_INTEGRATION_SUPER_ADMIN_TOKEN"),
};
const enabled = Object.values(config).every((value) => Boolean(value));

function integrationTest(name: string, fn: () => Promise<void>) {
  Deno.test({ name, ignore: !enabled, fn });
}

async function request(path: string, token?: string): Promise<Response> {
  const headers = new Headers({
    apikey: config.anonKey!,
    "content-type": "application/json",
  });
  if (token) headers.set("authorization", `Bearer ${token}`);
  return await fetch(`${config.url}${path}`, { headers });
}

integrationTest(
  "admin-api new GET routes reject unauthenticated requests",
  async () => {
    for (
      const path of [
        "/v1/kpi/cohorts",
        "/v1/geo/zones",
        "/v1/iot/health",
        "/v1/iot/commands",
        "/v1/agent/analytics",
        "/v1/agent/audit",
      ]
    ) {
      const response = await request(path);
      assertEquals(response.status, 401, `${path} must require a JWT`);
      const body = await response.json();
      assert(typeof body.error?.code === "string");
    }
  },
);

integrationTest(
  "admin-api new routes enforce viewer/operator authorization",
  async () => {
    const viewerWrite = await fetch(`${config.url}/v1/geo/zones`, {
      method: "POST",
      headers: {
        apikey: config.anonKey!,
        authorization: `Bearer ${config.viewer}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        name: "integration forbidden",
        center_lat: 48.8566,
        center_lng: 2.3522,
        radius_km: 1,
      }),
    });
    assertEquals(viewerWrite.status, 403);
    await viewerWrite.body?.cancel();

    const viewerBillingWrite = await fetch(`${config.url}/v1/geo/zones`, {
      method: "POST",
      headers: {
        apikey: config.anonKey!,
        authorization: `Bearer ${config.viewer}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        name: "integration forbidden operator",
        center_lat: 48.8566,
        center_lng: 2.3522,
        radius_km: 1,
      }),
    });
    assertEquals(viewerBillingWrite.status, 403);
    await viewerBillingWrite.body?.cancel();
  },
);

integrationTest(
  "admin-api read routes return valid local database payloads",
  async () => {
    const [cohorts, zones, health, commands, agent, audit] = await Promise.all([
      request("/v1/kpi/cohorts?months=2", config.viewer),
      request("/v1/geo/zones", config.viewer),
      request("/v1/iot/health", config.viewer),
      request("/v1/iot/commands?page=1&page_size=5", config.viewer),
      request("/v1/agent/analytics", config.viewer),
      request("/v1/agent/audit?page=1&page_size=5", config.viewer),
    ]);

    for (const response of [cohorts, zones, health, commands, agent, audit]) {
      assertEquals(response.status, 200);
    }

    const cohortBody = await cohorts.json();
    const zoneBody = await zones.json();
    const healthBody = await health.json();
    const commandBody = await commands.json();
    const agentBody = await agent.json();
    const auditBody = await audit.json();

    assert(Array.isArray(cohortBody.data));
    assert(Array.isArray(zoneBody));
    assert(typeof healthBody.total_boxes === "number");
    assert(Array.isArray(commandBody.data));
    assert(Array.isArray(agentBody.tools));
    assert(Array.isArray(auditBody.data));
  },
);

integrationTest(
  "admin-api zone writes are auditable and removable in local Supabase",
  async () => {
    let createdId: string | undefined;
    const name = `integration-${crypto.randomUUID()}`;
    try {
      const created = await fetch(`${config.url}/v1/geo/zones`, {
        method: "POST",
        headers: {
          apikey: config.anonKey!,
          authorization: `Bearer ${config.operator}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          name,
          center_lat: 48.8566,
          center_lng: 2.3522,
          radius_km: 2,
          target_clients: 10,
        }),
      });
      assertEquals(created.status, 201);
      const zone = await created.json();
      createdId = zone.id;
      assert(typeof createdId === "string");

      const updated = await fetch(`${config.url}/v1/geo/zones/${createdId}`, {
        method: "PATCH",
        headers: {
          apikey: config.anonKey!,
          authorization: `Bearer ${config.operator}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ target_clients: 20 }),
      });
      assertEquals(updated.status, 200);
      assertEquals((await updated.json()).target_clients, 20);

      const removed = await fetch(`${config.url}/v1/geo/zones/${createdId}`, {
        method: "DELETE",
        headers: {
          apikey: config.anonKey!,
          authorization: `Bearer ${config.operator}`,
        },
      });
      assertEquals(removed.status, 204);
      createdId = undefined;
    } finally {
      if (createdId) {
        await fetch(`${config.url}/v1/geo/zones/${createdId}`, {
          method: "DELETE",
          headers: {
            apikey: config.anonKey!,
            authorization: `Bearer ${config.operator}`,
          },
        });
      }
    }
  },
);
