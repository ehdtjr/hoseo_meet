import { useState, useEffect, useCallback, useRef } from "react";
import { useToast } from "@chakra-ui/react";
import type { Report } from "../types/report";
import { fetchReports, updateReport } from "../services/reportService";

export function useReports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [isResolvedFilter, setIsResolvedFilter] = useState<boolean | null>(
    null
  );

  const LIMIT = 30;
  const toast = useToast();

  const skipRef = useRef(0);
  const loadingRef = useRef(false);
  const hasMoreRef = useRef(true);

  // 🔄 신고 목록 불러오기
  const loadReports = useCallback(
    async (initial = false) => {
      if (loadingRef.current || (!initial && !hasMoreRef.current)) return;

      setLoading(true);
      loadingRef.current = true;

      try {
        const data = await fetchReports({
          skip: initial ? 0 : skipRef.current,
          limit: LIMIT,
          is_resolved: isResolvedFilter,
        });

        if (initial) {
          skipRef.current = LIMIT;
          setReports(data);
        } else {
          skipRef.current += LIMIT;

          // 중복 제거
          setReports((prev) => {
            const merged = [...prev, ...data];
            const uniqueMap = new Map<number, Report>();
            merged.forEach((item) => uniqueMap.set(item.id, item));
            return Array.from(uniqueMap.values());
          });
        }

        const more = data.length === LIMIT;
        setHasMore(more);
        hasMoreRef.current = more;
      } catch {
        toast({
          title: "신고 목록 불러오기 실패",
          status: "error",
          duration: 2000,
          isClosable: true,
        });
      } finally {
        setLoading(false);
        loadingRef.current = false;
      }
    },
    [isResolvedFilter, toast]
  );

  // ✅ 신고 수정 (단순히 Report 전체 수정)
  const modifyReport = useCallback(
    async (updated: Report) => {
      try {
        await updateReport(updated);
        toast({
          title: "신고가 수정되었습니다.",
          status: "success",
          duration: 1500,
          isClosable: true,
        });
        await loadReports(true);
      } catch {
        toast({
          title: "신고 수정 실패",
          status: "error",
          duration: 1500,
          isClosable: true,
        });
      }
    },
    [loadReports, toast]
  );

  // 필터 적용 시 초기화 후 재로딩
  const applyFilter = useCallback((isResolved: boolean | null) => {
    skipRef.current = 0;
    hasMoreRef.current = true;
    setHasMore(true);
    setIsResolvedFilter(isResolved);
  }, []);

  useEffect(() => {
    loadReports(true);
  }, [loadReports]);

  return {
    reports,
    loading,
    hasMore,
    isResolvedFilter,
    loadMore: () => loadReports(false),
    applyFilter,
    modifyReport,
  };
}
