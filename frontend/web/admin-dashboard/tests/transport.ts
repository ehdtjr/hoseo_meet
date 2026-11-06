import { AxiosError, AxiosHeaders } from "axios";
import type { AxiosResponse, InternalAxiosRequestConfig } from "axios";

export function response(config: InternalAxiosRequestConfig, data: unknown = {}) {
  return { config, data, status: 200, statusText: "OK", headers: new AxiosHeaders() };
}

export function httpError(config: InternalAxiosRequestConfig, status = 401) {
  const result: AxiosResponse = { ...response(config), status };
  return new AxiosError("Request failed", "ERR_BAD_RESPONSE", config, null, result);
}

export function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

export const rotatedTokens = { access_token: "new-access", refresh_token: "new-refresh" };
