# Offline map provenance

`chn-adm1.source.geojson` is the unchanged **geoBoundaries gbOpen CHN ADM1** input, revision `9469f09`, boundary ID `CHN-ADM1-43563684`. Its represented year is **2019**; upstream build date is 2023-12-12. It is an overview boundary dataset, not current surveying or city-level boundary data.

- Author/source: geoBoundaries / Wikimedia Commons.
- [Source metadata](https://www.geoboundaries.org/api/current/gbOpen/CHN/ADM1/).
- [Pinned original GeoJSON](https://github.com/wmgeolab/geoBoundaries/blob/9469f09/releaseData/gbOpen/CHN/ADM1/geoBoundaries-CHN-ADM1.geojson).
- [Direct LFS content](https://media.githubusercontent.com/media/wmgeolab/geoBoundaries/9469f09/releaseData/gbOpen/CHN/ADM1/geoBoundaries-CHN-ADM1.geojson).
- Original geometry license: **Public Domain**, as recorded in this layer's upstream metadata. geoBoundaries compilation: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); attribution retained in the app and here. [geoBoundaries terms](https://www.geoboundaries.org/index.html#usage).
- Source SHA-256: `3a00467a0db9b4136facb5f2f3d0edbfd96adb15651cfdf63991da9281030e85` (270,578 bytes).
- CRS: `urn:ogc:def:crs:OGC:1.3:CRS84`, longitude/latitude WGS-84. No GCJ-02 tiles or coordinate conversion.

Run `npm run map:build` to reproduce `china-provinces.json` offline. The script checks the source hash, normalizes Chinese names and province codes, quantizes coordinates to four decimals, and preserves all rings, holes and separate islands. The source's mislabeled `Guangzhou Province` is mapped to Guangdong / 广东 (44); geometry is untouched. All 34 source regions remain on the map; 31 mainland regions participate in this game's existing city catalog. Other regions have a neutral background.

Province coloring summarizes recorded/owned cities, not ownership of a whole province or measured conquered area. There are no prefecture boundaries in this asset; ADM2 from the same provider is actually county-level for China and is deliberately not mislabeled as prefectures. Mountains and buildings are original decorative vectors. Do not describe this layer as a 2026 official national standard map; the source's island/coastline detail and territorial representation are retained as provided.

To replace it, review the new license, vintage, coverage and CRS; update the pinned source and hash; regenerate the runtime asset; run geography tests and compare a map render. App startup and normal CI never download GIS data.
