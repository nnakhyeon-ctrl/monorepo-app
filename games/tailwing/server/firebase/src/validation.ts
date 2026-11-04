import { ApiError } from './security.js';

export type Json = Record<string, unknown>;
export function object(value: unknown, keys: readonly string[]): Json {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some((k) => !keys.includes(k))) throw new ApiError(400, 'invalid_input');
  return value as Json;
}
export function integer(value: unknown, max = 10000000): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0 || value > max) throw new ApiError(400, 'invalid_input');
  return value;
}
export function operation(value: unknown): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{16,64}$/.test(value)) throw new ApiError(400, 'invalid_input');
  return value;
}
export interface StageRecord { stage: number; cleared: boolean; best: number; attempts: number }
export interface GuestProgress { schema: 1; records: StageRecord[] }
export function guestProgress(value: unknown): GuestProgress {
  const data = object(value, ['schema', 'records']);
  if (data.schema !== 1 || !Array.isArray(data.records) || data.records.length > 15) throw new ApiError(400, 'invalid_input');
  const seen = new Set<number>();
  const records = data.records.map((entry) => {
    const r = object(entry, ['stage', 'cleared', 'best', 'attempts']);
    const stage = integer(r.stage, 15);
    if (!stage || seen.has(stage) || typeof r.cleared !== 'boolean') throw new ApiError(400, 'invalid_input');
    seen.add(stage);
    return { stage, cleared: r.cleared, best: integer(r.best), attempts: integer(r.attempts, 1000000) };
  }).sort((a, b) => a.stage - b.stage);
  const cleared = new Set(records.filter((r) => r.cleared).map((r) => r.stage));
  for (const r of records) {
    for (let i = 1; i < r.stage; i++) if (!cleared.has(i)) throw new ApiError(400, 'invalid_progression');
  }
  return { schema: 1, records };
}
export function unlocked(records: StageRecord[]): number {
  let stage = 1;
  while (stage < 15 && records.some((r) => r.stage === stage && r.cleared)) stage++;
  return stage;
}
export interface Preferences {
  sensitivity: number; music: boolean; effects: boolean; vibration: boolean;
  reduceMotion: boolean; musicVolume: number; effectsVolume: number;
}
export const defaultPreferences: Preferences = { sensitivity: 1, music: true, effects: true,
  vibration: false, reduceMotion: false, musicVolume: .25, effectsVolume: .45 };
export function preferences(value: unknown): Preferences {
  const p = object(value, Object.keys(defaultPreferences));
  for (const key of ['music', 'effects', 'vibration', 'reduceMotion']) {
    if (typeof p[key] !== 'boolean') throw new ApiError(400, 'invalid_input');
  }
  for (const key of ['sensitivity', 'musicVolume', 'effectsVolume']) {
    const n = p[key];
    if (typeof n !== 'number' || !Number.isFinite(n) ||
      (key === 'sensitivity' ? ![.75, 1, 1.25].includes(n) : n < 0 || n > 1)) throw new ApiError(400, 'invalid_input');
  }
  return Object.fromEntries(Object.keys(defaultPreferences).map((key) => [key, p[key]])) as unknown as Preferences;
}
