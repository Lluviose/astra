import { emptyData, type Data } from "../domain/model";
import { demoData } from "../domain/demo";

// Browser preview adapter. The iOS app uses database.ts and SQLite.
const preview = process.env.EXPO_PUBLIC_DEMO_MODE === "1";
const key = preview ? "astra-modern-demo-v1" : "astra-modern-v1";
export async function loadData(): Promise<Data> {
  const saved = localStorage.getItem(key);
  if (saved) return JSON.parse(saved);
  const initial = preview ? demoData() : emptyData();
  await saveData(initial);
  return initial;
}
export async function saveData(data: Data): Promise<void> {
  localStorage.setItem(key, JSON.stringify(data));
}
