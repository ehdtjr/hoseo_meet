// lib/api.ts
import axios from "axios";
import config from "../config";
import { refreshToken as refreshTokenAPI } from "../services/authService";
import {
  accessToken,
  clearAuthTokens,
  refreshToken,
  setAuthTokens,
  username,
} from "./authStore";
const api = axios.create({
  baseURL: config.apiBaseUrl,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

api.interceptors.request.use((config) => {
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  async (error) => {
    const originalRequest = error.config;

    if (
      error.response?.status === 401 &&
      !originalRequest._retry &&
      refreshToken
    ) {
      originalRequest._retry = true;

      try {
        const { access_token, refresh_token } = await refreshTokenAPI(
          refreshToken
        );
        setAuthTokens(access_token, refresh_token, username || "");

        originalRequest.headers.Authorization = `Bearer ${access_token}`;
        return api(originalRequest);
      } catch (err) {
        console.warn("❌ 토큰 재발급 실패 → 로그아웃 처리");
        clearAuthTokens();
        window.location.href = "/login";
        return Promise.reject(err);
      }
    }

    return Promise.reject(error);
  }
);

export default api;
