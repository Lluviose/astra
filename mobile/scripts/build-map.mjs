import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";

// The input is vendored, pinned and hash checked: normal builds never fetch maps.
const root = new URL("../assets/map/", import.meta.url);
const raw = readFileSync(new URL("chn-adm1.source.geojson", root));
const sha256 = createHash("sha256").update(raw).digest("hex");
if (
  sha256 !== "3a00467a0db9b4136facb5f2f3d0edbfd96adb15651cfdf63991da9281030e85"
)
  throw new Error(
    "Map source changed. Review provenance before updating its hash.",
  );
const names = {
  Beijing: ["11", "北京"],
  Tianjin: ["12", "天津"],
  Hebei: ["13", "河北"],
  Shanxi: ["14", "山西"],
  "Inner Mongolia": ["15", "内蒙古"],
  Liaoning: ["21", "辽宁"],
  Jilin: ["22", "吉林"],
  Heilongjiang: ["23", "黑龙江"],
  Shanghai: ["31", "上海"],
  Jiangsu: ["32", "江苏"],
  Zhejiang: ["33", "浙江"],
  Anhui: ["34", "安徽"],
  Fujian: ["35", "福建"],
  Jiangxi: ["36", "江西"],
  Shandong: ["37", "山东"],
  Henan: ["41", "河南"],
  Hubei: ["42", "湖北"],
  Hunan: ["43", "湖南"],
  // Upstream labels Guangdong "Guangzhou Province"; only the display name is corrected.
  Guangzhou: ["44", "广东"],
  Guangxi: ["45", "广西"],
  Hainan: ["46", "海南"],
  Chongqing: ["50", "重庆"],
  Sichuan: ["51", "四川"],
  Guizhou: ["52", "贵州"],
  Yunnan: ["53", "云南"],
  Tibet: ["54", "西藏"],
  Shaanxi: ["61", "陕西"],
  Gansu: ["62", "甘肃"],
  Qinghai: ["63", "青海"],
  Ningxia: ["64", "宁夏"],
  Xinjiang: ["65", "新疆"],
  Taiwan: ["71", "台湾"],
  "Hong Kong": ["81", "香港"],
  Macau: ["82", "澳门"],
};
const source = JSON.parse(raw);
if (source.crs.properties.name !== "urn:ogc:def:crs:OGC:1.3:CRS84")
  throw new Error("Expected WGS-84 longitude/latitude.");
const regions = source.features
  .map(({ properties: p, geometry: g }) => {
    const entry = Object.entries(names).find(([prefix]) =>
      p.shapeName.startsWith(prefix + " "),
    );
    if (!entry) throw new Error(`Unmapped region: ${p.shapeName}`);
    const [id, name] = entry[1];
    const polygons = g.type === "Polygon" ? [g.coordinates] : g.coordinates;
    // Quantize shared vertices identically; preserve every ring, hole and island.
    const rings = polygons.map((polygon) =>
      polygon.map((ring) =>
        ring.map(([x, y]) => [Number(x.toFixed(4)), Number(y.toFixed(4))]),
      ),
    );
    return {
      id,
      name,
      sourceId: p.shapeID,
      playable: !["71", "81", "82"].includes(id),
      polygons: rings,
    };
  })
  .sort((a, b) => a.id.localeCompare(b.id));
if (new Set(regions.map((r) => r.id)).size !== 34)
  throw new Error("Expected 34 unique regions");
const output = {
  version: 1,
  crs: "WGS84",
  year: 2019,
  source: "geoBoundaries gbOpen CHN ADM1",
  revision: "9469f09",
  sha256,
  regions,
};
writeFileSync(
  new URL("china-provinces.json", root),
  JSON.stringify(output) + "\n",
);
console.log(
  `Built ${regions.length} regions, ${regions.filter((r) => r.playable).length} playable.`,
);
