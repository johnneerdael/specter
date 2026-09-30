import { exec as bridgeExec } from './bridge.js';
import { shellEscape } from './utils.js';
import { CONTROL_TOGGLES } from './constants.js';

let DATA_DIR: string | null = null;
const cache: Record<string, string | undefined | null> = {};
let pendingWrites: Promise<void> = Promise.resolve();
const writeErrors = new Map<string, Error>();
const revisions = new Map<string, number>();
const safeDefaults: Record<string, string> = Object.fromEntries(
  CONTROL_TOGGLES.map(t => [t.key, t.default ?? '1'])
);
Object.assign(safeDefaults, {
  toggle_boot_state_props: '0', toggle_bootmode_spoof: '0',
  toggle_action_gms_force_stop: '0', toggle_scheduler: '0',
  toggle_hot_install: '0', toggle_boot_hash: '0', toggle_pif_props: '0',
});
function validKey(key: string) {
  if (!/^[A-Za-z0-9_.-]+$/.test(key) || key === '.' || key === '..') throw new Error('Invalid config key');
}

/** Set the Specter data directory for config file access. */
export function setDataDir(path: string) { DATA_DIR = path; }

/** Pre-populate the config cache by reading all `.val` files from the config directory. */
export async function cfgInit() {
  cfgInvalidate();
  const preloaded = (window as any).__preloadedCfg;
  if (preloaded && typeof preloaded === 'object' && Object.keys(preloaded).length > 0) {
    const entries = Object.entries(preloaded);
    for (const [key, val] of entries) {
      if (typeof val === 'string') cache[key] = val;
    }
    return;
  }
  try {
    if (!DATA_DIR && typeof localStorage !== 'undefined') {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k && k.startsWith('sp_cfg_')) {
          cache[k.slice(7)] = localStorage.getItem(k);
        }
      }
    }
  } catch {}
  if (!DATA_DIR) return;
  const cfgDir = shellEscape(DATA_DIR + '/config/val');
  const cmd = `for f in ${cfgDir}/*.val; do [ -f "\$f" ] || continue; k="\${f##*/}"; k="\${k%.val}"; v="\$(cat "\$f")"; [ -n "\$v" ] || continue; printf 'CFG:%s\n' "\$k"; printf '%s\n' "\$v"; done`;
  const result = await bridgeExec(cmd);
  if (result.code !== 0) throw new Error('Device config read failed');
  const stdout = (result.stdout || '').trim();
  if (!stdout) return;
  const lines = stdout.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line || !line.startsWith('CFG:')) continue;
    const key = line.slice(4);
    const next = lines[i + 1];
    const value = next || '';
    cache[key] = value;
    i++;
  }
}

async function readConfig(key: string): Promise<string | null> {
  validKey(key);
  if (!DATA_DIR) return null;
  const result = await bridgeExec(
    `cat ${shellEscape(DATA_DIR + '/config/val/' + key + '.val')} 2>/dev/null || true`
  );
  return (result.stdout || '').trim() || null;
}

function writeConfig(key: string, val: string | undefined | null) {
  validKey(key);
  if (!DATA_DIR) return Promise.reject(new Error("Device data directory unavailable; configuration not saved"));
  const dir = shellEscape(DATA_DIR + '/config/val');
  const destination = shellEscape(DATA_DIR + '/config/val/' + key + '.val');
  const temp = shellEscape(DATA_DIR + '/config/val/.' + key + '.XXXXXX');
  const cmd = `umask 077; mkdir -p ${dir} && tmp=$(mktemp ${temp}) && printf '%s' ${shellEscape(val || '')} > "$tmp" && mv "$tmp" ${destination}`;
  return bridgeExec(cmd).then(result => {
    if (result.code !== 0) throw new Error(result.stderr || 'Device config write failed');
  });
}

/** Retrieve a config value by key. Checks the in-memory cache first, then reads from disk. Returns the stored value, `defaultValue`, or `null`. */
export async function cfgGet(key: string, defaultValue?: string): Promise<string | undefined | null> {
  validKey(key);
  if (key in cache) return cache[key];
  const val = await readConfig(key);
  cache[key] = val ?? safeDefaults[key] ?? defaultValue;
  return cache[key];
}

/** Set a config value both in cache and on disk. */
export function cfgSet(key: string, val: string | undefined | null) {
  validKey(key);
  const revision = (revisions.get(key) ?? 0) + 1;
  revisions.set(key, revision);
  cache[key] = val;
  try { localStorage.setItem('sp_cfg_' + key, val ?? ''); } catch {}
  pendingWrites = pendingWrites.then(() => writeConfig(key, val)).then(() => {
    writeErrors.delete(key);
  }).catch((reason: unknown) => {
    const error = reason instanceof Error ? reason : new Error(String(reason));
    writeErrors.set(key, error);
    if (revisions.get(key) === revision) {
      delete cache[key];
      try { localStorage.removeItem('sp_cfg_' + key); } catch {}
    }
    window.dispatchEvent(new CustomEvent('specter-config-error', { detail: error.message }));
  });
}

/** Actions await queued device writes; persistence failures block execution. */
export async function cfgFlush(): Promise<void> {
  let observed: Promise<void>;
  do { observed = pendingWrites; await observed; } while (observed !== pendingWrites);
  if (writeErrors.size) throw new Error([...writeErrors.values()].map(e => e.message).join('; '));
}

/** Remove one key (or all keys when called without argument) from the in-memory cache. */
export function cfgInvalidate(key?: string) {
  if (key) {
    delete cache[key];
  } else {
    for (const k of Object.keys(cache)) delete cache[k];
  }
}

/** Migrate legacy localStorage keys (`selectedLanguage`, `themeMode`, `themePreset`) to the new config system. Idempotent — only runs once. */
export async function migrateLocalStorage() {
  try {
    if (localStorage.getItem('_cfg_migrated')) return;
    const map: Record<string, string> = {
      selectedLanguage: 'lang',
      themeMode: 'theme',
      themePreset: 'theme_preset',
    };
    for (const [oldKey, newKey] of Object.entries(map)) {
      const val = localStorage.getItem(oldKey);
      if (val) {
        cache[newKey] = val;
        cfgSet(newKey, val);
      }
    }
    await cfgFlush();
    localStorage.removeItem('themeMode');
    localStorage.removeItem('themePreset');
    localStorage.removeItem('clockFormat');
    localStorage.setItem('_cfg_migrated', '1');
  } catch (e) {
    console.warn('Migration failed:', e);
  }
}
