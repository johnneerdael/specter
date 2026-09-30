# shellcheck shell=sh
# Root-manager staging must remain intact until a normal reboot installation.
specter_hot_install() {
  [ "$(cfg_get toggle_hot_install 0)" = 0 ] || ui_print "! Live hot-install is disabled; install through your root manager and reboot after backup."
  return 0
}
