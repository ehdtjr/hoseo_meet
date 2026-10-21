import {
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Badge,
  Button,
  Input,
  Select,
  HStack,
} from "@chakra-ui/react";
import { format } from "date-fns";
import { useState } from "react";
import type { User } from "../../types/user";

interface UserListProps {
  users: User[];
  onUpdate?: (user: User) => void;
}

export default function UserList({ users, onUpdate }: UserListProps) {
  const [editUserId, setEditUserId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState<User | null>(null);

  const handleEditClick = (user: User) => {
    setEditUserId(user.id);
    setEditForm({ ...user });
  };

  const handleCancel = () => {
    setEditUserId(null);
    setEditForm(null);
  };

  const handleSave = () => {
    if (onUpdate && editForm) {
      onUpdate(editForm);
    }
    setEditUserId(null);
    setEditForm(null);
  };

  const handleChange = <K extends keyof User>(field: K, value: User[K]) => {
    if (editForm) {
      setEditForm({ ...editForm, [field]: value });
    }
  };

  return (
    <Table variant="simple" size="md">
      <Thead bg="gray.100" position="sticky" top={0} zIndex={1}>
        <Tr>
          <Th>ID</Th>
          <Th>이름</Th>
          <Th>이메일</Th>
          <Th>인증됨</Th>
          <Th>상태</Th>
          <Th>슈퍼유저</Th>
          <Th>가입일</Th>
          <Th>작업</Th>
        </Tr>
      </Thead>
      <Tbody>
        {users.map((user) => {
          const isEditing = user.id === editUserId;

          return (
            <Tr key={user.id}>
              <Td>{user.id}</Td>
              <Td>
                {isEditing ? (
                  <Input
                    size="sm"
                    value={editForm?.name ?? ""}
                    onChange={(e) => handleChange("name", e.target.value)}
                  />
                ) : (
                  user.name
                )}
              </Td>
              <Td>
                {isEditing ? (
                  <Input
                    size="sm"
                    value={editForm?.email ?? ""}
                    onChange={(e) => handleChange("email", e.target.value)}
                  />
                ) : (
                  user.email
                )}
              </Td>
              <Td>
                {isEditing ? (
                  <Select
                    size="sm"
                    value={String(editForm?.is_verified)}
                    onChange={(e) =>
                      handleChange("is_verified", e.target.value === "true")
                    }
                  >
                    <option value="true">인증됨</option>
                    <option value="false">미인증</option>
                  </Select>
                ) : (
                  <Badge colorScheme={user.is_verified ? "green" : "red"}>
                    {user.is_verified ? "인증됨" : "미인증"}
                  </Badge>
                )}
              </Td>
              <Td>
                {isEditing ? (
                  <Select
                    size="sm"
                    value={String(editForm?.is_active)}
                    onChange={(e) =>
                      handleChange("is_active", e.target.value === "true")
                    }
                  >
                    <option value="true">활성</option>
                    <option value="false">비활성</option>
                  </Select>
                ) : (
                  <Badge colorScheme={user.is_active ? "blue" : "gray"}>
                    {user.is_active ? "활성" : "비활성"}
                  </Badge>
                )}
              </Td>
              <Td>
                {isEditing ? (
                  <Select
                    size="sm"
                    value={String(editForm?.is_superuser)}
                    onChange={(e) =>
                      handleChange("is_superuser", e.target.value === "true")
                    }
                  >
                    <option value="true">예</option>
                    <option value="false">아니오</option>
                  </Select>
                ) : (
                  <Badge colorScheme={user.is_superuser ? "purple" : "gray"}>
                    {user.is_superuser ? "슈퍼유저" : "일반"}
                  </Badge>
                )}
              </Td>
              <Td>{format(new Date(user.created_at), "yyyy-MM-dd HH:mm")}</Td>
              <Td>
                {isEditing ? (
                  <HStack spacing={2}>
                    <Button size="sm" colorScheme="teal" onClick={handleSave}>
                      저장
                    </Button>
                    <Button size="sm" variant="outline" onClick={handleCancel}>
                      취소
                    </Button>
                  </HStack>
                ) : (
                  <Button
                    size="sm"
                    colorScheme="teal"
                    onClick={() => handleEditClick(user)}
                  >
                    수정
                  </Button>
                )}
              </Td>
            </Tr>
          );
        })}
      </Tbody>
    </Table>
  );
}
