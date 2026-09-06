import catalog from "../../assets/cities.json" with { type: "json" };
import type { Biome, GameCity, LandmarkStyle } from "./types.ts";

const coastNames = new Set(
  "上海 天津 大连 青岛 烟台 威海 日照 连云港 南通 宁波 舟山 温州 台州 福州 厦门 泉州 漳州 深圳 珠海 汕头 湛江 北海 海口 三亚 秦皇岛 防城港".split(
    " ",
  ),
);
const palettes: Record<Biome, string> = {
  coast: "#63C5D1",
  plateau: "#DCCB9D",
  forest: "#8BC4A0",
  desert: "#D9A76B",
  plain: "#B9B89B",
};
const signatures: Record<string, [string, LandmarkStyle]> = {
  上海: ["浦江灯塔", "harbor"],
  青岛: ["黄海帆塔", "sail"],
  成都: ["锦城竹庭", "garden"],
  拉萨: ["雪域石堡", "citadel"],
  北京: ["燕京城门", "gate"],
  西安: ["长安雁塔", "pagoda"],
  杭州: ["西湖水榭", "garden"],
  广州: ["珠江星塔", "spire"],
  深圳: ["鹏城光塔", "spire"],
  重庆: ["山城叠楼", "citadel"],
  哈尔滨: ["冰晶高塔", "spire"],
  三亚: ["天涯帆港", "sail"],
  苏州: ["姑苏园庭", "garden"],
  南京: ["金陵城阙", "gate"],
  敦煌: ["沙洲烽台", "citadel"],
  厦门: ["鹭岛灯塔", "harbor"],
  武汉: ["江城层楼", "pagoda"],
  昆明: ["春城花庭", "garden"],
};
function biomeOf(city: { name: string; province: string }): Biome {
  if (coastNames.has(city.name)) return "coast";
  if (/西藏|青海/.test(city.province)) return "plateau";
  if (/新疆|甘肃|宁夏|内蒙古/.test(city.province)) return "desert";
  if (/四川|云南|贵州|广西|福建|浙江/.test(city.province)) return "forest";
  return "plain";
}
const defaults: Record<Biome, [string, LandmarkStyle]> = {
  coast: ["潮汐灯塔", "harbor"],
  plateau: ["高原石堡", "citadel"],
  forest: ["山水庭院", "garden"],
  desert: ["绿洲烽台", "gate"],
  plain: ["星野楼阁", "pagoda"],
};
export const cities: GameCity[] = catalog.cities
  .filter((c) => !/香港|澳门|台湾/.test(c.province))
  .map((c) => {
    const biome = biomeOf(c);
    const [landmark, style] = signatures[c.name] ?? [
      `${c.name}·${defaults[biome][0]}`,
      defaults[biome][1],
    ];
    return { ...c, biome, landmark, style, accent: palettes[biome] };
  })
  .sort((a, b) => a.id.localeCompare(b.id));
export const cityById = new Map(cities.map((c) => [c.id, c]));
export const normalizeCity = (name: string) =>
  name.trim().normalize("NFKC").replace(/市$/, "");
export const resolveCity = (name: string) =>
  cities.find((c) => normalizeCity(c.name) === normalizeCity(name));
export function distance(a: GameCity, b: GameCity) {
  const r = Math.PI / 180;
  const x = (a.lon - b.lon) * Math.cos(((a.lat + b.lat) / 2) * r);
  return Math.hypot(x, a.lat - b.lat) * 111;
}
// Connected, bidirectional four-nearest-city graph, computed from bundled city centers.
const nearest = new Map(
  cities.map((c) => [
    c.id,
    cities
      .filter((o) => o.id !== c.id)
      .sort(
        (a, b) => distance(c, a) - distance(c, b) || a.id.localeCompare(b.id),
      )
      .slice(0, 4)
      .map((o) => o.id),
  ]),
);
export function adjacent(a: string, b: string) {
  return !!nearest.get(a)?.includes(b) || !!nearest.get(b)?.includes(a);
}
export const biomeLabels: Record<Biome, string> = {
  coast: "海岸",
  plateau: "高原",
  forest: "山林",
  desert: "旷野",
  plain: "平原",
};
