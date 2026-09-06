import { mapProject, regions, regionPath, regionProgress } from "./map2d.ts";
import { ellipse, landmark2d, polygon, type Ink } from "./landmarks2d.ts";
import type { WorldView } from "./types.ts";

export const majorCities = new Set([
  "110000",
  "310000",
  "440100",
  "510100",
  "540100",
  "650100",
  "230100",
  "610100",
]);
export const regionGeometry = regions.map((region) => ({
  region,
  path: regionPath(region),
}));
export function terrain2d(): Ink[] {
  const out: Ink[] = [];
  // Decorative motifs only; boundaries come exclusively from the bundled GeoJSON.
  const chains = [
    [81, 35, 7],
    [91, 35, 6],
    [96, 39, 4],
    [104, 31, 3],
    [123, 44, 4],
  ];
  for (const [lon, lat, count] of chains)
    for (let i = 0; i < count; i++) {
      const p = mapProject(lon + i * 1.3, lat + Math.sin(i) * 0.65),
        h = 8 + (i % 3) * 4;
      out.push({
        path: polygon([
          [p.x - 10, p.y],
          [p.x, p.y - h],
          [p.x + 11, p.y],
        ]),
        color: "#577F6B",
        opacity: 0.6,
      });
      out.push({
        path: polygon([
          [p.x, p.y - h],
          [p.x + 11, p.y],
          [p.x, p.y - 3],
        ]),
        color: "#A4B39B",
        opacity: 0.45,
      });
    }
  return out;
}
export const terrain = terrain2d();
function blend(a: string, b: string, amount: number) {
  const channel = (hex: string, i: number) => parseInt(hex.slice(i, i + 2), 16);
  return (
    "#" +
    [1, 3, 5]
      .map((i) =>
        Math.round(channel(a, i) * (1 - amount) + channel(b, i) * amount)
          .toString(16)
          .padStart(2, "0"),
      )
      .join("")
  );
}
export function mapScene(world: WorldView, selected: string) {
  const territory = regionGeometry.map(({ region, path }) => {
    const progress = regionProgress(region, world.cities);
    const developed = ["#659778", "#73A47E", "#8BAB7C", "#A4B47C"][
      Math.min(3, world.era)
    ];
    return {
      path,
      color: !region.playable
        ? "#375C53"
        : blend(
            "#476F60",
            developed,
            Math.min(
              1,
              progress.development * 0.7 +
                Math.log1p(progress.encounters) * 0.12,
            ),
          ),
      opacity: 1,
      border: region.id === selected.slice(0, 2) ? "#E5BE78" : "#95B4A0",
      progress,
    };
  });
  const detailed = new Set(
    [...world.cities]
      .sort(
        (a, b) =>
          Number(b.city.id === selected) - Number(a.city.id === selected) ||
          b.level - a.level ||
          b.visits - a.visits ||
          Number(majorCities.has(b.city.id)) -
            Number(majorCities.has(a.city.id)) ||
          a.city.id.localeCompare(b.city.id),
      )
      .filter(
        (c) =>
          c.city.id === selected ||
          c.level ||
          c.visits ||
          majorCities.has(c.city.id),
      )
      .slice(0, 64)
      .map((c) => c.city.id),
  );
  // All cities keep small hit targets. Detailed art is limited to meaningful cities.
  const markers = world.cities
    .map((c) => {
      const point = mapProject(c.city.lon, c.city.lat),
        chosen = c.city.id === selected;
      const important = detailed.has(c.city.id);
      return {
        ...point,
        id: c.city.id,
        name: c.city.name,
        chosen,
        important,
        level: c.level,
        color: c.level ? "#EDC984" : c.visits ? "#A8D8C2" : "#90AC9B",
        art: important ? landmark2d(c.city, Math.max(1, c.level)) : [],
        artScale: chosen ? 0.6 : c.level ? 0.46 : 0.3,
        opacity: c.level ? 1 : c.visits ? 0.85 : 0.55,
      };
    })
    .sort((a, b) => Number(a.chosen) - Number(b.chosen) || a.y - b.y);
  return { territory, markers };
}
export function player2d(era: number): Ink[] {
  const cloaks = ["#B0BA9F", "#8CC9B7", "#D9C492", "#ECC26D"],
    c = cloaks[Math.min(3, era)];
  const out: Ink[] = [
    { path: ellipse(0, 4, 10, 4), color: "#153F36" },
    { path: "M-9 2L-6 -17Q0 -22 6 -17L10 3Q0 8 -9 2Z", color: c },
    { path: ellipse(0, -22, 5, 6), color: "#EBDAC0" },
    { path: "M-6 -23Q0 -36 7 -23Z", color: "#2B5547" },
    { path: "M11 4L13 -21", color: "#D6B57B", strokeWidth: 2 },
  ];
  if (era >= 2)
    out.push({
      path: "M-7 -28L-7 -34L-2 -31L0 -38L3 -31L7 -34L7 -28Z",
      color: "#E5BE78",
    });
  return out;
}
