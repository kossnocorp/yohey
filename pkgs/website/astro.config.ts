import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";
import { writeFile } from "node:fs/promises";

export default defineConfig({
  site: "https://yohey.fyi",
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [{
    name: "release-installer",
    hooks: {
      "astro:build:done": async ({ dir }) => {
        const repo = process.env.GITHUB_REPOSITORY || "kossnocorp/yohey";
        await writeFile(new URL("_redirects", dir),
          `/install.sh https://github.com/${repo}/releases/latest/download/install.sh 302\n`);
      },
    },
  }],
});
