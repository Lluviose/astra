import React, { useMemo, useLayoutEffect, useRef } from "react";
import * as THREE from "three";
import {
  hainanOutline,
  inside,
  mainlandOutline,
  project,
} from "../../game/geography";
import type { GameCity, WorldView } from "../../game/types";

export type AtlasProps = {
  world: WorldView;
  selected: string;
  rotation: number;
  zoom: number;
  focusCity?: boolean;
  onSelect: (id: string) => void;
};
const gold = "#DAB477";
const surfaceHeight = (lon: number, lat: number) =>
  lon < 101 && lat < 39 && lat > 27
    ? 0.2 + Math.abs(Math.sin(lon * lat)) * 0.22
    : 0.06 + Math.abs(Math.sin(lon + lat)) * 0.055;
export function Landmark({
  city,
  level,
  preview = false,
}: {
  city: GameCity;
  level: number;
  preview?: boolean;
}) {
  const tier = preview ? 4 : level;
  const color = tier > 0 ? city.accent : "#6A7C78";
  // A stable city seed gives each city its own height, roof orientation and silhouette.
  const seed = Number(city.id) % 17;
  const cityScale = 0.9 + Number(city.id) / 5000000;
  const height = 0.22 + tier * 0.105 + seed * 0.006;
  const box = (
    x: number,
    y: number,
    z: number,
    sx: number,
    sy: number,
    sz: number,
    tint = color,
  ) => (
    <mesh position={[x, y, z]}>
      <boxGeometry args={[sx, sy, sz]} />
      <meshStandardMaterial color={tint} roughness={0.72} />
    </mesh>
  );
  if (tier === 0)
    return (
      <mesh position={[0, 0.07, 0]}>
        <octahedronGeometry args={[0.06]} />
        <meshStandardMaterial color={color} />
      </mesh>
    );
  return (
    <group
      rotation={[0, seed * 0.13, 0]}
      scale={[cityScale, 1 + (Number(city.id) % 10000) / 50000, 1]}
    >
      {box(0, 0.035, 0, 0.44, 0.07, 0.38, "#566C64")}
      {city.style === "sail" ? (
        <>
          {box(0, height / 2, 0, 0.025, height, 0.035, gold)}
          <mesh position={[0.08, height / 2, 0]} rotation={[0, 0, -0.25]}>
            <coneGeometry args={[0.17, height, 3]} />
            <meshStandardMaterial color={color} />
          </mesh>
        </>
      ) : city.style === "garden" ? (
        <>
          {box(0, 0.13, 0, 0.3, 0.2, 0.23)}
          <mesh position={[0, 0.29, 0]} rotation={[0, Math.PI / 4, 0]}>
            <coneGeometry args={[0.28, 0.14, 4]} />
            <meshStandardMaterial color={gold} />
          </mesh>
          {[-1, 1].map((n) => (
            <mesh key={n} position={[n * 0.19, 0.29, n * 0.1]}>
              <coneGeometry args={[0.065, 0.4, 5]} />
              <meshStandardMaterial color="#519B78" />
            </mesh>
          ))}
        </>
      ) : city.style === "gate" || city.style === "citadel" ? (
        <>
          {box(-0.13, height / 2, 0, 0.13, height, 0.2)}
          {box(0.13, height / 2, 0, 0.13, height, 0.2)}
          {box(0, height * 0.7, 0, 0.35, 0.1, 0.24, gold)}
          {tier >= 3 && box(0, height + 0.04, 0, 0.19, 0.2, 0.19)}
        </>
      ) : (
        <>
          <mesh position={[0, height / 2, 0]}>
            <cylinderGeometry
              args={[0.075, 0.13, height, city.style === "spire" ? 6 : 8]}
            />
            <meshStandardMaterial
              color={color}
              metalness={0.2}
              roughness={0.5}
            />
          </mesh>
          {city.style === "pagoda" &&
            Array.from({ length: tier + 1 }, (_, i) => (
              <mesh
                key={i}
                position={[0, 0.16 + (i * height) / (tier + 1), 0]}
                rotation={[0, Math.PI / 4, 0]}
              >
                <coneGeometry args={[0.2 - i * 0.015, 0.09, 4]} />
                <meshStandardMaterial color={gold} />
              </mesh>
            ))}
          <mesh position={[0, height + 0.055, 0]}>
            <sphereGeometry args={[0.08, 8, 6]} />
            <meshStandardMaterial
              color={gold}
              emissive={gold}
              emissiveIntensity={0.5}
            />
          </mesh>
        </>
      )}
      {tier >= 2 && box(0.24, 0.1, 0.12, 0.12, 0.2, 0.12)}
      {tier >= 3 && box(-0.23, 0.14, -0.13, 0.11, 0.28, 0.11)}
      {tier >= 4 && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.065, 0]}>
          <ringGeometry args={[0.34, 0.37, 32]} />
          <meshBasicMaterial color={gold} side={THREE.DoubleSide} />
        </mesh>
      )}
    </group>
  );
}

