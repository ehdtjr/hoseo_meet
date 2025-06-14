import {
  Box,
  SimpleGrid,
  Stat,
  StatLabel,
  StatNumber,
  Text,
  useColorModeValue,
} from "@chakra-ui/react";

export default function Dashboard() {
  return (
    <Box p={8}>
      <SimpleGrid columns={{ base: 1, md: 3 }} spacing={6} mb={8}>
        <StatCard label="총 유저 수" value="1,240명" />
        <StatCard label="신고 접수" value="32건" />
        <StatCard label="오늘 방문자" value="312명" />
      </SimpleGrid>

      <Box bg="gray.50" p={6} rounded="xl" shadow="md">
        <Text fontSize="lg" fontWeight="semibold" mb={2}>
          📅 최근 알림
        </Text>
        <Text color="gray.600">
          - test0@vision.hoseo.edu 님이 회원가입했습니다.
        </Text>
        <Text color="gray.600">- 사용자 3명이 신고 접수되었습니다.</Text>
      </Box>
    </Box>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  const bg = useColorModeValue("white", "gray.800");
  return (
    <Box p={6} bg={bg} rounded="lg" shadow="sm">
      <Stat>
        <StatLabel>{label}</StatLabel>
        <StatNumber>{value}</StatNumber>
      </Stat>
    </Box>
  );
}
