import type { Data, Entry } from "../domain/model.ts";
import { validDate } from "../domain/model.ts";
import {
  adjacent,
  cities,
  cityById,
  normalizeCity,
  resolveCity,
} from "./geography.ts";
import {
  validateDetails,
  defaultRules,
  emptyGame,
  type Campaign,
  type IntimacyDetails,
  type Rules,
  type RuleKey,
  type RewardLine,
  type EntryReward,
} from "./types.ts";

export const cleanTags = (tags: string[]) => [
  ...new Set(tags.map((t) => t.trim().normalize("NFKC")).filter(Boolean)),
];
export const splitTags = (value: string) => cleanTags(value.split(/[,，、\n]/));
export function validateRules(rules: Rules): Rules {
  for (const key of Object.keys(defaultRules) as RuleKey[]) {
    if (!Number.isInteger(rules[key]) || rules[key] < 0 || rules[key] > 1000)
      throw new Error("每项积分须为 0–1000 的整数");
  }
  return { ...rules };
}
export const levelCost = (level: number) =>
  [0, 80, 140, 240, 400][level] ?? Infinity;
export const levelNames = ["未占领", "前哨", "聚落", "城池", "奇观"];

/** Deterministic replay: edits, deletes and rule changes never accumulate stale XP. */
export function buildCampaign(data: Data): Campaign {
  const game = data.game ?? emptyGame();
  const rules = validateRules(game.rules);
  const people = new Set(data.people.map((p) => p.id));
  const seenPeople = new Set<string>(),
    seenCities = new Set<string>(),
    seenVenues = new Set<string>(),
    seenIDs = new Set<string>();
  const progress = new Map(
    cities.map((city) => [city.id, { city, visits: 0, earned: 0, level: 0 }]),
  );
  const rewards: EntryReward[] = [];
  const entries = [...data.entries].sort(
    (a, b) => a.date.localeCompare(b.date) || a.id.localeCompare(b.id),
  );
  for (const entry of entries) {
    if (
      entry.kind !== "intimacy" ||
      !people.has(entry.personId) ||
      !validDate(entry.date) ||
      seenIDs.has(entry.id)
    )
      continue;
    seenIDs.add(entry.id);
    validateDetails(entry.details);
    const city = resolveCity(entry.city);
    const cityKey = city?.id ?? normalizeCity(entry.city);
    const lines: RewardLine[] = [];
    const add = (key: RuleKey, quantity: number) => {
      if (quantity > 0)
        lines.push({ key, quantity, points: quantity * rules[key] });
    };
    add("entry", 1);
    add("newPerson", seenPeople.has(entry.personId) ? 0 : 1);
    add("newCity", city && !seenCities.has(city.id) ? 1 : 0);
    const details = entry.details;
    if (details) {
      const venue = details.venue.trim().normalize("NFKC");
      const venueKey = `${cityKey}:${venue}`;
      add("newVenue", venue && !seenVenues.has(venueKey) ? 1 : 0);
      if (venue) seenVenues.add(venueKey);
      add("position", cleanTags(details.positions).length);
      add("play", cleanTags(details.playTags).length);
      add("physique", cleanTags(details.physiqueTags).length);
      add("bodyRating", details.bodyRating);
    }
    add("unprotected", entry.protection === "no" ? 1 : 0);
    seenPeople.add(entry.personId);
    if (city) seenCities.add(city.id);
    const points = lines.reduce((n, line) => n + line.points, 0);
    rewards.push({ entryId: entry.id, cityId: city?.id, points, lines });
    if (city) {
      const p = progress.get(city.id)!;
      p.visits += 1;
      p.earned += points;
    }
  }
  const totalXP = rewards.reduce((sum, r) => sum + r.points, 0);
  let balance = totalXP,
    spent = 0,
    suspendedInvestments = 0;
  const actionIDs = new Set<string>();
  for (const investment of game.investments) {
    const p = progress.get(investment.cityId);
    const duplicate = actionIDs.has(investment.id);
    actionIDs.add(investment.id);
    const reachable =
      p &&
      (p.visits > 0 ||
        [...progress.values()].some(
          (o) => o.level > 0 && adjacent(o.city.id, p.city.id),
        ));
    const cost = levelCost(investment.level);
    if (
      duplicate ||
      !p ||
      !reachable ||
      investment.level !== p.level + 1 ||
      cost > balance
    ) {
      suspendedInvestments += 1;
      continue;
    }
    p.level = investment.level;
    balance -= cost;
    spent += cost;
  }
  const level = Math.floor(Math.sqrt(totalXP / 100)) + 1;
  const era = Math.min(3, Math.floor((level - 1) / 3));
  const owned = [...progress.values()].filter((p) => p.level > 0);
  const achievements = [
    {
      id: "first",
      title: "星火初燃",
      detail: "保存第一条亲密记录",
      progress: rewards.length,
      target: 1,
    },
    {
      id: "cities",
      title: "山河行者",
      detail: "在 5 座大陆城市留下记录",
      progress: seenCities.size,
      target: 5,
    },
    {
      id: "coast",
      title: "听潮者",
      detail: "点亮 3 座海岸城市",
      progress: [...progress.values()].filter(
        (p) => p.visits > 0 && p.city.biome === "coast",
      ).length,
      target: 3,
    },
    {
      id: "plateau",
      title: "云上来客",
      detail: "点亮一座高原城市",
      progress: [...progress.values()].filter(
        (p) => p.visits > 0 && p.city.biome === "plateau",
      ).length,
      target: 1,
    },
    {
      id: "empire",
      title: "连城之境",
      detail: "攻占 5 座城市",
      progress: owned.length,
      target: 5,
    },
    {
      id: "wonder",
      title: "奇观筑造者",
      detail: "将一座城市升至奇观",
      progress: owned.filter((p) => p.level === 4).length,
      target: 1,
    },
    {
      id: "chronicle",
      title: "百页长卷",
      detail: "累计 100 次亲密记录",
      progress: rewards.length,
      target: 100,
    },
  ].map((a) => ({ ...a, unlocked: a.progress >= a.target }));
  return {
    cities: [...progress.values()],
    level,
    era,
    totalXP,
    balance,
    spent,
    rewards,
    achievements,
    suspendedInvestments,
    nextLevelXP: level * level * 100,
    rank: ["执灯旅人", "筑城者", "山河领主", "星图君主"][era],
  };
}
export function canReach(campaign: Campaign, cityId: string) {
  const city = campaign.cities.find((p) => p.city.id === cityId);
  return (
    !!city &&
    (city.visits > 0 ||
      campaign.cities.some((p) => p.level > 0 && adjacent(p.city.id, cityId)))
  );
}
export function invest(data: Data, cityId: string, actionId: string): Data {
  if (!cityById.has(cityId)) throw new Error("城市不在当前沙盘中");
  const game = data.game ?? emptyGame();
  if (game.investments.some((i) => i.id === actionId))
    throw new Error("请勿重复提交同一操作");
  const campaign = buildCampaign(data);
  const city = campaign.cities.find((p) => p.city.id === cityId)!;
  const level = city.level + 1;
  if (level > 4) throw new Error("已解锁城市奇观");
  if (!canReach(campaign, cityId))
    throw new Error("先在这座城市记录，或攻占相邻城市");
  if (campaign.balance < levelCost(level)) throw new Error("可用星尘不足");
  return {
    ...data,
    game: {
      ...game,
      investments: [...game.investments, { id: actionId, cityId, level }],
    },
  };
}
export function rewardForDraft(data: Data, entry: Entry) {
  return buildCampaign({
    ...data,
    entries: [...data.entries.filter((e) => e.id !== entry.id), entry],
  }).rewards.find((r) => r.entryId === entry.id);
}
