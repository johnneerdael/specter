import { describe, expect, it, beforeEach, vi } from 'vitest'
import { cfgGet, cfgSet, cfgFlush, cfgInvalidate, setDataDir, migrateLocalStorage } from './cfg.js'
import { exec } from './bridge.js'

vi.mock('./bridge.js', () => ({
  exec: vi.fn(() => Promise.resolve({ stdout: '', stderr: '', code: 0 })),
}))

beforeEach(async () => {
  await cfgFlush().catch(() => {});
  vi.clearAllMocks()
  setDataDir('/data/adb/specter')
  cfgInvalidate()
  localStorage.clear()
})

describe('cfg (caching layer)', () => {
  it('missing device directory cannot report successful persistence', async () => {
    setDataDir('');
    cfgSet('missing_dir_test', 'value');
    await expect(cfgFlush()).rejects.toThrow('directory unavailable');
    expect(exec).not.toHaveBeenCalled();
    setDataDir('/data/adb/specter');
    cfgSet('missing_dir_test', 'value');
    await cfgFlush();
  });
  it('flush waits for actual device persistence before an action', async () => {
    let finish!: (value: any) => void
    vi.mocked(exec).mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
    cfgSet('keybox_custom_value', '/safe/key.xml')
    let completed = false
    const waiting = cfgFlush().then(() => { completed = true })
    await new Promise(resolve => setTimeout(resolve, 0))
    expect(completed).toBe(false)
    finish({ stdout: '', stderr: '', code: 0 })
    await waiting
    expect(completed).toBe(true)
  })

  it('failed persistence refuses the action flush', async () => {
    vi.mocked(exec).mockResolvedValueOnce({ stdout: '', stderr: 'permission denied', code: 1 } as any)
    cfgSet('keybox_custom_value', '/safe/key.xml')
    await expect(cfgFlush()).rejects.toThrow()
    cfgSet('keybox_custom_value', '')
    await cfgFlush()
  })

  it('missing mutation switches are off even with an old enabled fallback', async () => {
    expect(await cfgGet('toggle_prop_handler', '1')).toBe('0')
    expect(await cfgGet('toggle_action_keybox', '1')).toBe('0')
  })
  it('cfgGet returns cached value after cfgSet', async () => {
    cfgSet('test_key', 'test_value')
    const val = await cfgGet('test_key')
    expect(val).toBe('test_value')
  })

  it('cfgSet overwrites existing value', async () => {
    cfgSet('test_key', 'first')
    cfgSet('test_key', 'second')
    const val = await cfgGet('test_key')
    expect(val).toBe('second')
  })

  it('cfgGet returns defaultValue when not cached', async () => {
    const val = await cfgGet('nonexistent', 'default')
    expect(val).toBe('default')
  })

  it('cfgGet returns undefined when key missing and no default', async () => {
    const val = await cfgGet('nonexistent')
    expect(val).toBeUndefined()
  })

  it('cfgInvalidate removes single key', async () => {
    cfgSet('temp', 'value')
    expect(await cfgGet('temp')).toBe('value')
    cfgInvalidate('temp')
    expect(await cfgGet('temp')).toBeUndefined()
  })

  it('cfgInvalidate with no args clears all cache', async () => {
    cfgSet('a', '1')
    cfgSet('b', '2')
    cfgInvalidate()
    expect(await cfgGet('a')).toBeUndefined()
    expect(await cfgGet('b')).toBeUndefined()
  })

  it('migrateLocalStorage migrates keys', async () => {
    localStorage.setItem('selectedLanguage', 'en')
    localStorage.setItem('themeMode', 'dark')
    await migrateLocalStorage()
    expect(await cfgGet('lang')).toBe('en')
    expect(await cfgGet('theme')).toBe('dark')
    expect(localStorage.getItem('_cfg_migrated')).toBe('1')
  })

  it('migrateLocalStorage only runs once', async () => {
    localStorage.setItem('selectedLanguage', 'en')
    await migrateLocalStorage()
    localStorage.setItem('selectedLanguage', 'fr')
    await migrateLocalStorage()
    expect(await cfgGet('lang')).toBe('en')
  })
})
