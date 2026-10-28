import { adminFetch, adminList } from './client';
import type {
  AdminActionLog,
  AdminNote,
  AdminSubscription,
  AdminUser,
  AgentAnalytics,
  CoverageResponse,
  DeviceCommandStatus,
  IotHealth,
  KpiSummary,
  NoteTargetType,
  Paginated,
} from '../types/admin';

export interface CoverageZoneRecord {
  id: string;
  name: string;
  center_lat: number;
  center_lng: number;
  radius_km: number;
  target_clients: number;
  is_active: boolean;
  created_at: string;
}

export interface IotCommand {
  id: string;
  box_id: string;
  user_id: string;
  action: 'on' | 'off';
  appliance_name: string | null;
  requested_by: string;
  status: DeviceCommandStatus | 'processing';
  created_at: string;
  sent_at: string | null;
  acknowledged_at: string | null;
  error_message: string | null;
  ack_payload: Record<string, unknown> | null;
  latency_ms: number | null;
}

export interface AgentAnalyticsResponse extends AgentAnalytics {
  confirmation_events_tracked: boolean;
  pending_tool_actions_observed: number;
}

export interface AdminUserListItem {
  id: string;
  email: string;
  role: 'user' | 'vip' | 'admin';
  admin_level: 'viewer' | 'operator' | 'super_admin' | null;
  status: 'active' | 'suspended';
  created_at: string;
  box_count: number;
  subscription: {
    type: 'free' | 'vip';
    is_active: boolean;
    end_date: string | null;
  } | null;
}

export interface AdminUserProfile {
  id: string;
  email: string;
  role: 'user' | 'vip' | 'admin';
  admin_level: 'viewer' | 'operator' | 'super_admin' | null;
  status: 'active' | 'suspended';
  created_at: string;
  subscription: {
    id: string;
    type: 'free' | 'vip';
    start_date: string;
    end_date: string | null;
    is_active: boolean;
    auto_renew: boolean;
  } | null;
  boxes: {
    id: string;
    uid_hardware: string | null;
    name: string;
    status: string;
    firmware_version: string | null;
    last_sync: string | null;
    latitude: number | null;
    longitude: number | null;
  }[];
  totals: { kwh_30d: number; kwh_year: number; box_count: number; commands_30d: number };
  last_sync: string | null;
}

export interface AdminIdentity {
  id: string;
  email: string;
  role: 'user' | 'vip' | 'admin';
  level: 'viewer' | 'operator' | 'super_admin';
}

export interface FusedAuditLog {
  id: string;
  source: 'admin' | 'agent';
  at: string;
  action: string;
  target_type: string | null;
  target_id: string | null;
  actor_id: string | null;
  actor_email: string | null;
  status: string | null;
  details: Record<string, unknown>;
}

export function getAdminIdentity() {
  return adminFetch<AdminIdentity>('/me');
}

export function getKpiSummary(period: 'day' | 'week' | 'month' | 'quarter' = 'month') {
  return adminFetch<KpiSummary>('/kpi/summary', { query: { period } });
}

export function listUsers(query?: {
  page?: number;
  page_size?: number;
  status?: 'active' | 'suspended';
  role?: 'admin' | 'user' | 'vip';
  sub?: 'free' | 'vip';
  q?: string;
  sort?: string;
}): Promise<Paginated<AdminUserListItem>> {
  return adminList('/users', { query });
}

export function getUser(id: string): Promise<AdminUserProfile> {
  return adminFetch(`/users/${encodeURIComponent(id)}`);
}

export function updateUserStatus(id: string, status: 'active' | 'suspended') {
  return adminFetch(`/users/${encodeURIComponent(id)}/status`, {
    method: 'PATCH',
    body: { status },
  });
}

export function listSubscriptions(query?: {
  page?: number;
  page_size?: number;
  type?: 'free' | 'vip';
  is_active?: boolean;
  expiring_within_days?: number;
}): Promise<Paginated<AdminSubscription>> {
  return adminList('/subscriptions', { query });
}

export function updateSubscription(id: string, patch: {
  type?: 'free' | 'vip';
  end_date?: string | null;
  is_active?: boolean;
  auto_renew?: boolean;
}) {
  return adminFetch<AdminSubscription>(`/subscriptions/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: patch,
  });
}

export function listAdminActions(query?: { page?: number; page_size?: number; from?: string; to?: string }) {
  return adminList<AdminActionLog>('/admin/actions', { query });
}

export function listFusedAudit(query?: { page?: number; page_size?: number; source?: 'all' | 'admin' | 'agent' }): Promise<Paginated<FusedAuditLog>> {
  return adminList<FusedAuditLog>('/admin/audit-logs', { query });
}

export function listAdminNotes(query?: {
  page?: number;
  page_size?: number;
  target_type?: NoteTargetType;
  target_id?: string;
}) {
  return adminList<AdminNote>('/admin/notes', { query });
}

export function createAdminNote(input: {
  target_type: NoteTargetType;
  target_id: string;
  body: string;
}) {
  return adminFetch<AdminNote>('/admin/notes', { method: 'POST', body: input });
}

export function getCoverage(query?: {
  bbox?: string;
  precision?: number;
  zone_id?: string;
}): Promise<CoverageResponse> {
  return adminFetch('/geo/coverage', { query });
}

export function getHeatmap(query?: {
  metric?: 'boxes' | 'users' | 'kwh' | 'new_installations';
  from?: string;
  to?: string;
}) {
  return adminFetch<{
    metric: string;
    from: string;
    to: string;
    points: { lat: number; lng: number; weight: number }[];
  }>('/geo/heatmap', { query });
}

export function listCoverageZones(): Promise<CoverageZoneRecord[]> {
  return adminFetch('/geo/zones');
}

export function listBoxes(query?: {
  page?: number;
  page_size?: number;
  status?: 'active' | 'inactive' | 'blocked';
  user_id?: string;
  q?: string;
  firmware?: string;
}) {
  return adminList<import('../types/admin').AdminBox>('/boxes', { query });
}

export function getAgentAnalytics(query?: { from?: string; to?: string }): Promise<AgentAnalyticsResponse> {
  return adminFetch('/agent/analytics', { query });
}

export function getIotHealth(): Promise<IotHealth> {
  return adminFetch('/iot/health');
}

export function getBoxDetail(id: string) {
  return adminFetch<{
    id: string;
    uid_hardware: string | null;
    name: string;
    user_id: string | null;
    user_email: string | null;
    status: string;
    firmware_version: string | null;
    last_sync: string | null;
    appliances: { id: string; relay_index: number; name: string; is_on: boolean | null }[];
    recent_commands: IotCommand[];
    recent_syncs: { id: string; status: string; timestamp: string; error_message: string | null }[];
  }>(`/boxes/${encodeURIComponent(id)}`);
}

export function listIotCommands(query?: {
  page?: number;
  page_size?: number;
  status?: DeviceCommandStatus;
  box_id?: string;
  user_id?: string;
  from?: string;
  to?: string;
}): Promise<Paginated<IotCommand>> {
  return adminList('/iot/commands', { query });
}

export function retryIotCommand(id: string): Promise<IotCommand> {
  return adminFetch(`/iot/commands/${encodeURIComponent(id)}/retry`, {
    method: 'POST',
    body: {},
  });
}
