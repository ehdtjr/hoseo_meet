import { Box, Flex } from "@chakra-ui/react";
import Sidebar from "../components/Sidebar";
import { Outlet } from "react-router-dom";

export default function AdminLayout() {
  return (
    <Flex minH="100vh">
      <Sidebar />
      <Box flex="1" p={6} bg="gray.50">
        <Outlet /> {/* 여기서 Dashboard, Users 등 렌더링 */}
      </Box>
    </Flex>
  );
}
