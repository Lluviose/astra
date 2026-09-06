import { test } from "node:test";
import { URL } from "node:url";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { cities } from "../src/game/geography.ts";
import {
  regions,
  regionContains,
  mapProject,
  mapUnproject,
  fitCamera,
  clampCamera,
  toScreen,
  fromScreen,
  zoomAt,
  hitCity,
  selectAt,
  regionProgress,
  type MapRegion,
} from "../src/game/map2d.ts";
import { landmark2d } from "../src/game/landmarks2d.ts";
import { mapScene } from "../src/game/scene2d.ts";
import atlas from "../assets/map/china-provinces.json" with { type: "json" };
const progress = cities.map((city) => ({
  city,
  visits: 0,
  earned: 0,
  level: 0,
}));
const view = { width: 390, height: 388 };
const near = (a: number, b: number) =>
  assert.ok(Math.abs(a - b) < 1e-8, `${a} != ${b}`);

test("vendored geography matches the reviewed source and every city has a playable province", () => {
  const source = readFileSync(
    new URL("../assets/map/chn-adm1.source.geojson", import.meta.url),
  );
  assert.equal(createHash("sha256").update(source).digest("hex"), atlas.sha256);
  assert.equal(regions.length, 34);
  assert.equal(regions.filter((r) => r.playable).length, 31);
  for (const c of cities)
    assert.ok(
      regions.some((r) => r.playable && c.id.startsWith(r.id)),
      c.id,
    );
});
test("GeoJSON preserves finite closed polygon rings, including islands and holes", () => {
  let polygons = 0;
  for (const r of regions)
    for (const polygon of r.polygons) {
      polygons++;
      assert.ok(polygon.length > 0);
      for (const ring of polygon) {
        assert.ok(ring.length >= 4);
        assert.deepEqual(ring[0], ring.at(-1));
        for (const [lon, lat] of ring) {
          assert.ok(Number.isFinite(lon) && lon > 70 && lon < 140);
          assert.ok(Number.isFinite(lat) && lat > 0 && lat < 60);
        }
      }
    }
  assert.ok(polygons > regions.length);
});
test("known inland city coordinates land in the correct actual province", () => {
  for (const name of [
    "北京",
    "成都",
    "拉萨",
    "西安",
    "武汉",
    "昆明",
    "哈尔滨",
    "乌鲁木齐",
  ]) {
    const c = cities.find((c) => c.name === name)!;
    assert.ok(c, name);
    assert.ok(
      regionContains(
        regions.find((r) => c.id.startsWith(r.id))!,
        c.lon,
        c.lat,
      ),
      name,
    );
  }
});
test("point containment excludes holes and accepts a separate island", () => {
  const region: MapRegion = {
    id: "test",
    name: "test",
    sourceId: "test",
    playable: true,
    polygons: [
      [
        [
          [0, 0],
          [10, 0],
          [10, 10],
          [0, 10],
          [0, 0],
        ],
        [
          [3, 3],
          [7, 3],
          [7, 7],
          [3, 7],
          [3, 3],
        ],
      ],
      [
        [
          [20, 20],
          [21, 20],
          [21, 21],
          [20, 21],
          [20, 20],
        ],
      ],
    ],
  };
  assert.ok(regionContains(region, 1, 1));
  assert.ok(!regionContains(region, 5, 5));
  assert.ok(regionContains(region, 20.5, 20.5));
  assert.ok(!regionContains(region, 30, 30));
});
test("projection and camera inversion round trip every city after zoom and pan", () => {
  const camera = { x: -210, y: -180, scale: 1.3 };
  for (const c of cities) {
    const p = mapProject(c.lon, c.lat),
      geo = mapUnproject(p);
    near(geo[0], c.lon);
    near(geo[1], c.lat);
    const inverse = fromScreen(toScreen(p, camera), camera);
    near(inverse.x, p.x);
    near(inverse.y, p.y);
  }
});
test("zoom retains its focal point and camera cannot lose the board", () => {
  const initial = { x: -200, y: -160, scale: 1 };
  const anchor = { x: 190, y: 190 };
  const before = fromScreen(anchor, initial),
    after = fromScreen(anchor, zoomAt(initial, anchor, 1.5, view));
  near(before.x, after.x);
  near(before.y, after.y);
  const base = fitCamera(view),
    large = clampCamera({ scale: 100, x: 99999, y: -99999 }, view);
  near(large.scale, base.scale * 7);
  assert.ok(large.x <= 48);
  assert.ok(large.y >= view.height - 680 * large.scale - 48);
  near(clampCamera({ scale: 0.001, x: 0, y: 0 }, view).scale, base.scale);
});
test("tap selects the nearest city with a screen-space radius after transforms", () => {
  const city = progress.find((c) => c.city.name === "上海")!,
    camera = { x: -1200, y: -640, scale: 2 };
  const point = toScreen(mapProject(city.city.lon, city.city.lat), camera);
  assert.equal(hitCity(point, camera, progress), city.city.id);
  assert.equal(
    hitCity({ x: point.x + 21, y: point.y }, camera, [city]),
    city.city.id,
  );
  assert.equal(
    hitCity({ x: point.x + 23, y: point.y }, camera, [city]),
    undefined,
  );
  assert.equal(
    selectAt(toScreen(mapProject(150, 0), camera), camera, progress),
    undefined,
  );
});
test("province clicks fall back to a city in that province", () => {
  const camera = { x: 0, y: 0, scale: 3 };
  const point = toScreen(mapProject(85, 39), camera);
  assert.ok(selectAt(point, camera, progress)?.startsWith("65"));
});
test("province development counts owned cities without claiming the entire province", () => {
  const world = progress.map((c) => ({
    ...c,
    level: c.city.name === "成都" ? 2 : 0,
    visits: c.city.name === "成都" ? 3 : 0,
  }));
  const p = regionProgress(
    regions.find((r) => r.id === "51")!,
    world,
  );
  assert.equal(p.owned, 1);
  assert.equal(p.visited, 1);
  assert.ok(p.development > 0 && p.development < 1);
});
test("seven vector families evolve through four stages and are deterministic", () => {
  for (const style of [
    "harbor",
    "sail",
    "garden",
    "citadel",
    "gate",
    "pagoda",
    "spire",
  ]) {
    const city = cities.find((c) => c.style === style)!;
    const stages = [1, 2, 3, 4].map((t) => JSON.stringify(landmark2d(city, t)));
    assert.equal(new Set(stages).size, 4, style);
    assert.equal(stages[3], JSON.stringify(landmark2d(city, 4)));
    assert.ok(stages.every((s) => !s.includes("NaN")));
  }
});
test("large campaigns bound detailed rendering and always retain the selected city", () => {
  const world = {
    cities: progress.map((c) => ({ ...c, level: 4, visits: 10 })),
    era: 3,
    level: 12,
    totalXP: 10000,
    balance: 0,
  };
  const selected = cities.at(-1)!.id,
    scene = mapScene(world, selected);
  assert.equal(scene.markers.length, cities.length);
  assert.ok(scene.markers.filter((m) => m.art.length).length <= 64);
  assert.ok(scene.markers.find((m) => m.id === selected)?.art.length);
  assert.equal(scene.markers.at(-1)?.id, selected);
});
