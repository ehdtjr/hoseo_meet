import { useState, useEffect, useCallback, useRef } from "react";
import { fetchUsers, updateUser } from "../services/userService";
import { useToast } from "@chakra-ui/react";
import type { User } from "../types/user";

export function useUsers() {
  const [users, setUsers] = useState<User[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const LIMIT = 30;
  const toast = useToast();

  const debounceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const skipRef = useRef(0);

  // ✅ useRef 로 관리하는 상태들
  const loadingRef = useRef(false);
  const hasMoreRef = useRef(true);

  // 사용자 목록 불러오기
  const loadUsers = useCallback(
    async (initial = false) => {
      if (loadingRef.current || (!initial && !hasMoreRef.current)) return;

      setLoading(true);
      loadingRef.current = true;

      try {
        const data = await fetchUsers({
          skip: initial ? 0 : skipRef.current,
          limit: LIMIT,
          user_name_key: keyword,
        });

        if (initial) {
          setUsers(data);
          skipRef.current = LIMIT;
        } else {
          setUsers((prev) => [...prev, ...data]);
          skipRef.current += LIMIT;
        }

        const more = data.length === LIMIT;
        setHasMore(more);
        hasMoreRef.current = more;
      } catch {
        toast({
          title: "사용자 로딩 실패",
          status: "error",
          duration: 2000,
          isClosable: true,
        });
      } finally {
        setLoading(false);
        loadingRef.current = false;
      }
    },
    [keyword, toast]
  );

  // 사용자 정보 수정
  const updateUserInfo = useCallback(
    async (user: User) => {
      try {
        await updateUser(user);
        toast({
          title: "수정 완료",
          status: "success",
          duration: 1500,
          isClosable: true,
        });
        await loadUsers(true);
      } catch {
        toast({
          title: "수정 실패",
          status: "error",
          duration: 1500,
          isClosable: true,
        });
      }
    },
    [loadUsers, toast]
  );

  // 검색 트리거
  const handleSearch = useCallback(() => {
    skipRef.current = 0;
    hasMoreRef.current = true;
    setHasMore(true);
    loadUsers(true);
  }, [loadUsers]);

  // keyword 변경 시 디바운스 처리
  useEffect(() => {
    if (debounceTimer.current) clearTimeout(debounceTimer.current);
    debounceTimer.current = setTimeout(() => {
      handleSearch();
    }, 500);
  }, [keyword, handleSearch]);

  useEffect(() => {
    loadUsers(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return {
    users,
    loading,
    keyword,
    setKeyword,
    handleSearch,
    loadMore: () => loadUsers(false),
    hasMore,
    update: updateUserInfo,
  };
}
