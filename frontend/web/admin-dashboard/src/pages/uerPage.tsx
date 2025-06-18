import { Box, Input, Button, Flex, Spinner } from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import UserList from "../components/users/UserList";
import { useUsers } from "../hooks/useUsers";

export default function UserPage() {
  const {
    users,
    loading,
    keyword,
    update,
    setKeyword,
    handleSearch,
    loadMore,
    hasMore,
  } = useUsers();

  const loaderRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && hasMore) {
          loadMore();
        }
      },
      { threshold: 1.0 }
    );

    const current = loaderRef.current;
    if (current) observer.observe(current);

    return () => {
      if (current) observer.unobserve(current);
    };
  }, [hasMore, loadMore]);

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

      <UserList users={users} onUpdate={update} />

      {loading && (
        <Flex justify="center" align="center" mt={4} minH="100px">
          <Spinner size="lg" />
        </Flex>
      )}

      <div ref={loaderRef} style={{ height: "1px" }} />
    </Box>
  );
}
