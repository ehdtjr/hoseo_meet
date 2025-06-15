import { Table, Thead, Tbody, Tr, Th, Td, Badge } from "@chakra-ui/react";
import { format } from "date-fns";
import type { User } from "../../types/user";

interface UserListProps {
  users: User[];
}

export default function UserList({ users }: UserListProps) {
  return (
    <Table variant="simple" size="md">
      <Thead bg="gray.100" position="sticky" top={0} zIndex={1}>
        <Tr>
          <Th>ID</Th>
          <Th>이름</Th>
          <Th>이메일</Th>
          <Th>인증됨</Th>
          <Th>상태</Th>
          <Th>가입일</Th>
        </Tr>
      </Thead>
      <Tbody>
        {users.map((user) => (
          <Tr key={user.id}>
            <Td>{user.id}</Td>
            <Td>{user.name}</Td>
            <Td>{user.email}</Td>
            <Td>
              <Badge colorScheme={user.is_verified ? "green" : "red"}>
                {user.is_verified ? "인증됨" : "미인증"}
              </Badge>
            </Td>
            <Td>
              <Badge colorScheme={user.is_active ? "blue" : "gray"}>
                {user.is_active ? "활성" : "비활성"}
              </Badge>
            </Td>
            <Td>{format(new Date(user.created_at), "yyyy-MM-dd HH:mm")}</Td>
          </Tr>
        ))}
      </Tbody>
    </Table>
  );
}
