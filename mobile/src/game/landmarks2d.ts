import type { GameCity } from "./types.ts";

/** Renderer-independent vector assets. The same paths drive Skia and visual QA. */
export type Ink = {
  path: string;
  color: string;
  strokeWidth?: number;
  opacity?: number;
};
export function polygon(points: number[][]) {
  return points.map(([x, y], i) => `${i ? "L" : "M"}${x} ${y}`).join(" ") + "Z";
}
export function ellipse(x: number, y: number, rx: number, ry: number) {
  return `M${x - rx} ${y}a${rx} ${ry} 0 1 0 ${rx * 2} 0a${rx} ${ry} 0 1 0 ${-rx * 2} 0Z`;
}
export function landmark2d(city: GameCity, level: number): Ink[] {
  const tier = Math.max(1, Math.min(4, Math.floor(level))),
    out: Ink[] = [];
  const add = (path: string, color: string, opacity?: number) =>
    out.push({ path, color, opacity });
  const poly = (points: number[][], color: string) =>
    add(polygon(points), color);
  const oval = (x: number, y: number, rx: number, ry: number, color: string) =>
    add(ellipse(x, y, rx, ry), color);
  const seed = [...city.id].reduce(
    (n, c) => (n * 31 + c.charCodeAt(0)) >>> 0,
    17,
  );
  const gold = "#E5BE78",
    light = "#ECDFC1",
    side = "#789689",
    dark = "#24493F",
    accent = city.accent;
  // Isometric plinth: identical footprint across all levels and asset families.
  oval(4, 8, 51, 18, "#092B29");
  poly(
    [
      [-48, 0],
      [0, 24],
      [48, 0],
      [48, 8],
      [0, 32],
      [-48, 8],
    ],
    "#315C4F",
  );
  poly(
    [
      [-48, 0],
      [0, -24],
      [48, 0],
      [0, 24],
    ],
    city.biome === "desert" ? "#927A53" : "#638C72",
  );
  poly(
    [
      [-40, 0],
      [0, -20],
      [40, 0],
      [0, 20],
    ],
    city.biome === "coast" ? "#598E91" : "#86A184",
  );
  const box = (x: number, y: number, w: number, h: number, d = w * 0.42) => {
    poly(
      [
        [x - w, y - h],
        [x, y - h + d],
        [x, y + d],
        [x - w, y],
      ],
      light,
    );
    poly(
      [
        [x, y - h + d],
        [x + w, y - h],
        [x + w, y],
        [x, y + d],
      ],
      side,
    );
    poly(
      [
        [x - w, y - h],
        [x, y - h - d],
        [x + w, y - h],
        [x, y - h + d],
      ],
      "#B5C4A6",
    );
  };
  const roof = (x: number, y: number, w: number) => {
    poly(
      [
        [x - w, y],
        [x, y - w * 0.6],
        [x + w, y],
        [x, y + w * 0.3],
      ],
      dark,
    );
    poly(
      [
        [x - w, y],
        [x, y - w * 0.6],
        [x, y + w * 0.3],
      ],
      accent,
    );
    add(`M${x - w} ${y}L${x} ${y + w * 0.3}L${x + w} ${y}`, gold);
  };
  const window = (x: number, y: number) =>
    poly(
      [
        [x - 2, y - 5],
        [x + 2, y - 3],
        [x + 2, y + 3],
        [x - 2, y + 1],
      ],
      gold,
    );
  const tree = (x: number, y: number, size = 1) => {
    poly(
      [
        [x - 1, y - 13 * size],
        [x + 1, y - 13 * size],
        [x + 1, y],
        [x - 1, y],
      ],
      dark,
    );
    poly(
      [
        [x - 8 * size, y - 6 * size],
        [x, y - 26 * size],
        [x + 8 * size, y - 6 * size],
      ],
      "#2B6853",
    );
    poly(
      [
        [x - 7 * size, y - 12 * size],
        [x, y - 31 * size],
        [x + 7 * size, y - 12 * size],
      ],
      "#9FBF89",
    );
  };
  // Outpost remains recognizable and distinct from developed landmarks.
  if (tier === 1) {
    box(0, 1, 12, 19);
    roof(0, -21, 17);
    poly(
      [
        [10, -24],
        [12, -24],
        [12, -48],
        [10, -48],
      ],
      gold,
    );
    poly(
      [
        [12, -48],
        [27, -43],
        [12, -38],
      ],
      accent,
    );
    window(-6, -9);
  } else {
    const h = 38 + tier * 10 + (seed % 7);
    switch (city.style) {
      case "harbor":
        box(0, 0, 13, h);
        box(0, -h + 2, 18, 9);
        roof(0, -h - 9, 21);
        for (let y = -12; y > -h + 12; y -= 13) window(-7, y);
        oval(0, -h - 3, 7, 3, gold);
        poly(
          [
            [-36, 11],
            [-13, -1],
            [-9, 2],
            [-31, 15],
          ],
          "#D2BA8C",
        );
        add("M18 10q6 -5 12 0t12 0", "#A9DCE0");
        break;
      case "sail":
        poly(
          [
            [-29, 4],
            [0, 14],
            [30, 2],
            [22, 12],
            [0, 20],
            [-22, 13],
          ],
          dark,
        );
        poly(
          [
            [-2, 7],
            [1, 7],
            [1, -h - 15],
            [-2, -h - 15],
          ],
          gold,
        );
        add(`M-5 ${-h - 7}Q-28 -22 -26 0L-5 -5Z`, light);
        add(`M4 ${-h + 4}Q29 -27 25 -4L4 4Z`, accent);
        poly(
          [
            [-1, -h - 16],
            [17, -h - 9],
            [-1, -h - 5],
          ],
          gold,
        );
        break;
      case "garden":
        oval(14, 9, 18, 7, "#4C8991");
        box(-8, -1, 18, 26);
        roof(-8, -29, 26);
        window(-17, -12);
        window(-8, -9);
        tree(26, -1, 1.1);
        tree(-30, -2, 0.75);
        add("M4 8Q17 -5 29 4L29 8Q17 0 4 12Z", light);
        if (tier >= 3) {
          box(-7, -32, 10, 15);
          roof(-7, -49, 17);
        }
        break;
      case "citadel":
        box(0, 4, 29, 24);
        box(0, -17, 23, 22);
        box(5, -38, 14, tier >= 3 ? 28 : 15);
        for (const x of [-22, -10, 2, 14]) {
          box(x, -2, 3, 9);
          window(x, -15);
        }
        roof(5, tier >= 3 ? -68 : -55, 17);
        break;
      case "gate":
        box(-22, 0, 11, 38);
        box(22, 0, 11, 38);
        box(0, -27, 31, 17);
        roof(0, -46, 40);
        window(-27, -20);
        window(17, -20);
        add("M-9 7L-9 -16Q0 -27 9 -16L9 7Z", dark);
        if (tier >= 3) {
          box(0, -47, 17, 17);
          roof(0, -66, 26);
        }
        break;
      case "pagoda":
        for (let i = 0; i < tier + 1; i++) {
          const y = -i * 18,
            w = 20 - i * 3;
          box(0, y, w, 17);
          roof(0, y - 19, w + 7);
          window(-w * 0.6, y - 7);
        }
        poly(
          [
            [-1, -(tier + 1) * 18 - 8],
            [0, -(tier + 1) * 18 - 20],
            [2, -(tier + 1) * 18 - 8],
          ],
          gold,
        );
        break;
      case "spire":
        poly(
          [
            [-18, 2],
            [0, 11],
            [0, -h - 20],
          ],
          light,
        );
        poly(
          [
            [0, 11],
            [19, 1],
            [0, -h - 20],
          ],
          accent,
        );
        poly(
          [
            [-11, -h * 0.4],
            [0, -h * 0.4 + 5],
            [13, -h * 0.4],
            [0, -h * 0.4 - 5],
          ],
          gold,
        );
        box(0, -h * 0.42, 10, 9);
        window(-5, -h * 0.42 - 3);
        poly(
          [
            [-1, -h - 20],
            [0, -h - 33],
            [2, -h - 20],
          ],
          gold,
        );
        break;
    }
  }
  if (tier >= 3) {
    tree(-33, 5, 0.65);
    box(29, 9, 7, 12);
    roof(29, -5, 10);
    poly(
      [
        [-36, 8],
        [-36, 15],
        [0, 33],
        [36, 15],
        [36, 8],
        [0, 26],
      ],
      "#C2BA97",
    );
    for (const x of [-29, -16, 16, 29]) box(x, 24 - Math.abs(x) * 0.45, 3, 7);
  }
  if (tier === 4) {
    oval(-27, 6, 5, 2, gold);
    oval(27, -5, 5, 2, gold);
    poly(
      [
        [-36, -4],
        [-34, -4],
        [-34, -39],
        [-36, -39],
      ],
      gold,
    );
    poly(
      [
        [-34, -39],
        [-19, -34],
        [-34, -29],
      ],
      accent,
    );
    add("M-14 23L0 30L14 23", gold);
    // City seed adds repeatable stars without nondeterministic render-time randomness.
    for (let i = 0; i < 3; i++) {
      const x = -24 + i * 24,
        y = -88 - (seed % 9) - (i === 1 ? 13 : 0);
      poly(
        [
          [x, y - 4],
          [x + 2, y],
          [x, y + 4],
          [x - 2, y],
        ],
        gold,
      );
    }
  }
  return out;
}
