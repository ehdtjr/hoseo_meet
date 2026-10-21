import { Box, Flex, Button, Spinner, Select } from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import ReportList from "../components/reports/ReportList";
import { useReports } from "../hooks/useReport";

export default function ReportPage() {
  const {
    reports,
    loading,
    hasMore,
    isResolvedFilter,
    loadMore,
    applyFilter,
    modifyReport,
  } = useReports();

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
      <Flex mb={4} gap={4} align="center">
        <Select
          value={
            isResolvedFilter === null
              ? "all"
              : isResolvedFilter
              ? "true"
              : "false"
          }
          onChange={(e) => {
            const value = e.target.value;
            if (value === "true") applyFilter(true);
            else if (value === "false") applyFilter(false);
            else applyFilter(null);
          }}
          maxW="200px"
        >
          <option value="all">전체</option>
          <option value="false">미처리</option>
          <option value="true">처리됨</option>
        </Select>
        <Button
          onClick={() => applyFilter(isResolvedFilter)}
          colorScheme="teal"
        >
          새로고침
        </Button>
      </Flex>

      <ReportList reports={reports} onUpdate={modifyReport} />

      {loading && (
        <Flex justify="center" align="center" mt={4} minH="100px">
          <Spinner size="lg" />
        </Flex>
      )}

      <div ref={loaderRef} style={{ height: "1px" }} />
    </Box>
  );
}
