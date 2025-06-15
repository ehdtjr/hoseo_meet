import api from "../lib/axios";
import type { User } from "../types/user";

export const fetchUsers = async ({
  skip = 0,
  limit = 30,
  user_name_key = "",
}: {
  skip?: number;
  limit?: number;
  user_name_key?: string;
}): Promise<User[]> => {
  const response = await api.get<User[]>("/admin/user/list", {
    params: { skip, limit, user_name_key },
  });

  return response.data;
};
