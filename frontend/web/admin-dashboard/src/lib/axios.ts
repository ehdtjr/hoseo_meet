import axios from "axios";
import type { InternalAxiosRequestConfig } from "axios";
import config from "../config";
import { refreshToken as refreshTokenAPI } from "../services/authService";
import {
  accessToken,
  authSessionVersion,
  clearAuthTokens,
  refreshToken,
  rotateAuthTokens,
} from "./authStore";

type AuthRequestConfig = InternalAxiosRequestConfig & {
  _retry?: boolean;
  _authSessionVersion?: number;
};

const api = axios.create({
  baseURL: config.apiBaseUrl,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

let pendingRefresh: {
  sessionVersion: number;
  promise: Promise<string>;
} | null = null;

function refreshAccessToken(token: string, sessionVersion: number) {
  if (pendingRefresh?.sessionVersion === sessionVersion) {
    return pendingRefresh.promise;
  }

  const attempt = {
    sessionVersion,
    promise: refreshTokenAPI(token)
      .then(({ access_token, refresh_token }) => {
        if (authSessionVersion !== sessionVersion) {
          throw new axios.CanceledError("Authentication session changed");
        }
        rotateAuthTokens(access_token, refresh_token);
        return access_token;
      })
      .catch((error: unknown) => {
        const status = axios.isAxiosError(error) ? error.response?.status : undefined;
        if (
          authSessionVersion === sessionVersion &&
          (status === 400 || status === 401)
        ) {
          clearAuthTokens();
          window.location.href = "/login";
        }
        // Transport/server failures preserve the session for a later attempt.
        throw error;
      })
      .finally(() => {
        if (pendingRefresh === attempt) pendingRefresh = null;
      }),
  };
  pendingRefresh = attempt;
  return attempt.promise;
}

api.interceptors.request.use((request: AuthRequestConfig) => {
  if (
    request._authSessionVersion !== undefined &&
    request._authSessionVersion !== authSessionVersion
  ) {
    throw new axios.CanceledError("Authentication session changed");
  }
  request._authSessionVersion = authSessionVersion;
  if (accessToken) {
    request.headers.Authorization = `Bearer ${accessToken}`;
  } else {
    request.headers.delete("Authorization");
  }
  return request;
});

api.interceptors.response.use(
  (response) => response,
  async (error: unknown) => {
    if (!axios.isAxiosError(error)) return Promise.reject(error);
    const originalRequest: AuthRequestConfig | undefined = error.config;

    if (
      !originalRequest ||
      error.response?.status !== 401 ||
      originalRequest._retry ||
      !refreshToken ||
      originalRequest._authSessionVersion !== authSessionVersion
    ) {
      return Promise.reject(error);
    }

    originalRequest._retry = true;
    // A delayed 401 may arrive after another request has already rotated tokens.
    if (originalRequest.headers.Authorization === `Bearer ${accessToken}`) {
      await refreshAccessToken(refreshToken, authSessionVersion);
    }
    if (originalRequest._authSessionVersion !== authSessionVersion) {
      return Promise.reject(new axios.CanceledError("Authentication session changed"));
    }
    return api(originalRequest);
  }
);

export default api;
