export let accessToken: string | null = null;
export let refreshToken: string | null = null;
export let username: string | null = null;
// Changes on login/logout, but stays stable while this session rotates tokens.
export let authSessionVersion = 0;

export function setAuthTokens(token: string, refresh: string, user: string) {
  authSessionVersion += 1;
  accessToken = token;
  refreshToken = refresh;
  username = user;
}

export function rotateAuthTokens(token: string, refresh: string) {
  accessToken = token;
  refreshToken = refresh;
}

export function clearAuthTokens() {
  authSessionVersion += 1;
  accessToken = null;
  refreshToken = null;
  username = null;
}
