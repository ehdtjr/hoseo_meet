import { atom } from "recoil";
import type { AuthState } from "../types/auth";

export const authState = atom<AuthState>({
  key: "authState",
  default: {
    isLoggedIn: false,
    username: "",
    accessToken: "",
    refreshToken: "",
  },
});
