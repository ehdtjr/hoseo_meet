export interface AuthState {
  isLoggedIn: boolean;
  username: string;
  accessToken: string;
  refreshToken: string;
}

export interface User {
  username: string;
}

export interface LoginResponse {
  message: string;
  access_token: string;
  refresh_token: string;
}
