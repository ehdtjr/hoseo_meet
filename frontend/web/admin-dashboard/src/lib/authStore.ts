export let accessToken: string | null = null;
export let refreshToken: string | null = null;
export let username: string | null = null;

export function setAuthTokens(token: string, refresh: string, user: string) {
  accessToken = token;
  refreshToken = refresh;
  username = user;
}

export function clearAuthTokens() {
  accessToken = null;
  refreshToken = null;
  username = null;
}
