// Actual Skia geometry/raster QA; this does not replace iOS UI tests.
import { createRequire } from "node:module";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { cities } from "../src/game/geography.ts";
import { fitCamera } from "../src/game/map2d.ts";
import { mapScene, terrain, player2d } from "../src/game/scene2d.ts";
import { landmark2d } from "../src/game/landmarks2d.ts";
const require = createRequire(import.meta.url);
const {
  LoadSkiaWeb,
} = require("@shopify/react-native-skia/lib/commonjs/web/LoadSkiaWeb");
await LoadSkiaWeb({
  locateFile: () => require.resolve("canvaskit-wasm/bin/full/canvaskit.wasm"),
});
const {
  getSkiaExports,
  makeOffscreenSurface,
  PaintStyle,
  FillType,
} = require("@shopify/react-native-skia/lib/commonjs/headless");
const { Skia } = getSkiaExports();
const output = resolve(process.argv[2] || "verification");
mkdirSync(output, { recursive: true });
let paths = 0;
function ink(canvas, items) {
  for (const item of items) {
    const path = Skia.Path.MakeFromSVGString(item.path);
    if (!path) throw new Error("Invalid vector: " + item.path);
    path.setFillType(FillType.EvenOdd);
    const paint = Skia.Paint();
    paint.setAntiAlias(true);
    paint.setColor(Skia.Color(item.color));
    paint.setAlphaf(item.opacity ?? 1);
    if (item.strokeWidth) {
      paint.setStyle(PaintStyle.Stroke);
      paint.setStrokeWidth(item.strokeWidth);
    }
    canvas.drawPath(path, paint);
    path.dispose();
    paint.dispose();
    paths++;
  }
}
function save(surface, name) {
  surface.flush();
  const image = surface.makeImageSnapshot();
  writeFileSync(resolve(output, name), image.encodeToBytes());
  image.dispose();
  surface.dispose();
}
function at(canvas, x, y, scale, draw) {
  canvas.save();
  canvas.translate(x, y);
  canvas.scale(scale, scale);
  draw();
  canvas.restore();
}
for (const developed of [false, true]) {
  const surface = makeOffscreenSurface(1170, 1164),
    canvas = surface.getCanvas();
  canvas.clear(Skia.Color("#123D37"));
  canvas.scale(3, 3);
  const world = {
    cities: cities.map((city, i) => ({
      city,
      visits: developed && i % 9 === 0 ? 8 : 0,
      level: developed && i % 9 === 0 ? 1 + (i % 4) : 0,
      earned: 0,
    })),
    era: developed ? 2 : 0,
    level: developed ? 8 : 1,
    totalXP: 0,
    balance: 0,
  };
  const scene = mapScene(world, "310000"),
    camera = fitCamera({ width: 390, height: 388 });
  at(canvas, camera.x, camera.y, camera.scale, () => {
    for (const p of scene.territory)
      ink(canvas, [
        p,
        { path: p.path, color: p.border, strokeWidth: 1.5, opacity: 0.65 },
      ]);
    ink(canvas, terrain);
    for (const m of scene.markers.filter((m) => m.important))
      at(canvas, m.x, m.y, m.artScale, () => ink(canvas, m.art));
  });
  save(surface, developed ? "atlas-developed.png" : "atlas-empty.png");
}
const surface = makeOffscreenSurface(1080, 1370),
  canvas = surface.getCanvas();
canvas.clear(Skia.Color("#153C34"));
const examples = ["上海", "青岛", "成都", "拉萨", "北京", "西安", "广州"];
for (let row = 0; row < examples.length; row++) {
  const city = cities.find((c) => c.name === examples[row]);
  for (let stage = 1; stage <= 4; stage++)
    at(canvas, 135 + (stage - 1) * 270, 160 + row * 190, 1.5, () =>
      ink(canvas, landmark2d(city, stage)),
    );
}
save(surface, "landmarks-stages.png");
const check = makeOffscreenSurface(2, 2);
for (const city of cities)
  for (let stage = 1; stage <= 4; stage++)
    ink(check.getCanvas(), landmark2d(city, stage));
for (let era = 0; era < 4; era++) ink(check.getCanvas(), player2d(era));
check.dispose();
console.log(`Skia rendered ${paths} valid paths; images: ${output}`);
