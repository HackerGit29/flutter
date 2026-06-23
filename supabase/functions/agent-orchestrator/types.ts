export type ChatRequest = {
  message: string;
  session_id?: string;
  locale?: string;
  mode?: "text" | "voice";
};

export type AuthUser = {
  id: string;
  email?: string;
};

export type ToolCall = {
  id: string;
  type: "function";
  function: {
    name: string;
    arguments: string;
  };
};

export type ResolvedAppliance = {
  appliance_id: string;
  appliance_name: string;
  box_id: string;
  box_uid: string;
  relay_index: number;
};

export type PolicyDecision = {
  allowed: boolean;
  reason?: string;
};
