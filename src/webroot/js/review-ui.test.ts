import { beforeEach, describe, expect, it, vi } from 'vitest';
import { exec } from './bridge.js';
import { cfgGet } from './cfg.js';
import { openSubPage } from './subpage.js';
import { openCustomKeyboxDialog } from './keybox-ui.js';
import { openRegenerateDialog } from './target-apps-dialogs.js';
import { showToast } from './toast.js';
import type { SubPageConfig, SubPageCustomItem } from './subpage.js';

vi.mock('./bridge.js', () => ({ exec: vi.fn(), getModuleDir: () => '/module' }));
vi.mock('./cfg.js', () => ({ cfgGet: vi.fn(), cfgSet: vi.fn() }));
vi.mock('./subpage.js', () => ({ openSubPage: vi.fn() }));
vi.mock('./toast.js', () => ({ showToast: vi.fn() }));
vi.mock('./i18n.js', () => ({ getTranslation: () => '' }));
vi.mock('./terminal.js', () => ({ appendToOutput: vi.fn() }));
vi.mock('./file-browser.js', () => ({ openFileBrowser: vi.fn() }));
vi.mock('./device.js', () => ({ refreshKeyboxStatus: vi.fn() }));
vi.mock('./actions.js', () => ({ runAction: vi.fn() }));

beforeEach(() => {
  vi.clearAllMocks();
  document.body.innerHTML = '';
  vi.mocked(exec).mockResolvedValue({ code: 0, stdout: '', stderr: '' });
});

describe('review UI regressions', () => {
  it('a crafted persisted keybox path cannot inject markup or input attributes', async () => {
    const path = '/private/\"><img src=x onerror=alert(1)>.xml';
    vi.mocked(cfgGet).mockResolvedValue(path);
    await openCustomKeyboxDialog();
    const config = vi.mocked(openSubPage).mock.calls[0]![0] as SubPageConfig;
    const items = config.groups.flatMap(g => g.items).filter(i => i.type === 'custom') as SubPageCustomItem[];
    const host = document.createElement('div');
    for (const item of items) {
      const container = document.createElement('div');
      item.render(container, () => true);
      host.append(container);
    }
    expect(host.querySelector('img')).toBeNull();
    expect(host.querySelector('[onerror]')).toBeNull();
    expect((host.querySelector('#kb-url-input') as HTMLInputElement).value).toBe(path);
  });
  it('a refused regeneration never shows success or refreshes apps', async () => {
    if (!customElements.get('md-dialog')) {
      customElements.define('md-dialog', class extends HTMLElement {
        show() {}
        close() { this.dispatchEvent(new Event('close')); }
      });
    }
    vi.mocked(exec).mockResolvedValueOnce({ code: 1, stdout: '', stderr: 'refused' });
    const refreshApps = vi.fn().mockResolvedValue(undefined);
    openRegenerateDialog({
      apps: [], getDefaultMode: () => 'bare', setDefaultMode: vi.fn(), applyFilters: vi.fn(),
      refreshApps, loading: document.createElement('div'), list: document.createElement('div'),
    });
    (document.querySelector('#ta-regenerate-confirm') as HTMLElement).click();
    await vi.waitFor(() => expect(showToast).toHaveBeenCalled());
    expect(refreshApps).not.toHaveBeenCalled();
    expect(vi.mocked(showToast).mock.calls.every(([, options]) => options?.type !== 'success')).toBe(true);
  });
});
