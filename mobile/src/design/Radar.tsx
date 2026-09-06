import React from "react";
import Svg, { Polygon, Line, Text as SvgText, Circle } from "react-native-svg";
import { dimensions, type Scores } from "../domain/model";
import { c } from "./ui";

export default function Radar({ scores }: { scores: Scores }) {
  const point = (i: number, r: number) => { const a = i * Math.PI / 3 - Math.PI / 2; return [120 + Math.cos(a) * r, 111 + Math.sin(a) * r]; };
  const polygon = (scale: number) => dimensions.map((_, i) => point(i, 69 * scale).join(",")).join(" ");
  return <Svg width="100%" height={225} viewBox="0 0 240 225" accessible={false}>
    {[1, 0.66, 0.33].map(scale => <Polygon key={scale} points={polygon(scale)} fill={scale === 1 ? "#F3F5F1" : "none"} stroke="#DCE2DA" strokeWidth="1" />)}
    {dimensions.map((label, i) => { const p = point(i, 69), l = point(i, 93); return <React.Fragment key={label}><Line x1={120} y1={111} x2={p[0]} y2={p[1]} stroke="#E0E5DC" /><SvgText x={l[0]} y={l[1] + 4} fontSize="11" fill={c.muted} textAnchor="middle">{label}</SvgText></React.Fragment>; })}
    <Polygon points={scores.map((n, i) => point(i, n / 10 * 69).join(",")).join(" ")} fill="rgba(49,94,245,0.10)" stroke={c.blue} strokeWidth="1.5" />
    {scores.map((n, i) => { const p = point(i, n / 10 * 69); return <Circle key={i} cx={p[0]} cy={p[1]} r="2.5" fill={c.blue} />; })}
  </Svg>;
}
