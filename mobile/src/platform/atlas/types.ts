import type { WorldView } from "../../game/types";
export type MapCommand = {
  kind: "in" | "out" | "reset" | "locate";
  revision: number;
};
export type AtlasProps = {
  world: WorldView;
  selected: string;
  onSelect: (id: string) => void;
  command: MapCommand;
  focusCity: boolean;
};
