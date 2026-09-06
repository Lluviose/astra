import { test } from "node:test";
import assert from "node:assert/strict";
import {
  emptyData,
  upsertEntry,
  upsertPerson,
  removePerson,
  type Data,
  type Entry,
} from "../src/domain/model.ts";
import {
  buildCampaign,
  invest,
  validateRules,
  levelCost,
} from "../src/game/engine.ts";
import { cities, resolveCity, adjacent } from "../src/game/geography.ts";
import { defaultRules } from "../src/game/types.ts";
function fixture(): Data {
  return upsertPerson(emptyData(), {
    id: "p",
    name: "虚构代号",
    city: "上海",
    note: "",
    tags: [],
    photo: null,
    album: [],
    favorite: false,
    archived: false,
    scores: [0, 0, 0, 0, 0, 0],
    createdAt: "2026-09-01",
  });
}
const entry = (patch: Partial<Entry> = {}): Entry => ({
  id: "e",
  personId: "p",
  date: "2026-09-01",
  kind: "intimacy",
  title: "测试记录",
  note: "",
  city: "上海",
  protection: "unspecified",
  followUp: false,
  completed: false,
  ...patch,
});
test("empty campaign has no XP, territory or unlocked achievements", () => {
  const c = buildCampaign(emptyData());
  assert.equal(c.balance, 0);
  assert.equal(c.level, 1);
  assert.equal(c.cities.filter((c) => c.level).length, 0);
  assert.ok(c.achievements.every((a) => !a.unlocked));
});
test("private fields contribute separately with normalized duplicate tags counted once", () => {
  const d = upsertEntry(
    fixture(),
    entry({
      protection: "no",
      details: {
        venue: "旅店 A",
        positions: [" A ", "Ａ", "B"],
        playTags: ["C"],
        physiqueTags: ["D"],
        bodyRating: 8,
      },
    }),
  );
  const c = buildCampaign(d);
  assert.equal(c.totalXP, 20 + 30 + 40 + 10 + 10 + 10 + 5 + 5 + 16);
  assert.equal(
    c.rewards[0].lines.find((l) => l.key === "position")?.quantity,
    2,
  );
});
test("protected and unspecified never receive the unprotected bonus", () => {
  for (const protection of ["yes", "unspecified"] as const) {
    const c = buildCampaign(upsertEntry(fixture(), entry({ protection })));
    assert.equal(
      c.rewards[0].lines.some((l) => l.key === "unprotected"),
      false,
    );
  }
});
test("first city is canonicalized; first rewards attach chronologically regardless of array order", () => {
  let d = upsertEntry(
    fixture(),
    entry({ id: "later", date: "2026-09-03", city: "上海市" }),
  );
  d = upsertEntry(d, entry());
  const c = buildCampaign(d);
  assert.equal(c.totalXP, 110);
  assert.equal(c.rewards.find((r) => r.entryId === "later")?.points, 20);
  assert.equal(c.cities.find((p) => p.city.name === "上海")?.visits, 2);
});
test("date and missed records cannot farm private-field or first-time rewards", () => {
  for (const kind of ["date", "missed"] as const)
    assert.equal(
      buildCampaign(upsertEntry(fixture(), entry({ kind, protection: "no" })))
        .totalXP,
      0,
    );
});
test("editing and deleting a record replay rewards instead of accumulating XP", () => {
  const d = upsertEntry(fixture(), entry());
  const next = upsertEntry(d, entry({ protection: "no" }));
  assert.equal(buildCampaign(next).totalXP, 100);
  assert.equal(next.entries.length, 1);
  assert.equal(buildCampaign(removePerson(next, "p")).totalXP, 0);
});
test("build spends currency but preserves character XP; repeated action is rejected", () => {
  const d = upsertEntry(fixture(), entry());
  const built = invest(d, "310000", "action-1");
  const c = buildCampaign(built);
  assert.equal(c.balance, 10);
  assert.equal(c.totalXP, 90);
  assert.equal(c.spent, 80);
  assert.throws(() => invest(built, "310000", "action-1"));
  assert.throws(() => invest(built, "310000", "action-2"));
  assert.equal(d.game.investments.length, 0);
});
test("foreign and unknown cities retain record XP but do not create territories", () => {
  for (const city of ["巴黎", "不存在城市", ""]) {
    const c = buildCampaign(upsertEntry(fixture(), entry({ city })));
    assert.equal(c.totalXP, 50);
    assert.equal(c.cities.filter((p) => p.visits).length, 0);
  }
});
test("invalid tags, scores and rules fail before mutation", () => {
  assert.throws(() =>
    upsertEntry(
      fixture(),
      entry({
        details: {
          venue: "",
          positions: Array(13).fill("A"),
          playTags: [],
          physiqueTags: [],
          bodyRating: 0,
        },
      }),
    ),
  );
  for (const bodyRating of [NaN, -1, 11, 1.5])
    assert.throws(() =>
      upsertEntry(
        fixture(),
        entry({
          details: {
            venue: "",
            positions: [],
            playTags: [],
            physiqueTags: [],
            bodyRating,
          },
        }),
      ),
    );
  for (const entry of [-1, Infinity, 0.5, 1001])
    assert.throws(() => validateRules({ ...defaultRules, entry }));
});
test("each rule can be disabled and no stale rewards remain", () => {
  const d = upsertEntry(fixture(), entry({ protection: "no" }));
  d.game.rules = Object.fromEntries(
    Object.keys(defaultRules).map((k) => [k, 0]),
  ) as typeof defaultRules;
  assert.equal(buildCampaign(d).totalXP, 0);
});
test("deleting supporting records suspends construction without negative balance and restores on recovery", () => {
  const built = invest(upsertEntry(fixture(), entry()), "310000", "a");
  const reduced = { ...built, entries: [] };
  const c = buildCampaign(reduced);
  assert.equal(c.balance, 0);
  assert.equal(c.suspendedInvestments, 1);
  assert.equal(c.cities.find((p) => p.city.id === "310000")?.level, 0);
  assert.equal(
    buildCampaign({ ...reduced, entries: built.entries }).cities.find(
      (p) => p.city.id === "310000",
    )?.level,
    1,
  );
});
test("expansion requires a visited city or neighbor, and replay invalidates disconnected claims", () => {
  let d = upsertEntry(fixture(), entry());
  d.game.rules.entry = 1000;
  d = invest(d, "310000", "a");
  const neighbor = cities.find((c) => adjacent("310000", c.id))!;
  d = invest(d, neighbor.id, "b");
  assert.equal(
    buildCampaign(d).cities.find((p) => p.city.id === neighbor.id)?.level,
    1,
  );
  assert.throws(() => invest(d, "540100", "far"));
  const disconnected = buildCampaign({
    ...d,
    entries: [entry({ city: "北京" })],
  });
  assert.equal(disconnected.suspendedInvestments, 2);
});
test("unique city landmarks and symmetric graph cover the mainland catalog", () => {
  assert.ok(cities.length > 350);
  assert.equal(new Set(cities.map((c) => c.id)).size, cities.length);
  assert.ok(cities.every((c) => !/香港|澳门|台湾/.test(c.province)));
  assert.equal(resolveCity("上海市")?.landmark, "浦江灯塔");
  assert.equal(resolveCity("拉萨")?.biome, "plateau");
  assert.notEqual(resolveCity("成都")?.style, resolveCity("青岛")?.style);
  assert.equal(new Set(cities.map((c) => c.landmark)).size, cities.length);
  for (const city of cities.slice(0, 30))
    for (const other of cities.slice(0, 30))
      assert.equal(adjacent(city.id, other.id), adjacent(other.id, city.id));
});
test("four-stage construction unlocks a wonder and remains idempotent on reload", () => {
  let d = upsertEntry(fixture(), entry());
  d.game.rules.entry = 1000;
  for (let i = 1; i <= 4; i++) d = invest(d, "310000", `a${i}`);
  const c = buildCampaign(d);
  assert.equal(
    c.spent,
    [1, 2, 3, 4].reduce((n, l) => n + levelCost(l), 0),
  );
  assert.equal(c.achievements.find((a) => a.id === "wonder")?.unlocked, true);
  assert.throws(() => invest(d, "310000", "a5"));
  assert.deepEqual(buildCampaign(JSON.parse(JSON.stringify(d))), c);
});
test("coastal and plateau achievements derive from recorded cities", () => {
  let d = fixture();
  for (const [i, city] of ["上海", "青岛", "三亚", "拉萨"].entries())
    d = upsertEntry(d, entry({ id: `e${i}`, city }));
  const c = buildCampaign(d);
  assert.ok(c.achievements.find((a) => a.id === "coast")?.unlocked);
  assert.ok(c.achievements.find((a) => a.id === "plateau")?.unlocked);
});
