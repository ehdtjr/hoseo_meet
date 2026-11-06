import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import axios, { AxiosError } from "axios";
import type { InternalAxiosRequestConfig } from "axios";
import api from "../src/lib/axios";
import authClient from "../src/lib/authClient";
import * as store from "../src/lib/authStore";
import { login, refreshToken } from "../src/services/authService";
import { deferred, httpError, response, rotatedTokens } from "./transport";

const navigate = vi.fn();
const apiAdapter = vi.fn();
const authAdapter = vi.fn();
const originalApiAdapter = api.defaults.adapter;
const originalAuthAdapter = authClient.defaults.adapter;

beforeEach(() => {
  vi.resetAllMocks();
  vi.stubGlobal("window", { location: { set href(path: string) { navigate(path); } } });
  store.setAuthTokens("old-access", "old-refresh", "admin");
  api.defaults.adapter = apiAdapter;
  authClient.defaults.adapter = authAdapter;
  apiAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
    if (config.headers.Authorization === "Bearer old-access") throw httpError(config);
    return response(config, { ok: true });
  });
  authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => response(config, rotatedTokens));
});

afterEach(() => {
  store.clearAuthTokens();
  api.defaults.adapter = originalApiAdapter;
  authClient.defaults.adapter = originalAuthAdapter;
  vi.unstubAllGlobals();
});

