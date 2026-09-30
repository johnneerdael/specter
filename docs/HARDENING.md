# Preservation-first fork: safety contract

This fork prioritizes existing app data, cryptographic keys and recovery access. It is not installed or payment-validated on the user's phone merely because CI passes.

## Changes

- Mutating defaults are off across shell, scheduler and WebUI. Explicit stored preferences remain, but unsupported actions below stay refused even with an old opt-in.
- Backend discovery/status does not install/disable backends or delete legacy directories. Conflict resolution does not execute uninstallers or rename third-party scripts.
- First boot takes a write-once, backend-namespaced snapshot; it does not run the full action pipeline. A manifest records paths, format, original absence and snapshot limitations. Snapshots/configuration survive uninstall.
- Known JSON/TXT writes use a whole read–modify–write Specter lock, private sibling temporaries, metadata-preserving replacement and preimage comparison. These locks cannot coordinate an unrelated native editor; close native editing while using an explicitly enabled Specter editor. Concurrent drift is refused where observed; there remains an unavoidable external check-to-rename race.
- Unknown TEESimulator schemas are refused; profiles without apps and fields after `profiles` are preserved. Intermediate configuration loading is read-only and generated JSON is checked before commit.
- A valid existing boot digest is retained. A stale cache/random value is never used; an explicitly enabled fresh observation is required for an absent digest. Property values are cosmetic, not proof that the bootloader is locked or secure.
- Root actions wait for queued device settings; failed persistence blocks actions and surfaces an error. Local browser cache is not authoritative over phone defaults.
- UI target edits use unique private staging files and propagate backend refusal. Ordinary aggregate target actions merge rather than regenerate; regeneration is separately confirmed. Keybox paths are escaped before HTML rendering.
- Shared-storage diagnostic export is a bounded boolean-settings summary only; raw logs, logcat, URLs, key paths and arbitrary settings are not exported. An old sanitization argument cannot opt back into raw export.
- Owned non-persistent property changes record original existence/value and last Specter value. Uninstall restores only unchanged owned values, under a per-property lock; later-owner changes retain the journal for inspection. Persistent-store mutation is refused pending separate persistent/volatile validation.
- Revocation reporting distinguishes listed, checked-not-listed and unknown. A first-certificate status is informational, not complete private-key/chain validation or proof of integrity. Missing X.509 tooling leaves status unknown. Downloads require certificate-verified HTTPS with HTTPS-only redirects; unavailable curl fails closed.
- Scheduler locks are never stolen on loose process-name matching. Uninstall signals only a numeric PID with matching script argv and rechecked process start time. RKPD is not force-stopped. App-data clearing is explicit and command failure is propagated.
- Detached inotify watchers are disabled pending validated child-identity/lifetime cleanup. The scheduler is off by default; an explicit opt-in permits its polling loop only.
- Shell assertion failure fails CI; release builds run the same type/shell/test gates. Telegram notifications require explicit repository opt-in. Upstream module auto-update is disabled so it cannot silently replace this fork.

## Deliberately unsupported operations

The following are blocked, not advertised as fixed/validated: keybox download/install (complete XML/private-key/certificate-chain validation absent), multi-file automatic restore, HMA scope replacement, live OMK/INI edits, hot-install/hot-apply/adb module replacement, broad ROM/PIF property deletion, bulk app-data cleanup, vendor/Widevine key provisioning, automated denylist changes and automatic debugging/OEM-unlock changes. PIF fingerprint fetching is delegated to the single PIF's native tools.

Manual native restoration must match the backend and manifest, preserve all profiles and referenced keyboxes, and account for original absence. Never flatten a multi-profile backup into one target list. Legacy shared backup names are not proof of backend compatibility. Snapshot collection is not an atomic device-wide backup; inspect completeness and source stability before using it. If any referenced file was missing/unsupported, treat it as incomplete; automatic restoration remains disabled.

## Regression and validation scope

Run `npm ci`, `npm audit`, `npx tsc --noEmit`, `bash tests/run.sh`, `npm test` and `npm run build`. Linux CI also runs ShellCheck and artifact structure checks. Android shell mocks and offline fixture transforms do not test SELinux labels, filesystem watchers, TEE/HAL behavior or bank policies. Check the Actions run at the exact commit before installing its artifact. Retain the original phone backup independently.

See [supported-tool comparison and recommendations](COMPATIBILITY.md). Recommendations are evidence-labelled and must be revalidated after upgrades.
