import * as SQLite from "expo-sqlite";
import { emptyData, type Data, type Person, type Entry } from "../domain/model";
import { demoData } from "../domain/demo";

const preview = process.env.EXPO_PUBLIC_DEMO_MODE === "1";
let opening: Promise<SQLite.SQLiteDatabase> | undefined;
function database() {
  return (opening ??= (async () => {
    const db = await SQLite.openDatabaseAsync(
      preview ? "astra-modern-demo.db" : "astra-modern.db",
    );
    await db.execAsync(`PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;
      CREATE TABLE IF NOT EXISTS people (id TEXT PRIMARY KEY NOT NULL, data TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS entries (id TEXT PRIMARY KEY NOT NULL, person_id TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE, date TEXT NOT NULL, data TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS entries_date ON entries(date);
      CREATE TABLE IF NOT EXISTS preferences (id INTEGER PRIMARY KEY CHECK(id=1), data TEXT NOT NULL);`);
    return db;
  })());
}
export async function loadData(): Promise<Data> {
  const db = await database();
  const prefs = await db.getFirstAsync<{ data: string }>(
    "SELECT data FROM preferences WHERE id=1",
  );
  if (!prefs) {
    const data = preview ? demoData() : emptyData();
    await saveData(data);
    return data;
  }
  const people = await db.getAllAsync<{ data: string }>(
    "SELECT data FROM people",
  );
  const entries = await db.getAllAsync<{ data: string }>(
    "SELECT data FROM entries ORDER BY date DESC",
  );
  return {
    ...JSON.parse(prefs.data),
    people: people.map((p) => JSON.parse(p.data) as Person),
    entries: entries.map((e) => JSON.parse(e.data) as Entry),
  };
}
export async function saveData(data: Data): Promise<void> {
  const db = await database();
  await db.withExclusiveTransactionAsync(async (txn) => {
    await txn.runAsync("DELETE FROM entries");
    await txn.runAsync("DELETE FROM people");
    for (const person of data.people)
      await txn.runAsync(
        "INSERT INTO people(id,data) VALUES (?,?)",
        person.id,
        JSON.stringify(person),
      );
    for (const entry of data.entries)
      await txn.runAsync(
        "INSERT INTO entries(id,person_id,date,data) VALUES (?,?,?,?)",
        entry.id,
        entry.personId,
        entry.date,
        JSON.stringify(entry),
      );
    await txn.runAsync(
      "INSERT OR REPLACE INTO preferences(id,data) VALUES (1,?)",
      JSON.stringify({ settings: data.settings, demo: data.demo }),
    );
  });
}