describe("authenticated request recovery", () => {
  it("rotates tokens and replays once with the new bearer token", async () => {
    await expect(api.get("/users")).resolves.toMatchObject({ data: { ok: true } });
    expect(apiAdapter).toHaveBeenCalledTimes(2);
    expect(authAdapter).toHaveBeenCalledTimes(1);
    const refresh = authAdapter.mock.calls[0][0];
    expect(refresh.url).toBe("/auth/refresh");
    expect(JSON.parse(refresh.data)).toEqual({ refresh_token: "old-refresh" });
    expect(refresh.headers.Authorization).toBeUndefined();
    expect(store.accessToken).toBe("new-access");
    expect(store.refreshToken).toBe("new-refresh");
    expect(store.username).toBe("admin");
    expect(apiAdapter.mock.calls[1][0].headers.Authorization).toBe("Bearer new-access");
    expect(navigate).not.toHaveBeenCalled();
  });

  it("shares one refresh between concurrent 401s and retries every request once", async () => {
    const gate = deferred<void>();
    authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
      await gate.promise;
      return response(config, rotatedTokens);
    });
    const requests = ["/users", "/reports", "/stats"].map((url) => api.get(url));
    await vi.waitFor(() => expect(authAdapter).toHaveBeenCalledTimes(1));
    expect(apiAdapter).toHaveBeenCalledTimes(3);
    gate.resolve();
    expect((await Promise.all(requests)).every((result) => result.status === 200)).toBe(true);
    expect(authAdapter).toHaveBeenCalledTimes(1);
    expect(apiAdapter).toHaveBeenCalledTimes(6);
    for (const url of ["/users", "/reports", "/stats"]) {
      expect(apiAdapter.mock.calls.filter(([config]) => config.url === url)).toHaveLength(2);
    }
  });

  it("reuses rotated tokens for an old 401 arriving after refresh completes", async () => {
    const slow = deferred<void>();
    apiAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
      if (config.headers.Authorization === "Bearer old-access") {
        if (config.url === "/slow") await slow.promise;
        throw httpError(config);
      }
      return response(config);
    });
    const delayed = api.get("/slow");
    await api.get("/fast");
    slow.resolve();
    await delayed;
    expect(authAdapter).toHaveBeenCalledTimes(1);
    expect(apiAdapter).toHaveBeenCalledTimes(4);
  });

  it("stops if the replay also returns 401", async () => {
    apiAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => { throw httpError(config); });
    await expect(api.get("/users")).rejects.toMatchObject({ response: { status: 401 } });
    expect(apiAdapter).toHaveBeenCalledTimes(2);
    expect(authAdapter).toHaveBeenCalledTimes(1);
  });

  it.each([400, 401, 500, 503, "network"])("settles concurrent refresh failures (%s) without recursion", async (failure) => {
    const gate = deferred<void>();
    authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
      await gate.promise;
      throw failure === "network" ? new AxiosError("offline", "ERR_NETWORK", config) : httpError(config, failure);
    });
    const results = Promise.allSettled([api.get("/users"), api.get("/reports")]);
    await vi.waitFor(() => expect(authAdapter).toHaveBeenCalledTimes(1));
    gate.resolve();
    expect((await results).map((result) => result.status)).toEqual(["rejected", "rejected"]);
    expect(authAdapter).toHaveBeenCalledTimes(1);
    expect(apiAdapter).toHaveBeenCalledTimes(2);
    if (failure === 400 || failure === 401) {
      expect(store.accessToken).toBeNull();
      expect(store.refreshToken).toBeNull();
      expect(store.username).toBeNull();
      expect(navigate).toHaveBeenCalledExactlyOnceWith("/login");
    } else {
      expect(store.accessToken).toBe("old-access");
      expect(store.refreshToken).toBe("old-refresh");
      expect(navigate).not.toHaveBeenCalled();
      // The failed shared promise must be released so a later action can recover.
      authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => response(config, rotatedTokens));
      await expect(api.get("/retry-later")).resolves.toMatchObject({ status: 200 });
      expect(authAdapter).toHaveBeenCalledTimes(2);
    }
  });

  it("does not refresh without a refresh token", async () => {
    store.clearAuthTokens();
    apiAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => { throw httpError(config); });
    await expect(api.get("/users")).rejects.toMatchObject({ response: { status: 401 } });
    expect(authAdapter).not.toHaveBeenCalled();
    expect(navigate).not.toHaveBeenCalled();
  });

  it("passes through non-401 and config-less errors", async () => {
    apiAdapter.mockImplementationOnce(async (config: InternalAxiosRequestConfig) => { throw httpError(config, 403); });
    await expect(api.get("/users")).rejects.toMatchObject({ response: { status: 403 } });
    const error = new AxiosError("missing config");
    apiAdapter.mockRejectedValueOnce(error);
    await expect(api.get("/users")).rejects.toBe(error);
    expect(authAdapter).not.toHaveBeenCalled();
  });

  it.each(["logout", "login"])("ignores refresh success after %s", async (change) => {
    const gate = deferred<void>();
    authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
      await gate.promise;
      return response(config, rotatedTokens);
    });
    const result = api.get("/users").catch((error: unknown) => error);
    await vi.waitFor(() => expect(authAdapter).toHaveBeenCalledTimes(1));
    if (change === "logout") store.clearAuthTokens();
    else store.setAuthTokens("other-access", "other-refresh", "other-admin");
    gate.resolve();
    expect(axios.isCancel(await result)).toBe(true);
    expect(store.accessToken).toBe(change === "logout" ? null : "other-access");
    expect(store.username).toBe(change === "logout" ? null : "other-admin");
    expect(apiAdapter).toHaveBeenCalledTimes(1);
    expect(navigate).not.toHaveBeenCalled();
  });

  it("does not log out a new login when an old refresh is rejected", async () => {
    const gate = deferred<void>();
    authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
      await gate.promise;
      throw httpError(config);
    });
    const result = api.get("/users").catch((error: unknown) => error);
    await vi.waitFor(() => expect(authAdapter).toHaveBeenCalledTimes(1));
    store.setAuthTokens("other-access", "other-refresh", "other-admin");
    gate.resolve();
    await result;
    expect(store.accessToken).toBe("other-access");
    expect(navigate).not.toHaveBeenCalled();
  });

  it("does not replay an old session's delayed 401 under a new login", async () => {
    const gate = deferred<void>();
    apiAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
      await gate.promise;
      throw httpError(config);
    });
    const result = api.get("/users").catch((error: unknown) => error);
    await vi.waitFor(() => expect(apiAdapter).toHaveBeenCalledTimes(1));
    store.setAuthTokens("other-access", "other-refresh", "other-admin");
    gate.resolve();
    await result;
    expect(authAdapter).not.toHaveBeenCalled();
    expect(apiAdapter).toHaveBeenCalledTimes(1);
  });
});

describe("authentication transport", () => {
  it("does not refresh or redirect when login is rejected", async () => {
    authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => { throw httpError(config); });
    await expect(login("admin", "wrong-password")).rejects.toMatchObject({ response: { status: 401 } });
    expect(authAdapter).toHaveBeenCalledTimes(1);
    expect(authAdapter.mock.calls[0][0].headers.Authorization).toBeUndefined();
    expect(apiAdapter).not.toHaveBeenCalled();
    expect(store.accessToken).toBe("old-access");
    expect(navigate).not.toHaveBeenCalled();
  });

  it("keeps direct refresh errors outside the authenticated retry loop", async () => {
    authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => { throw httpError(config); });
    await expect(refreshToken("old-refresh")).rejects.toMatchObject({ response: { status: 401 } });
    expect(authAdapter).toHaveBeenCalledTimes(1);
    expect(apiAdapter).not.toHaveBeenCalled();
    expect(navigate).not.toHaveBeenCalled();
  });
});
