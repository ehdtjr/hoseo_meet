export interface User {
  id: number;
  email: string;
  is_active: boolean;
  is_superuser: boolean;
  is_verified: boolean;
  name: string;
  gender: "male" | "female" | "unknown";
  profile: string | null;
  created_at: string; // ISO 형식 문자열
}
