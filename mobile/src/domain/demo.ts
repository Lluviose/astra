import {
  emptyData,
  localDate,
  type Data,
  type Entry,
  type Person,
} from "./model.ts";

// Fictional fixture. Activated only by the preview build or an explicit Settings action.
export function demoData(now = new Date()): Data {
  const ago = (days: number) => {
    const date = new Date(now);
    date.setDate(date.getDate() - days);
    return localDate(date);
  };
  const people: Person[] = [
    {
      id: "lin",
      name: "林间",
      city: "杭州",
      note: "喜欢散步，也喜欢没有目的地的周末。\n记得她说，下次要一起去看海。",
      tags: ["摄影", "咖啡", "慢热"],
      photo: "demo:portrait",
      album: ["demo:portrait"],
      favorite: true,
      archived: false,
      scores: [9, 8, 9, 9, 8, 9],
      createdAt: ago(98),
    },
    {
      id: "summer",
      name: "夏末",
      city: "上海",
      note: "总能发现有意思的小店。",
      tags: ["音乐", "展览"],
      photo: null,
      album: [],
      favorite: true,
      archived: false,
      scores: [8, 8, 9, 8, 9, 8],
      createdAt: ago(75),
    },
    {
      id: "island",
      name: "小岛",
      city: "成都",
      note: "一起走过很长的一段夜路。",
      tags: ["旅行", "电影"],
      photo: null,
      album: [],
      favorite: false,
      archived: false,
      scores: [8, 9, 8, 9, 8, 8],
      createdAt: ago(120),
    },
    {
      id: "blue",
      name: "蓝",
      city: "北京",
      note: "想找时间再见一面。",
      tags: ["阅读"],
      photo: null,
      album: [],
      favorite: false,
      archived: false,
      scores: [8, 7, 9, 8, 7, 8],
      createdAt: ago(21),
    },
  ];
  const entries: Entry[] = Array.from({ length: 18 }, (_, i) => ({
    id: `demo-entry-${i}`,
    personId: people[i % 3].id,
    date: ago(i === 0 ? 1 : i * 6 + 2),
    kind: i % 4 === 2 ? "date" : "intimacy",
    title:
      i === 0
        ? "雨停之后，一起散步"
        : ["傍晚的风刚刚好", "周末，留给喜欢的事", "又见面了"][i % 3],
    note:
      i === 0
        ? "从咖啡店走到江边，聊了很多。普通的一天，也想好好记住。"
        : "值得留住的小小片刻。",
    city: ["上海", "成都", "拉萨", "青岛", "三亚", "杭州"][i % 6],
    details: {
      venue: "示例地点",
      positions: ["标签 A"],
      playTags: ["标签 B"],
      physiqueTags: ["个人偏好"],
      bodyRating: 8,
    },
    protection: "unspecified",
    followUp: i === 0,
    completed: false,
  }));
  const data = { ...emptyData(), people, entries, demo: true };
  data.game.investments = [
    { id: "demo-build-1", cityId: "310000", level: 1 },
    { id: "demo-build-2", cityId: "310000", level: 2 },
    { id: "demo-build-3", cityId: "510100", level: 1 },
    { id: "demo-build-4", cityId: "540100", level: 1 },
  ];
  return data;
}