const tiles = (() => {
  const result: {
    x: number;
    z: number;
    height: number;
    lon: number;
    lat: number;
  }[] = [];
  for (let row = 0; row < 46; row++)
    for (let col = 0; col < 69; col++) {
      const lon = 73 + col * 0.92 + (row % 2) * 0.46,
        lat = 18 + row * 0.8;
      if (
        !inside(lon, lat, mainlandOutline) &&
        !inside(lon, lat, hainanOutline)
      )
        continue;
      const [x, z] = project(lon, lat);
      const mountain = lon < 101 && lat < 39 && lat > 27;
      result.push({
        x,
        z,
        lon,
        lat,
        height: mountain
          ? 0.2 + Math.abs(Math.sin(lon * lat)) * 0.22
          : 0.06 + Math.abs(Math.sin(lon + lat)) * 0.055,
      });
    }
  return result;
})();
function Terrain({ world }: { world: WorldView }) {
  const ref = useRef<THREE.InstancedMesh>(null);
  useLayoutEffect(() => {
    if (!ref.current) return;
    const matrix = new THREE.Matrix4(),
      color = new THREE.Color();
    const owned = world.cities.filter((p) => p.level > 0);
    const visited = world.cities.filter((p) => p.visits > 0);
    tiles.forEach((tile, i) => {
      const influence = owned.find(
        (p) =>
          Math.hypot((p.city.lon - tile.lon) * 0.8, p.city.lat - tile.lat) <
          0.8 + p.level * 0.55,
      );
      const discovered =
        influence ||
        visited.some(
          (p) =>
            Math.hypot((p.city.lon - tile.lon) * 0.8, p.city.lat - tile.lat) <
            1.2,
        );
      const height = tile.height + (influence ? influence.level * 0.025 : 0);
      matrix.compose(
        new THREE.Vector3(tile.x, height / 2, tile.z),
        new THREE.Quaternion(),
        new THREE.Vector3(1, height, 1),
      );
      ref.current!.setMatrixAt(i, matrix);
      color.set(
        influence
          ? "#749985"
          : discovered
            ? "#607D73"
            : tile.height > 0.2
              ? "#566461"
              : "#354F49",
      );
      if (influence) color.lerp(new THREE.Color("#D2BA82"), world.era * 0.1);
      ref.current!.setColorAt(i, color);
    });
    ref.current.instanceMatrix.needsUpdate = true;
    if (ref.current.instanceColor) ref.current.instanceColor.needsUpdate = true;
  }, [world]);
  return (
    <instancedMesh
      ref={ref}
      args={[undefined, undefined, tiles.length]}
      frustumCulled={false}
    >
      <cylinderGeometry args={[0.087, 0.087, 1, 6]} />
      <meshStandardMaterial roughness={0.95} />
    </instancedMesh>
  );
}
export default function AtlasScene({
  world,
  selected,
  rotation,
  zoom,
  focusCity,
  onSelect,
}: AtlasProps) {
  const visible = useMemo(
    () =>
      world.cities.filter(
        (p) =>
          p.visits > 0 ||
          p.level > 0 ||
          p.city.id === selected ||
          [
            "110000",
            "310000",
            "510100",
            "540100",
            "650100",
            "230100",
            "460200",
            "610100",
            "440100",
          ].includes(p.city.id),
      ),
    [world, selected],
  );
  if (focusCity) {
    const city = world.cities.find((p) => p.city.id === selected)!;
    return (
      <>
        <color attach="background" args={["#102D2B"]} />
        <ambientLight intensity={1.5} />
        <directionalLight
          position={[-3, 10, 5]}
          intensity={2.2}
          color="#FFF0CA"
        />
        <group
          scale={6 * zoom}
          rotation={[0, rotation, 0]}
          position={[0, -1.3, 0]}
        >
          <Landmark
            city={city.city}
            level={city.level}
            preview={city.level === 0}
          />
        </group>
      </>
    );
  }
  return (
    <>
      <color attach="background" args={["#102D2B"]} />
      <ambientLight intensity={1.4} />
      <directionalLight
        position={[-3, 10, 5]}
        intensity={2.1}
        color="#FFF0CA"
      />
      <directionalLight position={[8, 3, -5]} intensity={1} color="#6CB8BB" />
      <group rotation={[0, rotation, 0]} scale={zoom}>
        <Terrain world={world} />
        {visible.map((p) => {
          const [x, z] = project(p.city.lon, p.city.lat);
          const selectedCity = p.city.id === selected;
          return (
            <group
              key={p.city.id}
              position={[x, surfaceHeight(p.city.lon, p.city.lat) + 0.05, z]}
              onClick={(e) => {
                e.stopPropagation();
                onSelect(p.city.id);
              }}
            >
              <Landmark city={p.city} level={p.level} />
              <mesh position={[0, 0.15, 0]} visible={false}>
                <sphereGeometry args={[0.26, 8, 6]} />
                <meshBasicMaterial />
              </mesh>
              <mesh position={[0, 0.005, 0]} rotation={[-Math.PI / 2, 0, 0]}>
                <ringGeometry
                  args={[
                    selectedCity ? 0.26 : 0.14,
                    selectedCity ? 0.3 : 0.17,
                    28,
                  ]}
                />
                <meshBasicMaterial
                  color={
                    selectedCity
                      ? gold
                      : p.visits > 0
                        ? p.city.accent
                        : "#79928B"
                  }
                  side={THREE.DoubleSide}
                />
              </mesh>
            </group>
          );
        })}
        {/* A non-identifying player token evolves with the global character level. */}
        <group position={[-4.6, 0.1, 3.6]}>
          <mesh position={[0, 0.22, 0]}>
            <coneGeometry args={[0.2, 0.5 + world.era * 0.1, 6]} />
            <meshStandardMaterial color={world.era > 1 ? gold : "#C1DDD0"} />
          </mesh>
          <mesh position={[0, 0.57 + world.era * 0.05, 0]}>
            <sphereGeometry args={[0.11, 12, 8]} />
            <meshStandardMaterial color={gold} />
          </mesh>
          {world.era > 0 && (
            <mesh position={[0, 0.76, 0]}>
              <torusGeometry args={[0.15, 0.02, 6, 20]} />
              <meshStandardMaterial color={gold} />
            </mesh>
          )}
        </group>
      </group>
    </>
  );
}
