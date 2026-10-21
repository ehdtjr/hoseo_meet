const config = {
  apiBaseUrl:
    import.meta.env.VITE_API_BASE_URL || "https://campusmeet.store/api/v1",
};
export default config;

console.log("VITE_API_BASE_URL:", config.apiBaseUrl);
