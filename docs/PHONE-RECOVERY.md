# Your OnePlus: recovery without resetting the phone

Checked 30 September 2026. **Start with Step 1, then report the result. Do not run all the steps in one sitting.** Each checkpoint decides whether the next change is needed.

Goal: recover ordinary app access and investigate Wallet while preserving apps, sessions and keys. Specter is a manager, not an attestation engine. Installing it alone will not restore payments. No combination below has yet passed a payment test on this phone. Google documents rooted phones and unlocked bootloaders as unsupported for Wallet; this is an experimental recovery path, not a promise of eligibility. [Wallet requirements](https://support.google.com/wallet/answer/12200245?hl=en).

## What to keep, disable, remove or add

| Item on your phone | What you should do now |
|---|---|
| Zygisk Next 1.5.0 | **Keep enabled.** You already have the Zygisk runtime you need. |
| Magisk built-in Zygisk / Enforce DenyList | **Keep both off**, as currently configured. Do not add another Zygisk runtime. |
| JingMatrix TEESimulator v4.0 (`teesim`) | **Keep enabled.** Leave profiles, key stores, keybox and RKPD toggle unchanged. |
| Integrity Box v43 (`playintegrityfix`) | **Keep disabled. Do not press Remove.** Its uninstaller can delete shared backend/Specter data. |
| HMA-OSS and Vector | Leave unchanged for the initial test. They are **not requirements for Specter**. HMA has a separate optional test below. |
| Frosty | Keep its Google service-freezing/payment/cloud/telemetry options off. Current inspected preferences are off; that does not undo past component overrides. The writer of those overrides is unknown. |
| Morphe/root-installed app modules, audio, hosts and other unrelated modules | Leave alone. Bulk removal could make more app APKs unavailable. |
| NoHello, TSupport, TreatWheel, Sensitive Props, Yurikey, BRENE | These old module IDs are **not currently installed**. There is nothing to remove for them. |
| Specter | Optional **later**, after the initial checks. Use only the validated fork ZIP in Step 3. |
| Standalone PIF, Tricky Store, TEESimulator-RS, another integrity/keybox manager | **Add nothing now.** PIF has a separate assisted checkpoint in Step 4; no backend swap is presently recommended. |

**Remove now: nothing. Add now: nothing.** Your verified backups are retained, but a live root backup is not proof that bank sessions or hardware-bound keys can be restored to another phone. Do not reset, relock the bootloader, clear banking/Wallet/Play services data, clear RKPD/keystore, or download shared attestation private keys.

## Step 1 — Test the two disabled DroidGuard components

Read-only inspection found both DroidGuard services explicitly disabled for user 0. That may contribute to the failed integrity checks; it is not a proven explanation. Restore **only these two overrides** to Android's manifest-controlled defaults. Do not enable every Google service or use a blanket “unfreeze” command.

1. Keep the phone unlocked and connected by USB. In the Mac terminal run:

   ```sh
   adb devices
   adb shell dumpsys package com.google.android.gms
   ```

   Continue only with one connected device listed as `device`. Save the terminal output privately. Under **User 0 → disabledComponents**, confirm both `com.google.android.gms.droidguard.DroidGuardGmsService` and `com.google.android.gms.droidguard.DroidGuardPersistentService` are present. If not, stop: the phone state has changed and this test needs updating.

2. Run the first command. If it does not report `new state: default`, stop. Otherwise run the second and require the same result:

   ```sh
   adb shell "su -c 'pm default-state --user 0 com.google.android.gms/com.google.android.gms.droidguard.DroidGuardGmsService'"
   adb shell "su -c 'pm default-state --user 0 com.google.android.gms/com.google.android.gms.droidguard.DroidGuardPersistentService'"
   ```

   Approve a root prompt if shown. `default` means the app manifest governs the component; it does **not** guarantee it is running or that Wallet will pass. Android may restart Play services during the change. [Android component-state definition](https://developer.android.com/reference/android/content/pm/PackageManager#COMPONENT_ENABLED_STATE_DEFAULT).

3. Run the package dump again. Confirm both names are gone from **User 0 → disabledComponents** (they may still appear elsewhere in the dump):

   ```sh
   adb shell dumpsys package com.google.android.gms
   ```

4. **Do not reboot yet.** Open your existing Play Integrity API Checker, run a new check, and record BASIC / DEVICE / STRONG separately. Open Wallet and record its exact message. Check whether important banking apps are still visible and their existing sessions open; do not log out or reinstall them. A screenshot of the checker and Wallet error is sufficient; redact account details.

**Checkpoint: send those results before installing anything.** Stop on an unknown-component/permission error, app/session regression, or if either disabled override returns. A returning override requires finding its writer, not repeatedly forcing it back on.

Only if this test itself causes a new regression, these commands restore the two **previously recorded** disabled overrides. Do not use them merely because Wallet still fails:

```sh
adb shell "su -c 'pm disable --user 0 com.google.android.gms/com.google.android.gms.droidguard.DroidGuardGmsService'"
adb shell "su -c 'pm disable --user 0 com.google.android.gms/com.google.android.gms.droidguard.DroidGuardPersistentService'"
```

## Step 2 — If still failing, establish a clean boot baseline

After reviewing Step 1, confirm Integrity Box is still disabled in Magisk → Modules. Use the phone's normal **Restart** once. Unlock with your PIN after boot before testing. Do not install another module in the same step.

Integrity Box was disabled without a subsequent reboot; previously loaded hooks or properties may remain until boot. A reboot is a baseline check, not a guaranteed provisioning repair.

Repeat the Step 1 component-state, integrity, Wallet and banking checks. If apps or sessions regress, stop before further changes. If payments already work, stop changing the attestation stack; you do not need Specter to keep a working setup.

**Only if apps still disappear:** separately record HMA's configuration privately, then disable just **HMA-OSS Zygisk** in Magisk → Modules and restart once. Do not uninstall HMA or disable Vector/Morphe simultaneously. Recheck launcher search and Settings → Apps. If worse, re-enable that same module and restart. Root-detection behavior may change during this test. Missing APK files need separate repair; PIF/Specter cannot recreate them, and HMA has not been proven to cause the missing apps.

## Step 3 — Optional: install the validated Specter manager

Do this only after the baseline is stable and the checkpoint has been reviewed. Keep Zygisk Next and JingMatrix TEESimulator; leave Integrity Box disabled.

**Before installing or taking the first Specter reboot:** the assistant must recheck and privately preserve the existing Specter configuration (or record its absence), including legacy settings. Every mutating preference must be absent or `0`: property/boot spoofing, ROM/PIF properties, GMS stopping/clearing, targeting, patch/fingerprint/keybox changes, automation, scheduler, hot-install and boot-hash changes. They were absent at the latest inspection, but old explicit preferences can survive an installation. If any is enabled, stop for targeted, reviewed preparation; do not install and discover it after boot.

1. Use the actual module ZIP, not GitHub's download wrapper. The Actions download can contain a second ZIP with the same filename; the outer ZIP is **not a Magisk module**. Extract it once. A module must contain `module.prop` at its top level, not just another ZIP. The verified inner archive has now been saved in your Mac's Downloads as **`Specter-MAGISK-v1.5.0-ge79ffbd.zip`**; the original wrapper is retained.

   On the Mac, verify that distinctly named ZIP and copy it to the phone:

   ```sh
   shasum -a 256 "$HOME/Downloads/Specter-MAGISK-v1.5.0-ge79ffbd.zip"
   unzip -p "$HOME/Downloads/Specter-MAGISK-v1.5.0-ge79ffbd.zip" module.prop
   adb push "$HOME/Downloads/Specter-MAGISK-v1.5.0-ge79ffbd.zip" /sdcard/Download/
   ```

   Expected SHA-256: `c009756f2c19a952c2a774ff5c625de67fb25c2033fce8ff16e124099bb88b34`. The second command must print `id=specter` and `version=v1.5.0-ge79ffbd`. If the hash differs or `module.prop` is missing, do not install. The wrapper has a different digest beginning `5b69ab37` and is not installable. This exact module commit passed [fork Actions validation](https://github.com/johnneerdael/specter/actions/runs/36743791402); that validates code and packaging, not payments or a successful phone install.

2. Open **Magisk → Modules → Install from storage**. Select **`Specter-MAGISK-v1.5.0-ge79ffbd.zip`**, not the earlier same-named wrapper or an upstream release. Read the result; on an error, stop without rebooting. After a successful install, restart once and unlock with your PIN. Do not replace module files over ADB or hot-apply.

3. Open the already installed **KsuWebUIStandalone → Specter**. No additional WebUI APK or Zygisk module is needed. Confirm Specter version `v1.5.0-ge79ffbd` and backend **JingMatrix TEESimulator**. If absent/ambiguous, stop.

4. Confirm **OFF**: Boot Spoofing, ROM Cleaner, debugging/ADB changes, Kill Play Store, Update Target, Set Security Patch, Set Fingerprint (PIF), Install Keybox, Auto-Targeting, Auto PIF, Auto Keybox, scheduler and hot-install where shown. Do not activate these controls as a “fix everything” step. Use read-only status inspection; keep existing modules as configuration owners. Defaults are off, but old explicit preferences can survive.

5. Repeat the same checkpoint checks. Leave TEESimulator's RKPD toggle and key/profile settings untouched. Neither installing Specter nor selecting another backend proves that the earlier Qualcomm RKP/CSR failure is repaired.

## Step 4 — Optional PIF replacement: assisted checkpoint, not a blind flash

Consider this only if the component/boot baseline is healthy but DEVICE integrity still fails. **Do not install it yet without a fresh preservation check.** There is currently no active standalone PIF; disabled Integrity Box occupies its module ID.

The inspected candidate is [KOWX712's official release](https://github.com/KOWX712/PlayIntegrityFix/releases/tag/v4.7-inject-s), specifically **`PlayIntegrityFix_v4.7-1-inject-s.zip`**, SHA-256 `10eec591735cafee437332871443a2fadf6632b1a58abb16fe2461d9df100ab1`. This is a source/package-reviewed candidate, not a phone/payment-validated recommendation. Its packaged fingerprint is not guaranteed to work.

Before installation, the assistant must privately preserve and verify the old Integrity Box directory, `/data/adb/pif.prop` and `.old` if present, and the exact GMS/Play Store injection files this installer replaces. The inspected old module `system.prop` is empty and its `pif.prop` and global files are absent, but this must be rechecked at installation time.

Why the checkpoint matters: the candidate imports old module settings, replaces selected injection files and can overwrite an existing `.old` file. It also changes boot/build properties, some persistent ROM flags and denylist configuration independently of its `spoofProps`/`spoofProvider` options. Preserve the exact pre-install values/configuration privately as part of the checkpoint. Disabling PIF and rebooting may **not** undo persistent changes; any restoration needs separate review. It is **not** a fingerprint-only, zero-global-change module. [Installer](https://raw.githubusercontent.com/KOWX712/PlayIntegrityFix/v4.7-inject-s/module/customize.sh), [service](https://raw.githubusercontent.com/KOWX712/PlayIntegrityFix/v4.7-inject-s/module/service.sh), [boot setup](https://raw.githubusercontent.com/KOWX712/PlayIntegrityFix/v4.7-inject-s/module/post-fs-data.sh).

After preservation and explicit review:

1. Install that exact PIF ZIP through **Magisk → Modules → Install from storage**, replacing the same ID. **Do not run Integrity Box's Remove/uninstaller first.** Do not install another PIF alongside it.
2. Before reboot, verify the staged replacement is PIF, contains no retained Integrity Box scripts, and retains `spoofProps=false`, `spoofProvider=false`, `spoofSignature=false`, `spoofVendingSdk=false`. Keep Specter's PIF/property automation off. Magisk installation can clear the old disabled flag **before reboot**; an install error is a stop condition, not permission to boot potentially re-enabled Integrity Box. [Magisk installer](https://github.com/topjohnwu/Magisk/blob/v31.0/scripts/util_functions.sh).
3. After successful staged verification, restart once, unlock, and repeat all checks. Use the existing WebUI host for the PIF's native interface; do not mix multiple fingerprint managers or assume Magisk's Action button only opens a UI. Provider/prop and Vending-SDK spoofing are not generic repair switches. [PIF maintainer guidance](https://github.com/KOWX712/PlayIntegrityFix/blob/inject_s/README.md).

If the new PIF causes regressions, disable **only the newly installed PIF** and restart, then review the preserved files before any restoration. Do not run uninstallers, restore live backend files or reactivate Integrity Box as an automatic rollback.

## When to stop

- **Wallet works:** stop modifying the stack. Confirm a payment yourself and check each bank separately before calling the combination payment-validated.
- **DEVICE passes but STRONG does not:** record the result and Wallet's actual message. Do not wipe keys or chase STRONG by stacking managers.
- **All verdicts still fail, services become disabled again, apps disappear, or key/session operations regress:** stop and inspect the specific failure. Do not swap to Tricky Store/TEESimulator-RS, clear RKPD, regenerate keys or reset as the next experiment.

Keep a physical card/another supported payment method available while testing. Stock restoration remains a separate, higher-impact decision after verifying app-native recovery options—not an instruction in this checklist.
