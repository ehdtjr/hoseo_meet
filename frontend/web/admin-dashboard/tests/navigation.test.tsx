// @vitest-environment jsdom
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { act } from "react-dom/test-utils";
import { createRoot } from "react-dom/client";
import type { Root } from "react-dom/client";
import { RecoilRoot } from "recoil";
import { ChakraProvider } from "@chakra-ui/react";
import type { InternalAxiosRequestConfig } from "axios";
import App from "../src/App";
import api from "../src/lib/axios";
import authClient from "../src/lib/authClient";
import * as store from "../src/lib/authStore";
import { httpError, response, rotatedTokens } from "./transport";

let container: HTMLDivElement;
let root: Root;
const apiAdapter = vi.fn();
const authAdapter = vi.fn();
const originalApiAdapter = api.defaults.adapter;
const originalAuthAdapter = authClient.defaults.adapter;

beforeEach(() => {
  vi.resetAllMocks();
  vi.stubGlobal("IS_REACT_ACT_ENVIRONMENT", true);
  vi.stubGlobal("matchMedia", () => ({
    matches: false, addListener() {}, removeListener() {},
    addEventListener() {}, removeEventListener() {},
  }));
  window.history.replaceState(null, "", "/dashboard");
  store.clearAuthTokens();
  api.defaults.adapter = apiAdapter;
  authClient.defaults.adapter = authAdapter;
  apiAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => {
    if (config.headers.Authorization === "Bearer old-access") throw httpError(config);
    return response(config, []);
  });
  authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => response(config,
    config.url === "/auth/login"
      ? { access_token: "old-access", refresh_token: "old-refresh", is_admin: true, message: "성공" }
      : rotatedTokens
  ));
  container = document.createElement("div");
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(async () => {
  await act(async () => root.unmount());
  container.remove();
  store.clearAuthTokens();
  api.defaults.adapter = originalApiAdapter;
  authClient.defaults.adapter = originalAuthAdapter;
  vi.unstubAllGlobals();
});

async function renderApp() {
  await act(async () => root.render(<RecoilRoot><ChakraProvider><App /></ChakraProvider></RecoilRoot>));
}

async function submitLogin() {
  await renderApp();
  expect(window.location.pathname).toBe("/login");
  await act(async () => {
    for (const [selector, value] of [["input[placeholder='admin']", "admin"], ["input[type='password']", "password"]]) {
      const input = container.querySelector<HTMLInputElement>(selector)!;
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")!.set!.call(input, value);
      input.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });
  await act(async () => container.querySelector<HTMLButtonElement>("button")!.click());
}

it("logs in, refreshes normally, navigates between protected screens, and guards a cleared session", async () => {
  await submitLogin();
  expect(window.location.pathname).toBe("/dashboard");
  expect(container.textContent).toContain("총 유저 수");
  await act(async () => { await api.get("/admin/user/list"); });
  expect(store.accessToken).toBe("new-access");
  expect(window.location.pathname).toBe("/dashboard");
  await act(async () => container.querySelector<HTMLAnchorElement>("a[href='/settings']")!.click());
  expect(window.location.pathname).toBe("/settings");
  expect(container.textContent).toContain("설정 페이지");
  await act(async () => container.querySelector<HTMLAnchorElement>("a[href='/dashboard']")!.click());
  expect(window.location.pathname).toBe("/dashboard");

  // A hard redirect reloads Recoil's in-memory auth state; emulate that reload.
  store.clearAuthTokens();
  await act(async () => root.unmount());
  root = createRoot(container);
  await renderApp();
  expect(window.location.pathname).toBe("/login");
  expect(container.textContent).toContain("관리자 로그인");
  expect(authAdapter).toHaveBeenCalledTimes(2);
});

it("keeps a failed login on the login screen without starting refresh", async () => {
  authAdapter.mockImplementation(async (config: InternalAxiosRequestConfig) => { throw httpError(config); });
  await submitLogin();
  expect(window.location.pathname).toBe("/login");
  expect(store.accessToken).toBeNull();
  expect(authAdapter).toHaveBeenCalledTimes(1);
  expect(authAdapter.mock.calls[0][0].url).toBe("/auth/login");
});

it("keeps the protected screen during a server outage and recovers on the next action", async () => {
  await submitLogin();
  authAdapter.mockImplementationOnce(async (config: InternalAxiosRequestConfig) => { throw httpError(config, 503); });
  await act(async () => { await expect(api.get("/admin/user/list")).rejects.toMatchObject({ response: { status: 503 } }); });
  expect(window.location.pathname).toBe("/dashboard");
  expect(container.textContent).toContain("총 유저 수");
  expect(store.accessToken).toBe("old-access");
  await act(async () => { await api.get("/admin/user/list"); });
  expect(store.accessToken).toBe("new-access");
  expect(window.location.pathname).toBe("/dashboard");
});
