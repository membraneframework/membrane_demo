const esbuild = require("esbuild");
const path = require("path");

esbuild
  .build({
    entryPoints: ["src/index.ts"],
    outdir: path.resolve(__dirname, "../priv/static/"),
    bundle: true,
    sourcemap: true,
    minify: true,
    format: "cjs",
    target: ["es6"],
  })
  .catch(() => process.exit(1));
