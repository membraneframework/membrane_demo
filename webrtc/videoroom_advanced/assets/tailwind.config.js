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
  theme: {
    rotate: {
      135: "135deg",
    },
    extend: {
      invert: {
        50: ".50",
      },
    },
  },
  variants: {
    extend: {
      opacity: ["disabled"],
    },
    backgroundColor: ({ after }) => after(["disabled", "group-disabled"]),
  },
  plugins: [require("@tailwindcss/aspect-ratio")],
};
