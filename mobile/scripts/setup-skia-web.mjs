import { createRequire } from "node:module";
import { mkdirSync, copyFileSync } from "node:fs";
const require = createRequire(import.meta.url);
const directory = new URL("../public/", import.meta.url);
mkdirSync(directory, { recursive: true });
copyFileSync(
  require.resolve("canvaskit-wasm/bin/full/canvaskit.wasm"),
  new URL("canvaskit.wasm", directory),
);
console.log("Copied matching CanvasKit WASM for offline web preview.");
