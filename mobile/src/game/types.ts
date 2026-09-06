export type IntimacyDetails = {
  venue: string;
  positions: string[];
  playTags: string[];
  physiqueTags: string[];
  /** Subjective 0–10 snapshot for this entry; never inferred from a photo. */
  bodyRating: number;
};
export type RuleKey =
  | "entry"
  | "newPerson"
  | "newCity"
  | "newVenue"
  | "unprotected"
  | "position"
  | "play"
  | "physique"
  | "bodyRating";
export type Rules = Record<RuleKey, number>;
export const ruleLabels: Record<RuleKey, string> = {
  entry: "每次亲密记录",
  newPerson: "首次人物",
  newCity: "首次城市",
  newVenue: "首次地点",
  unprotected: "无套记录",
  position: "每种姿势",
  play: "每种玩法",
  physique: "每种身体特征",
  bodyRating: "主观身体评分 × 系数",
};
export const defaultRules: Rules = {
  entry: 20,
  newPerson: 30,
  newCity: 40,
  newVenue: 10,
  unprotected: 10,
  position: 5,
  play: 5,
  physique: 5,
  bodyRating: 2,
};
export type Investment = { id: string; cityId: string; level: number };
export type GameData = { version: 1; rules: Rules; investments: Investment[] };
export const emptyGame = (): GameData => ({
  version: 1,
  rules: { ...defaultRules },
  investments: [],
});
export type Biome = "coast" | "plateau" | "forest" | "desert" | "plain";
export type LandmarkStyle =
  "harbor" | "sail" | "garden" | "citadel" | "pagoda" | "gate" | "spire";
export type GameCity = {
  id: string;
  name: string;
  province: string;
  lat: number;
  lon: number;
  biome: Biome;
  landmark: string;
  style: LandmarkStyle;
  accent: string;
};
export type RewardLine = { key: RuleKey; quantity: number; points: number };
export type EntryReward = {
  entryId: string;
  cityId?: string;
  points: number;
  lines: RewardLine[];
};
export type CityProgress = {
  city: GameCity;
  visits: number;
  earned: number;
  level: number;
};
/** The renderer receives no person IDs, names, notes, ratings, or private tags. */
export type WorldView = {
  cities: CityProgress[];
  level: number;
  era: number;
  totalXP: number;
  balance: number;
};
export type Achievement = {
  id: string;
  title: string;
  detail: string;
  progress: number;
  target: number;
  unlocked: boolean;
};
export type Campaign = WorldView & {
  rewards: EntryReward[];
  spent: number;
  achievements: Achievement[];
  suspendedInvestments: number;
  nextLevelXP: number;
  rank: string;
};

export function validateDetails(details?: IntimacyDetails) {
  if (!details) return;
  if (
    !Number.isInteger(details.bodyRating) ||
    details.bodyRating < 0 ||
    details.bodyRating > 10
  )
    throw new Error("主观身体评分须为 0–10 的整数");
  if (details.venue.length > 80) throw new Error("地点代号最多 80 字");
  for (const tags of [
    details.positions,
    details.playTags,
    details.physiqueTags,
  ]) {
    if (tags.length > 12 || tags.some((t) => t.length > 24))
      throw new Error("每组最多 12 个标签，每个最多 24 字");
  }
}
