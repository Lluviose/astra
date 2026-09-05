export const dimensions = ['外貌', '身材', '气质', '默契', '回味', '心动'] as const;
export type Scores = [number, number, number, number, number, number];
export type Person = {
  id: string; name: string; city: string; note: string; tags: string[];
  photo: string | null; album: string[]; favorite: boolean; archived: boolean;
  scores: Scores; createdAt: string;
};
export type Entry = {
  id: string; personId: string; date: string; kind: 'date' | 'intimacy' | 'missed';
  title: string; note: string; city: string; protection: 'yes' | 'no' | 'unspecified';
  followUp: boolean; completed: boolean;
};
export type Settings = { appLock: boolean; haptics: boolean; title: string; maskOnLaunch: boolean };
export type Data = { people: Person[]; entries: Entry[]; settings: Settings; demo: boolean };
export const kindLabels = { date: '约会', intimacy: '亲密', missed: '未发生' } as const;
export const emptyData = (): Data => ({ people: [], entries: [], settings: { appLock: false, haptics: true, title: '把心动，留给自己。', maskOnLaunch: false }, demo: false });
export const scoreAverage = (scores: Scores) => scores.reduce((sum, score) => sum + score, 0) / scores.length;
export const intimacyCount = (data: Data, id?: string) => data.entries.filter(e => e.kind === 'intimacy' && (!id || e.personId === id)).length;
export const collection = (data: Data) => data.people.filter(p => data.entries.some(e => e.personId === p.id && e.kind === 'intimacy'));
export const personEntries = (data: Data, id: string) => data.entries.filter(e => e.personId === id).sort((a,b) => b.date.localeCompare(a.date));
export function localDate(date = new Date()): string {
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
}
export function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const d = new Date(year, month-1, day, 12);
  return d.getFullYear() === year && d.getMonth() === month-1 && d.getDate() === day;
}
export function upsertPerson(data: Data, person: Person): Data {
  if (!person.name.trim()) throw new Error('请填写人物代号');
  if (person.scores.length !== 6 || person.scores.some(n => !Number.isFinite(n) || n < 0 || n > 10)) throw new Error('评分须在 0–10 之间');
  const clean = { ...person, name: person.name.trim(), city: person.city.trim() };
  return { ...data, people: [...data.people.filter(p => p.id !== clean.id), clean] };
}
export function upsertEntry(data: Data, entry: Entry): Data {
  if (!data.people.some(p => p.id === entry.personId)) throw new Error('请先选择人物');
  if (!validDate(entry.date)) throw new Error('请填写有效日期，例如 2026-09-05');
  if (!entry.title.trim()) throw new Error('给这次相处起个标题吧');
  return { ...data, entries: [...data.entries.filter(e => e.id !== entry.id), { ...entry, title: entry.title.trim(), city: entry.city.trim() }] };
}
export function removePerson(data: Data, id: string): Data {
  return { ...data, people: data.people.filter(p => p.id !== id), entries: data.entries.filter(e => e.personId !== id) };
}
export function filterEntries(data: Data, query = '', kind = 'all', personId = 'all', month = 'all'): Entry[] {
  const term = query.trim().toLocaleLowerCase();
  return [...data.entries].filter(e => (kind === 'all' || e.kind === kind)
    && (personId === 'all' || e.personId === personId)
    && (month === 'all' || e.date.startsWith(month))
    && (!term || [e.title,e.note,e.city,data.people.find(p => p.id === e.personId)?.name || ''].join(' ').toLocaleLowerCase().includes(term)))
    .sort((a,b) => b.date.localeCompare(a.date));
}
export function summary(data: Data, now = new Date()) {
  const cities = [...new Set(data.entries.map(e => e.city).filter(Boolean))];
  const months = Array.from({ length: 6 }, (_, i) => {
    const date = new Date(now.getFullYear(), now.getMonth()-5+i, 1, 12);
    const key = localDate(date).slice(0,7);
    return { key, label: `${date.getMonth()+1}月`, count: data.entries.filter(e => e.date.startsWith(key)).length };
  });
  return { cities, months, collectionCount: collection(data).length, intimateCount: intimacyCount(data), average: data.people.length ? data.people.reduce((n,p) => n+scoreAverage(p.scores),0)/data.people.length : 0 };
}
