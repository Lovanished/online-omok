import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        board: "#dcb35c",
      },
    },
  },
  plugins: [],
};
export default config;
