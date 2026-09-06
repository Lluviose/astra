import React from "react";
import { Text } from "react-native";
import { WithSkiaWeb } from "@shopify/react-native-skia/lib/module/web";
import type { AtlasProps } from "./types";

// CanvasKit must exist before evaluating the Skia renderer.
const getComponent = () => import("./SkiaAtlas");
const opts = { locateFile: (file: string) => `/${file}` };
export default function AtlasCanvas(props: AtlasProps) {
  return (
    <WithSkiaWeb
      getComponent={getComponent}
      opts={opts}
      componentProps={props}
      fallback={
        <Text style={{ color: "#CBD6C2", padding: 80 }}>正在展开山河…</Text>
      }
    />
  );
}
