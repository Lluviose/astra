import React from "react";
import { Canvas } from "@react-three/fiber";
import AtlasScene, { type AtlasProps } from "./Scene";

export default function AtlasCanvas(props: AtlasProps) {
  return (
    <Canvas
      frameloop="demand"
      dpr={[1, 1.5]}
      camera={{ position: [0, 10, 12], fov: 45, near: 0.1, far: 80 }}
      onCreated={({ camera }) => camera.lookAt(0, 0, 0)}
    >
      <AtlasScene {...props} />
    </Canvas>
  );
}
