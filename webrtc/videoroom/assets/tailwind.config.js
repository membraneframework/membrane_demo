module.exports = {
  mode: "jit",
  purge: {
    content: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
    safelist: [
      "grid",
      "grid-cols-1",
      "md:grid-cols-1",
      "md:grid-cols-2",
      "md:grid-cols-3",
      "md:grid-cols-4",
    ],
  },
  theme: {},
  variants: {
    extend: {},
  },
  plugins: [require("@tailwindcss/aspect-ratio")],
};
