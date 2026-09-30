import { exec, getDataDir, getModuleDir } from './bridge.js';
import { cfgFlush } from './cfg.js';
import { shellEscape } from './utils.js';

// One shell owns each private staging file until commit, including failure cleanup.
export async function writeTargetList(content: string): Promise<void> {
  await cfgFlush();
  const dir = getDataDir();
  const moduleDir = getModuleDir();
  if (!dir || !moduleDir) throw new Error('Device paths unavailable');
  const command = `umask 077; mkdir -p ${shellEscape(dir)} || exit 1; tmp=$(mktemp ${shellEscape(dir + '/.target.XXXXXX')}) || exit 1; trap 'rm -f "$tmp"' EXIT; printf '%s' ${shellEscape(content)} > "$tmp" || exit 1; sh ${shellEscape(moduleDir + '/features/target.sh')} --set "$tmp"`;
  const result = await exec(command);
  if (result.code !== 0) throw new Error(result.stderr || 'Failed to commit target list');
}

export async function writeBlacklist(content: string): Promise<void> {
  await cfgFlush();
  const dir = getDataDir();
  if (!dir) throw new Error('Device data directory unavailable');
  const destination = shellEscape(dir + '/blacklist.txt');
  const enabled = shellEscape(dir + '/blacklist_enabled');
  const command = `umask 077; mkdir -p ${shellEscape(dir)} || exit 1; tmp=$(mktemp ${shellEscape(dir + '/.blacklist.XXXXXX')}) || exit 1; trap 'rm -f "$tmp"' EXIT; [ ! -L ${destination} ] && [ ! -L ${enabled} ] && printf '%s' ${shellEscape(content)} > "$tmp" && mv "$tmp" ${destination} && touch ${enabled}`;
  const result = await exec(command);
  if (result.code !== 0) throw new Error(result.stderr || 'Failed to save blacklist');
}
