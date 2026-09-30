#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

sp_restore_owned || log_w "UNINSTALL" "Some settings changed ownership or could not be restored; journals retained"

# Old legacy journals are intentionally retained for manual inspection.
# Never prefix-scan/delete properties belonging to ROMs or other modules.
# Keep original snapshots and configuration outside the module directory.
if [ -f "$SPECTER_DIR/scheduler.pid" ]; then
  specter_stop_pid_file "$SPECTER_DIR/scheduler.pid" "$MODDIR/lib/scheduler.sh" ||
    log_w "UNINSTALL" "Scheduler PID not verified; no signal sent"
fi
rm -f "$SPECTER_DIR/.first_boot_pending"
log_i "UNINSTALL" "Module removed; backups, configuration and unresolved ownership journals preserved"
exit 0
