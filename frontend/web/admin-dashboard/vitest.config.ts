import { defineConfig, mergeConfig } from "vitest/config";
import viteConfig from "./vite.config";

export default mergeConfig(viteConfig, defineConfig({
  test: {
    include: ["tests/**/*.test.{ts,tsx}"],
    testTimeout: 3000,
  },
}));
