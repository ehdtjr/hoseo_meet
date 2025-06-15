import { Box, Input, Button, useToast, Flex, Spinner } from "@chakra-ui/react";
import { useEffect, useRef, useState } from "react";
import { fetchUsers } from "../services/userService";
import type { User } from "../types/user";
import UserList from "../components/users/UserList";

export default function UserPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [keyword, setKeyword] = useState("");
  const [skip, setSkip] = useState(0);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const toast = useToast();
  const LIMIT = 30;
  const loaderRef = useRef<HTMLDivElement | null>(null);

  const loadUsers = async (initial = false) => {
    if (loading || (!initial && !hasMore)) return;

    setLoading(true);
    try {
      const data = await fetchUsers({
        user_name_key: keyword,
        skip: initial ? 0 : skip,
        limit: LIMIT,
      });

      if (initial) {
        setUsers(data);
        setSkip(LIMIT);
        setHasMore(data.length === LIMIT);
      } else {
        setUsers((prev) => [...prev, ...data]);
        setSkip((prev) => prev + LIMIT);
        setHasMore(data.length === LIMIT);
      }
    } catch {
      toast({
        title: "불러오기 실패",
        description: "사용자 목록을 가져올 수 없습니다.",
        status: "error",
        duration: 2000,
        isClosable: true,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    setSkip(0);
    setHasMore(true);
    loadUsers(true);
  };

  // 무한 스크롤 감지
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) loadUsers();
      },
      { threshold: 1.0 }
    );
    if (loaderRef.current) observer.observe(loaderRef.current);
    return () => {
      if (loaderRef.current) observer.unobserve(loaderRef.current);
    };
  }, [loaderRef.current]);

  useEffect(() => {
    loadUsers(true);
  }, []);

  return (
    <Box p={6} maxH="100vh" overflowY="auto">
      <Flex mb={4} gap={2}>
        <Input
          placeholder="이름으로 검색"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
        />
        <Button onClick={handleSearch} colorScheme="teal">
          검색
        </Button>
      </Flex>

      <UserList users={users} />

      {loading && <Spinner mt={4} />}
      <div ref={loaderRef} style={{ height: "1px" }} />
    </Box>
  );
}
