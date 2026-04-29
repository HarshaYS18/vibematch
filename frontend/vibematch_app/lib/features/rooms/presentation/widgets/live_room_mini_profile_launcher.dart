import 'package:flutter/material.dart';

import '../../data/room_moderation_repository.dart';
import '../controllers/live_room_profile_navigator.dart';
import '../live_room_models.dart';
import 'live_room_mini_profile_sheet.dart';
import 'room_kickout_duration_sheet.dart';
import 'room_theme.dart';

class LiveRoomMiniProfileLauncher {
  const LiveRoomMiniProfileLauncher._();

  static void open({
    required BuildContext context,
    required SeatUser user,
    required int seatIndex,
    required SeatUser currentUser,
    required bool canModerate,
    required List<SeatUser> allRoomUsers,
    required RoomPrivacyMode privacyMode,
    required String roomName,
    String? roomId,
    required ValueChanged<SeatUser> onMentionTap,
    required ValueChanged<String> onSetAdminTap,
    ValueChanged<String>? onRemoveAdminTap,
    ValueChanged<SeatUser>? onReportTap,
    ValueChanged<RoomKickoutDuration>? onKickOutDurationSelected,
    required ValueChanged<int> onLeaveAndLock,
    required ValueChanged<String> onSelfMuteToggle,
    required ValueChanged<String> onAdminMuteToggle,
    required ValueChanged<String> onGiftTap,
  }) {
    final canShowKickOut = canModerate && user.id != currentUser.id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Stack(
        children: [
          LiveRoomMiniProfileSheet(
            user: user,
            currentUser: currentUser,
            canModerate: canModerate,
            onAvatarTap: () {
              Navigator.pop(context);
              LiveRoomProfileNavigator.openExistingPublicProfile(
                context: context,
                user: user,
                privacyMode: privacyMode,
                roomName: roomName,
              );
            },
            onVipTap: () => LiveRoomProfileNavigator.openVipCentrePage(
              context: context,
              user: user,
            ),
            onSendingLevelTap:
                () => LiveRoomProfileNavigator.openSendingExperiencePage(
                      context: context,
                      user: user,
                    ),
            onReceivingLevelTap:
                () => LiveRoomProfileNavigator.openReceivingExperiencePage(
                      context: context,
                      user: user,
                    ),
            onSentRankingTap: () => LiveRoomProfileNavigator.openFollowedPage(
              context: context,
              user: user,
              users: allRoomUsers,
            ),
            onReceivedRankingTap:
                () => LiveRoomProfileNavigator.openFollowersPage(
                      context: context,
                      user: user,
                      users: allRoomUsers,
                    ),
            onFamilyTap: () => LiveRoomProfileNavigator.openFamilyPage(
              context: context,
              user: user,
            ),
            onRelationshipTap: () => LiveRoomProfileNavigator.openLoveAndBondCentre(
              context: context,
              user: user,
            ),
            onMedalsTap: () => LiveRoomProfileNavigator.openMedalsPage(
              context: context,
              user: user,
            ),
            onMentionTap: () => onMentionTap(user),
            onSetAdminTap: () => onSetAdminTap(user.id),
            onRemoveAdminTap: () {
              if (onRemoveAdminTap != null) {
                onRemoveAdminTap(user.id);
              } else {
                Navigator.pop(context);
              }
            },
            onReportTap: () {
              if (onReportTap != null) {
                onReportTap(user);
              } else {
                _openReportSheet(context: context, user: user);
              }
            },
            onLeaveAndLock: () => onLeaveAndLock(seatIndex),
            onSelfMuteToggle: () => onSelfMuteToggle(user.id),
            onAdminMuteToggle: () => onAdminMuteToggle(user.id),
            onGiftTap: () => onGiftTap(user.id),
          ),
          if (canShowKickOut && onKickOutDurationSelected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: Center(
                child: _MiniProfileKickOutIconButton(
                  onTap: () => _openKickOutDurationSheet(
                    context: context,
                    user: user,
                    onDurationSelected: onKickOutDurationSelected,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static void _openKickOutDurationSheet({
    required BuildContext context,
    required SeatUser user,
    required ValueChanged<RoomKickoutDuration> onDurationSelected,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RoomKickoutDurationSheet(
          user: user,
          onDurationSelected: onDurationSelected,
        ),
      );
    });
  }

  static void _openReportSheet({
    required BuildContext context,
    required SeatUser user,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _MiniProfileReportSheet(user: user),
      );
    });
  }
}

class _MiniProfileKickOutIconButton extends StatelessWidget {
  const _MiniProfileKickOutIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: RoomColors.coral,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: RoomColors.coral.withValues(alpha: 0.30),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1.2),
            ),
            child: const Icon(
              Icons.person_remove_alt_1_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProfileReportSheet extends StatefulWidget {
  const _MiniProfileReportSheet({required this.user});

  final SeatUser user;

  @override
  State<_MiniProfileReportSheet> createState() => _MiniProfileReportSheetState();
}

class _MiniProfileReportSheetState extends State<_MiniProfileReportSheet> {
  final List<String> _reasons = const [
    'Harassment or bullying',
    'Hate or abusive speech',
    'Scam or fraud',
    'Sexual or inappropriate content',
    'Spam or fake profile',
    'Other safety issue',
  ];

  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.report_gmailerrorred_rounded,
                  color: RoomColors.coral,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report ${widget.user.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Select a reason. This will later create a safety report for CS/Monitor review.',
                      style: TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: _selectedReason == reason
                        ? RoomColors.coral.withValues(alpha: 0.10)
                        : RoomColors.pearl,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedReason == reason
                          ? RoomColors.coral.withValues(alpha: 0.35)
                          : RoomColors.softLine,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedReason == reason
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: _selectedReason == reason
                            ? RoomColors.coral
                            : const Color(0xFF9A8FA3),
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            color: RoomColors.plum,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason == null
                  ? null
                  : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: RoomColors.coral,
                foregroundColor: Colors.white,
                disabledBackgroundColor: RoomColors.softLine,
                disabledForegroundColor: const Color(0xFF9A8FA3),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Submit Report',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
