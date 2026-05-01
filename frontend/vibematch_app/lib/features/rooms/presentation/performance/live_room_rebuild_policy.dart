class LiveRoomRebuildPolicy {
  const LiveRoomRebuildPolicy._();

  static const bool keepRoomControllersStable = true;
  static const bool lazyOpenHeavyPanels = true;
  static const bool isolateComposerTextUpdates = true;
  static const bool isolateGiftPanelUpdates = true;
  static const bool preserveRoomStateAcrossShellRebuilds = true;
}
