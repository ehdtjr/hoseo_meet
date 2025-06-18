import { BrowserRouter, Routes, Route } from "react-router-dom";
import RequireAuth from "./components/RequireAuth";
import Login from "./pages/login";
import AdminLayout from "./layouts/AdminLayout";
import UserPage from "./pages/uerPage";
import Dashboard from "./pages/dashboard";
import ReportPage from "./pages/reports";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />

        {/* ✅ 보호된 관리자 라우트 묶음 */}
        <Route
          path="/"
          element={
            <RequireAuth>
              <AdminLayout />
            </RequireAuth>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="users" element={<UserPage />} />
          <Route path="reports" element={<ReportPage />} />
          <Route path="settings" element={<div>설정 페이지</div>} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
