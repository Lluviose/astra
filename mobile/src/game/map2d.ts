import atlas from "../../assets/map/china-provinces.json" with { type: "json" };
import type { CityProgress } from "./types.ts";

export const BOARD = { width: 1000, height: 680 };
export type Point = { x: number; y: number };
export type Camera = Point & { scale: number };
export type Viewport = { width: number; height: number };
export const regions = atlas.regions;
export type MapRegion = (typeof regions)[number];

// Local equirectangular game projection with a standard parallel of 35 degrees.
// Every source uses WGS84. The projection is shared by geometry, cities and hit tests.
export function mapProject(lon: number, lat: number): Point {
  return { x: 40 + (lon - 73) * 14.6, y: 35 + (54 - lat) * 17.82 };
}
export function mapUnproject(p: Point): [number, number] {
  return [73 + (p.x - 40) / 14.6, 54 - (p.y - 35) / 17.82];
}
export function fitCamera(view: Viewport): Camera {
  "worklet";
  const scale = Math.max(
    0.01,
    Math.min((view.width - 32) / 1000, (view.height - 106) / 680),
  );
  return {
    scale,
    x: (view.width - 1000 * scale) / 2,
    y: 64 + (view.height - 106 - 680 * scale) / 2,
  };
}
export function clampCamera(camera: Camera, view: Viewport): Camera {
  "worklet";
  const base = fitCamera(view);
  const scale = Math.min(base.scale * 7, Math.max(base.scale, camera.scale));
  const clampAxis = (v: number, span: number, size: number, home: number) =>
    span <= size - 32 ? home : Math.min(48, Math.max(size - span - 48, v));
  return {
    scale,
    x: clampAxis(
      camera.x,
      1000 * scale,
      view.width,
      (view.width - 1000 * scale) / 2,
    ),
    y: clampAxis(camera.y, 680 * scale, view.height, base.y),
  };
}
export function toScreen(p: Point, camera: Camera): Point {
  "worklet";
  return { x: p.x * camera.scale + camera.x, y: p.y * camera.scale + camera.y };
}
export function fromScreen(p: Point, camera: Camera): Point {
  "worklet";
  return {
    x: (p.x - camera.x) / camera.scale,
    y: (p.y - camera.y) / camera.scale,
  };
}
export function zoomAt(
  camera: Camera,
  anchor: Point,
  factor: number,
  view: Viewport,
): Camera {
  "worklet";
  const p = fromScreen(anchor, camera),
    base = fitCamera(view);
  const scale = Math.min(
    base.scale * 7,
    Math.max(base.scale, camera.scale * factor),
  );
  return clampCamera(
    { scale, x: anchor.x - p.x * scale, y: anchor.y - p.y * scale },
    view,
  );
}
export function cityCamera(p: Point, view: Viewport): Camera {
  const scale = fitCamera(view).scale * 3.5;
  return clampCamera(
    {
      scale,
      x: view.width * 0.44 - p.x * scale,
      y: view.height * 0.53 - p.y * scale,
    },
    view,
  );
}
export function ringContains(point: Point, ring: number[][]) {
  let hit = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i],
      [xj, yj] = ring[j];
    if (
      yi > point.y !== yj > point.y &&
      point.x < ((xj - xi) * (point.y - yi)) / (yj - yi) + xi
    )
      hit = !hit;
  }
  return hit;
}
export function regionContains(region: MapRegion, lon: number, lat: number) {
  const p = { x: lon, y: lat };
  return region.polygons.some(
    ([outer, ...holes]) =>
      ringContains(p, outer) && !holes.some((r) => ringContains(p, r)),
  );
}
export function regionAt(p: Point) {
  const [lon, lat] = mapUnproject(p);
  return regions.find((r) => regionContains(r, lon, lat));
}
export function regionPath(region: MapRegion) {
  return region.polygons
    .flatMap((polygon) =>
      polygon.map(
        (ring) =>
          ring
            .map(([lon, lat], i) => {
              const p = mapProject(lon, lat);
              return `${i ? "L" : "M"}${p.x.toFixed(2)} ${p.y.toFixed(2)}`;
            })
            .join(" ") + "Z",
      ),
    )
    .join(" ");
}
export function hitCity(
  p: Point,
  camera: Camera,
  cities: CityProgress[],
  radius = 22,
) {
  return cities
    .map((c) => ({
      id: c.city.id,
      p: toScreen(mapProject(c.city.lon, c.city.lat), camera),
    }))
    .map((c) => ({ id: c.id, distance: Math.hypot(c.p.x - p.x, c.p.y - p.y) }))
    .filter((c) => c.distance <= radius)
    .sort((a, b) => a.distance - b.distance || a.id.localeCompare(b.id))[0]?.id;
}
export function selectAt(p: Point, camera: Camera, cities: CityProgress[]) {
  const hit = hitCity(p, camera, cities);
  if (hit) return hit;
  const board = fromScreen(p, camera),
    region = regionAt(board);
  if (!region?.playable) return undefined;
  return cities
    .filter((c) => c.city.id.startsWith(region.id))
    .sort((a, b) => {
      const pa = mapProject(a.city.lon, a.city.lat),
        pb = mapProject(b.city.lon, b.city.lat);
      return (
        Math.hypot(pa.x - board.x, pa.y - board.y) -
        Math.hypot(pb.x - board.x, pb.y - board.y)
      );
    })[0]?.city.id;
}
export function regionProgress(region: MapRegion, cities: CityProgress[]) {
  const local = cities.filter((c) => c.city.id.startsWith(region.id));
  return {
    encounters: local.reduce((sum, c) => sum + c.visits, 0),
    total: local.length,
    visited: local.filter((c) => c.visits > 0).length,
    owned: local.filter((c) => c.level > 0).length,
    development: local.length
      ? local.reduce((n, c) => n + c.level, 0) / (local.length * 4)
      : 0,
  };
}
