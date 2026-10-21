import type { ReactNode } from "react";
import { useRecoilValue } from "recoil";
import { authState } from "../state/authAtom";
import { Navigate } from "react-router-dom";

export default function RequireAuth({ children }: { children: ReactNode }) {
  const auth = useRecoilValue(authState);

  if (!auth.isLoggedIn) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>; // ReactNode는 Fragment로 감싸는 것이 일반적
}
