import {
  Box,
  VStack,
  Link,
  Text,
  Divider,
  Icon,
  useColorModeValue,
} from "@chakra-ui/react";
import { Link as RouterLink, useLocation } from "react-router-dom";
import { FiHome, FiUsers, FiSettings } from "react-icons/fi";

const navItems = [
  { label: "대시보드", to: "/dashboard", icon: FiHome },
  { label: "사용자 관리", to: "/users", icon: FiUsers },
  { label: "설정", to: "/settings", icon: FiSettings },
];

export default function Sidebar() {
  const location = useLocation();
  const activeColor = useColorModeValue("teal.500", "teal.300");

  return (
    <Box w="240px" bg="gray.800" color="white" p={6} minH="100vh">
      <Text fontSize="2xl" fontWeight="bold" mb={6}>
        🛠 관리자
      </Text>

      <Divider borderColor="gray.600" mb={6} />

      <VStack align="start" spacing={4}>
        {navItems.map((item) => (
          <Link
            key={item.to}
            as={RouterLink}
            to={item.to}
            display="flex"
            alignItems="center"
            gap={3}
            fontWeight={location.pathname === item.to ? "bold" : "normal"}
            color={location.pathname === item.to ? activeColor : "gray.300"}
            _hover={{ textDecoration: "none", color: activeColor }}
            w="full"
            py={2}
            px={3}
            rounded="md"
            bg={location.pathname === item.to ? "gray.700" : "transparent"}
          >
            <Icon as={item.icon} boxSize={5} />
            {item.label}
          </Link>
        ))}
      </VStack>
    </Box>
  );
}
