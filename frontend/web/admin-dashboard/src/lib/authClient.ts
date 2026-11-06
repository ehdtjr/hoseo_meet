import axios from "axios";
import config from "../config";

// Login and refresh must never enter the authenticated client's retry loop.
const authClient = axios.create({
  baseURL: config.apiBaseUrl,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

export default authClient;
