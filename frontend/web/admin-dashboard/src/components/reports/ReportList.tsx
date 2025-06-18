import {
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Button,
  Badge,
} from "@chakra-ui/react";
import { format } from "date-fns";
import type { Report } from "../../types/report";

interface ReportListProps {
  reports: Report[];
  onUpdate: (report: Report) => void;
}

export default function ReportList({ reports, onUpdate }: ReportListProps) {
  return (
    <Table variant="simple" size="md">
      <Thead bg="gray.100" position="sticky" top={0} zIndex={1}>
        <Tr>
          <Th>ID</Th>
          <Th>신고자</Th>
          <Th>피신고자</Th>
          <Th>사유</Th>
          <Th>처리 여부</Th>
          <Th>신고일</Th>
          <Th>관리</Th>
        </Tr>
      </Thead>
      <Tbody>
        {reports.map((report) => (
          <Tr key={`${report.id}-${report.created_at}`}>
            <Td>{report.id}</Td>
            <Td>{report.reporter_id}</Td>
            <Td>{report.reported_user_id}</Td>
            <Td>{report.reason}</Td>
            <Td>
              <Badge colorScheme={report.is_resolved ? "green" : "red"}>
                {report.is_resolved ? "처리됨" : "미처리"}
              </Badge>
            </Td>
            <Td>{format(new Date(report.created_at), "yyyy-MM-dd HH:mm")}</Td>
            <Td>
              <Button
                size="sm"
                colorScheme={report.is_resolved ? "gray" : "teal"}
                onClick={() =>
                  onUpdate({ ...report, is_resolved: !report.is_resolved })
                }
              >
                {report.is_resolved ? "되돌리기" : "처리 완료"}
              </Button>
            </Td>
          </Tr>
        ))}
      </Tbody>
    </Table>
  );
}
