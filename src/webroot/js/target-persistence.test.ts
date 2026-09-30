import { beforeEach, describe, expect, it, vi } from 'vitest';
import { exec } from './bridge.js';
import { cfgFlush } from './cfg.js';
import { writeTargetList, writeBlacklist } from './target-persistence.js';

vi.mock('./bridge.js', () => ({
  exec: vi.fn(),
  getModuleDir: () => '/module with spaces',
  getDataDir: () => '/private data',
}));
vi.mock('./cfg.js', () => ({ cfgFlush: vi.fn() }));

beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(cfgFlush).mockResolvedValue(undefined);
  vi.mocked(exec).mockResolvedValue({ code: 0, stdout: '', stderr: '' });
});

describe('target persistence', () => {
  it('flushes before a private, unique, quoted staging transaction without an encoder', async () => {
    await writeTargetList("app.one\napp.'two");
    expect(cfgFlush).toHaveBeenCalledBefore(vi.mocked(exec));
    expect(exec).toHaveBeenCalledTimes(1);
    const command = vi.mocked(exec).mock.calls[0]![0];
    expect(command).toContain('umask 077');
    expect(command).toContain('mktemp');
    expect(command).toContain('.target.XXXXXX');
    expect(command).toContain('trap');
    expect(command).toContain("'/module with spaces/features/target.sh'");
    expect(command).not.toContain('base64');
    expect(command).not.toContain('.target_staging');
  });
  it('refuses to stage anything after failed configuration persistence', async () => {
    vi.mocked(cfgFlush).mockRejectedValueOnce(new Error('unsaved config'));
    await expect(writeTargetList('app.one')).rejects.toThrow('unsaved config');
    expect(exec).not.toHaveBeenCalled();
  });
  it('propagates a refused target commit', async () => {
    vi.mocked(exec).mockResolvedValueOnce({ code: 1, stdout: '', stderr: 'backend refused' });
    await expect(writeTargetList('app.one')).rejects.toThrow('backend refused');
  });
  it('blacklist uses private atomic staging and reports shell failure', async () => {
    vi.mocked(exec).mockResolvedValueOnce({ code: 1, stdout: '', stderr: 'write failed' });
    await expect(writeBlacklist('app.one')).rejects.toThrow('write failed');
    const command = vi.mocked(exec).mock.calls[0]![0];
    expect(command).toContain('mktemp');
    expect(command).toContain('mv');
    expect(command).not.toContain('base64');
  });
});
