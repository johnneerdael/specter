# Specter — preservation-first fork

A safety-hardened fork of [dpejoh/Specter](https://github.com/dpejoh/specter). This fork preserves existing backend configuration, app data and recovery access. **It does not guarantee Strong Integrity, Google Wallet payments or banking access.**

[Compatibility, supported backend/PIF differences and explicit recommendations](docs/COMPATIBILITY.md) · [Hardening contract and unsupported operations](docs/HARDENING.md)

[OnePlus recovery checklist: what to keep, disable, add and do next](docs/PHONE-RECOVERY.md). Start there for the inspected phone; it currently has Integrity Box disabled, not an active standalone PIF.

## Safe starting point

1. Verify private backups and app-native recovery options before modifying the phone. Root backups cannot guarantee migration of bank sessions or hardware-bound keys.
2. Retain one existing attestation backend and one PIF. Specter does not automatically install, uninstall or disable them. Multiple enabled backends require inspection and explicit selection.
3. Install only an artifact from a successful fork Actions run at its exact commit, through the root manager. Reboot only after backup completion and explicit approval. Direct adb replacement and hot-apply are blocked.
4. First boot snapshots/inspects only; it does not download keyboxes, run targeting or alter patch levels. Mutating defaults are off. Existing explicit preferences survive, but unsupported actions stay blocked.
5. Use backend/PIF native tools for key material and fingerprint management. Refer to the compatibility matrix: fixture-tested support is not device/payment validation.

## Deliberate limitations

Keybox installation, automatic restoration, HMA replacement, full/bulk data cleanup, Widevine/vendor provisioning, broad property cleanup, live OMK/INI writes and automatic denylist/debugging changes are refused. This is intentional protection, not a claim these features were validated. JSON/TXT editors are opt-in, preserve supported structures and refuse unsupported input. Default ownership remains with existing modules.

Uninstall retains snapshots/configuration and unresolved rollback journals. It restores only property values still owned by Specter. No RKPD or keystore data is cleared; no simulator keys are regenerated. Changing a manager is not demonstrated to fix a hardware provisioning failure.

## Build and validation

```sh
npm ci
npm audit
npx tsc --noEmit
bash tests/run.sh
npm test
npm run build
```

Output: `Specter-v{version}-g{commit}.zip`. Packaging works on macOS and Linux. Build/release workflows enforce test failures; Telegram notifications are disabled unless `ENABLE_TELEGRAM_NOTIFICATIONS=true` is explicitly set. Upstream module auto-update is disabled to preserve fork hardening.

The shell tests use Android mocks and offline fixtures. CI does not establish SELinux/watcher compatibility, real attestation, application session preservation or payment eligibility. The exact phone configuration must be independently tested before a third-party combination is called device-validated.

## Credits and license

Original Specter/Yurikey by [dpejoh](https://github.com/dpejoh). Backend/PIF projects retain their own authorship and licenses: [Tricky Store](https://github.com/5ec1cff/TrickyStore), [JingMatrix TEESimulator](https://github.com/JingMatrix/TEESimulator), [TEESimulator-RS](https://github.com/Enginex0/TEESimulator-RS), [OhMyKeymint](https://github.com/qwq233/OhMyKeymint), [KOWX712 PIF](https://github.com/KOWX712/PlayIntegrityFix), [osm0sis PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork). See [LICENSE](LICENSE).

Use only lawful device-owned configuration/key material. Do not publish private keyboxes, app databases, tokens, backups or credential exports in issues or CI artifacts.
