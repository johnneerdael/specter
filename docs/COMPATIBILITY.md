# Supported tools and evidence-based recommendations

Reviewed 2026-09-30. This is a preservation-first recommendation, **not a guarantee of Strong Integrity, Wallet payments or banking access**. Root-manager/backend/PIF release changes and server-side verdict changes require revalidation. Do not source shared or harvested third-party attestation private keys.

## Recommendation for this OnePlus

Follow the [phone-specific recovery checklist](PHONE-RECOVERY.md) first. Keep the existing JingMatrix TEESimulator v4.0 and Zygisk Next initially. On this phone, `playintegrityfix` is **disabled Integrity Box**, not an enabled standalone PIF: leave it disabled until a separately reviewed replacement. A working existing PIF on another device should normally be retained, not stacked with another. Use backend/PIF native interfaces. Leave Specter property handling, fingerprint fetching, automatic targeting, keybox updates, scheduler and GMS management off. Do not add HMA unless a specific app needs it. Preserve its existing export and restrict scope manually; do not scope Settings, the launcher or provisioning services just to hide unrelated apps.

This recommendation minimizes changes. Device diagnostics found TEE RKP certificate/CSR failure while StrongBox succeeded. They **did not establish that Integrity Box caused the HAL failure**, nor that changing the Specter manager or backend fixes it. No backend/PIF combination has been payment-validated on this phone. Do not clear RKPD/keystore data, delete simulator key stores or change cryptographic derivation parameters to test a hypothesis.

## Backend comparison

| Backend | Configuration and ownership | Fork support and validation | Recommendation |
|---|---|---|---|
| JingMatrix TEESimulator v4.0 | `teesim`; `/data/adb/teesim/config.json`; named profiles and per-profile keyboxes. Its daemon watches configuration. | Detection/read-only diagnostics; supported version-1 JSON edits have shell-fixture coverage. Unknown compound fields, escapes or malformed schemas are refused. Native Android reload/payment behavior of this fork is **not tested**. Existing phone inspection is separate evidence. | Preferred **preservation baseline** for this phone because it is already installed, not because it has proved payments work. Native UI owns profiles/keyboxes by default. [Upstream v4.0 documentation](https://github.com/JingMatrix/TEESimulator/blob/v4.0/README.md). |
| Tricky Store | `tricky_store`; `/data/adb/tricky_store/`; legacy `target.txt`/`security_patch.txt` or detected `config.ini`. | Legacy TXT target-section transforms are fixture-tested. INI live edits are refused until watcher/inode semantics are validated. No device test of a backend switch. | Alternative for a controlled, backed-up trial, **not a validated fix** for this Qualcomm RKP failure. [Upstream documentation](https://github.com/5ec1cff/TrickyStore). |
| TEESimulator-RS | Uses Tricky Store's module/config namespace and replaces it, rather than coexisting with it. Different certificate/key-generation internals from JingMatrix. | Tricky-style configuration adapter only; no independent integration or payment test. Upstream's Oplus auto-mode deliberately avoids global boot-property spoofing. | Candidate only. Never install alongside Tricky Store. Do not force Oplus boot-property spoofing. [Upstream documentation](https://github.com/Enginex0/TEESimulator-RS). |
| OhMyKeymint | `oh_my_keymint`; TOML configuration/injector files under its own keystore directory. | Detection/read-only inspection and offline TOML helper tests; live TOML edits are refused. Snapshot includes configuration/injector when available. | Native management only; do not regenerate/change trust values as a generic repair. [Upstream configuration](https://github.com/qwq233/OhMyKeymint/blob/master/docs/CONFIGURATION.md). |

Use **one** enabled attestation backend. Disabled, staged-only and pending-removal modules do not count as active. If multiple enabled backends exist, auto-detection refuses a writer; an explicit enabled selection does not disable the others or make coexistence safe.

## PIF variants: support is not equivalence

| Variant | Important differences | Validation and recommendation |
|---|---|---|
| KOWX712 `inject_s` / `Play Integrity Fix [INJECT]` | Current lightweight branch uses `.prop`, unlike preserved older JSON-based inject branches. Requires one Zygisk implementation. Upstream explicitly warns against third-party fingerprint fetching. | Offline Specter helper fixtures cover `/data/adb/pif.prop`; the installed module/version must still be checked. Prefer **native PIF management** alongside the existing backend. Upstream says provider/prop spoof options are for configurations without Tricky Store/TEESimulator; its Vending SDK spoof has documented sign-in/update/variant/crash problems. Do not enable those as generic repair steps. [Maintainer documentation](https://github.com/KOWX712/PlayIntegrityFix/blob/inject_s/README.md). |
| osm0sis Play Integrity Fork | Separate implementation/options and native fingerprint tooling; Specter's offline adapter chooses `custom.pif.prop`. It is not interchangeable with the INJECT branch merely because both occupy `playintegrityfix`. | Offline path/merge fixtures only; no device/payment validation. Retain an already-working installed version rather than switching on reputation alone. Use native tooling. [Maintainer repository](https://github.com/osm0sis/PlayIntegrityFork). |
| KOW preserved `main`/older `inject` branches | Legacy original/JSON variants differ from `inject_s`; a display-name match does not establish `.prop` compatibility. | **Not recommended as a Specter-managed combination**. Automatic PIF fingerprint updates are disabled in this fork for every variant, preventing schema guessing. [Branch comparison](https://github.com/KOWX712/PlayIntegrityFix/blob/inject_s/README.md). |

Do not stack PIF variants, multiple Zygisk implementations, Integrity Box/Yurikey/TSupport/property modules and Specter writers. Conflict detection does not automatically uninstall, rename or disable them. Default ownership remains with the existing module; feature-specific Specter ownership does not grant unrelated features. A manual whole-module priority switch intentionally affects all its listed features.

## Validation protocol before a recommendation becomes device-validated

1. Record exact root manager, enabled modules, release hashes and backend/PIF settings. Back up complete configuration, key stores, keyboxes and app data privately. Never publish these files in issue reports or CI.
2. Verify backup source/host hashes and archive parsing. Confirm important app-native recovery/export options separately; a live root copy is not proof of restorable bank sessions or hardware-bound keys.
3. Keep one backend and one PIF; change one setting/module at a time, retaining a rollback receipt. Do not uninstall an old manager if its uninstaller removes shared backend/Specter data.
4. After an explicitly approved reboot, check provisioning logs, ordinary app/key operations and application visibility before integrity verdicts. Record BASIC/DEVICE/STRONG separately; verdicts are not interchangeable with payment approval.
5. Confirm Wallet's own status and a real user-performed payment, plus each required bank's sign-in/session behavior. Only then label that exact combination **device/payment validated**. Stop on key loss, disappearing apps or provisioning regressions.

No evidence currently supports calling TEESimulator-RS, Tricky Store or an alternative PIF “best” for this device. The explicit recommendation is the minimally changed existing setup with native ownership. CI proves code/fixture behavior and packaging, **not third-party interoperability or banking eligibility**.
