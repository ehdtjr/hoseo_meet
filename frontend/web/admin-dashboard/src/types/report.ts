export interface Report {
  id: number;
  reporter_id: number;
  reported_user_id: number;
  reason: string;
  is_resolved: boolean;
  created_at: string;
}
