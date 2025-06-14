import api from "../lib/axios";
import type { LoginResponse } from "../types/auth";

export async function login(
  username: string,
  password: string
): Promise<LoginResponse> {
  const formData = new URLSearchParams();
  formData.append("username", username);
  formData.append("password", password);

  const response = await api.post("/auth/login", formData, {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
  });

  return response.data;
}

export async function refreshToken(
  refreshToken: string
): Promise<LoginResponse> {
  const response = await api.post("/auth/refresh", {
    refresh_token: refreshToken,
  });

  return response.data;
}
