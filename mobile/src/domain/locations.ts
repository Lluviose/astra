import catalog from "../../assets/cities.json";
export function findCity(name: string) {
  return catalog.cities.find(
    (c) => c.name.replace(/市$/, "") === name.trim().replace(/市$/, ""),
  );
}
// WGS-84 city centers to GCJ-02 for mainland Apple map tiles. No device location is read.
export function mapCoordinate(lat: number, lon: number) {
  if (lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271)
    return { latitude: lat, longitude: lon };
  const x = lon - 105,
    y = lat - 35,
    pi = Math.PI;
  let dlat =
    -100 +
    2 * x +
    3 * y +
    0.2 * y * y +
    0.1 * x * y +
    0.2 * Math.sqrt(Math.abs(x));
  dlat += ((20 * Math.sin(6 * x * pi) + 20 * Math.sin(2 * x * pi)) * 2) / 3;
  dlat += ((20 * Math.sin(y * pi) + 40 * Math.sin((y / 3) * pi)) * 2) / 3;
  dlat +=
    ((160 * Math.sin((y / 12) * pi) + 320 * Math.sin((y * pi) / 30)) * 2) / 3;
  let dlon =
    300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  dlon += ((20 * Math.sin(6 * x * pi) + 20 * Math.sin(2 * x * pi)) * 2) / 3;
  dlon += ((20 * Math.sin(x * pi) + 40 * Math.sin((x / 3) * pi)) * 2) / 3;
  dlon +=
    ((150 * Math.sin((x / 12) * pi) + 300 * Math.sin((x / 30) * pi)) * 2) / 3;
  const rad = (lat / 180) * pi,
    sin = Math.sin(rad),
    magic = 1 - 0.006693421622965943 * sin * sin,
    sqrt = Math.sqrt(magic);
  dlat =
    (dlat * 180) /
    (((6378245 * (1 - 0.006693421622965943)) / (magic * sqrt)) * pi);
  dlon = (dlon * 180) / ((6378245 / sqrt) * Math.cos(rad) * pi);
  return { latitude: lat + dlat, longitude: lon + dlon };
}
