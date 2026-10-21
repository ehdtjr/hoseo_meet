import api from "../lib/axios";
import type { Report } from "../types/report";

interface FetchReportsParams {
  skip?: number;
  limit?: number;
  is_resolved?: boolean | null;
}

export const fetchReports = async ({
  skip = 0,
  limit = 30,
  is_resolved,
}: FetchReportsParams): Promise<Report[]> => {
  const response = await api.get<Report[]>("/admin/report/list", {
    params: {
      skip,
      limit,
      is_resolved,
    },
  });

  return response.data;
};

export const updateReport = async (report: Report): Promise<void> => {
  await api.post("/admin/report/update", report);
};
