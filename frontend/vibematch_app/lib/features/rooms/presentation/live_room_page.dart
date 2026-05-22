import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../social/widgets/friends_invite_sheet.dart';
import '../data/chat_moderation_api_service.dart';
import '../data/live_room_media_signaling_service.dart';
import '../data/live_room_member_request_service.dart';
import '../data/live_room_membership_service.dart';
import '../data/room_api_service.dart';
import '../data/room_moderation_repository.dart';
import '../data/room_music_controller.dart';
import 'controllers/live_room_gift_controller.dart';
import 'controllers/live_room_message_controller.dart';
import 'controllers/live_room_mention_text_controller.dart';
import 'controllers/live_room_moderation_controller.dart';
import 'controllers/live_room_navigation_controller.dart';
import 'controllers/live_room_presence_controller.dart';
import 'controllers/live_room_profile_navigator.dart';
import 'controllers/live_room_seat_controller.dart';
import 'controllers/live_room_sheet_controller.dart';
import 'controllers/live_room_settings_controller.dart';
import 'controllers/live_room_state_controller.dart';
import 'controllers/live_room_users_controller.dart';
import 'controllers/live_room_vibesync_controller.dart';
import 'live_room_models.dart';
import 'live_room_restore_state.dart';
import 'modules/cricket_room_mode_signal.dart';
import 'modules/cricket_stumps_flow_module.dart';
import 'modules/live_room_emoji_actions_module.dart';
import 'modules/live_room_games_actions_module.dart';
import 'modules/live_room_gift_actions_module.dart';
import 'modules/live_room_inbox_actions_module.dart';
import 'modules/live_room_leave_actions_module.dart';
import 'modules/live_room_message_actions_module.dart';
import 'modules/room_music_overlay.dart';
import 'widgets/cricket_room_backgrounds.dart';
import 'widgets/live_room_announcement_sheet.dart';
import 'widgets/live_room_body.dart';
import 'widgets/live_room_gift_overlay.dart';
import 'widgets/live_room_info_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_mini_profile_launcher.dart';
import 'widgets/live_room_minimized_bubble.dart';
import 'widgets/live_room_minimized_overlay_service.dart';
import 'widgets/live_room_privacy_sheet.dart';
import 'widgets/live_room_remote_audio_renderers.dart';
import 'widgets/live_room_seat_invite_notification.dart';
import 'widgets/live_room_seat_layout_picker_sheet.dart';
import 'widgets/live_room_settings_sheet_module.dart';
import 'widgets/live_room_users_sheet.dart';
import 'widgets/room_contribution_rankings_sheet.dart';
import 'widgets/room_level_sheet.dart';
import 'widgets/room_seats.dart';
import 'widgets/room_theme.dart';
import 'widgets/vibesync_room_module.dart';

part 'live_room_page_actions.dart';
part 'live_room_page_presence.dart';
part 'live_room_page_sheets.dart';
part 'live_room_page_support.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({
    super.key,
    this.roomName = 'Live Room',
    this.roomId = 'VM000000',
    this.language = 'Telugu',
    this.modeTitle = 'Open',
    this.onlineCount = 1,
    this.initialBackgroundTheme,
    this.restoreState,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final RoomBackgroundTheme? initialBackgroundTheme;
  final LiveRoomRestoreState? restoreState;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final LiveRoomMentionTextController _messageController;
  late final TextEditingController _announcementController;
  late final FocusNode _messageFocusNode;
  late final LiveRoomStateController _roomStateController;
  late final LiveRoomGiftController _giftController;
  late final LiveRoomSeatController _seatController;
  late final LiveRoomMessageController _roomMessageController;
  late final LiveRoomModerationController _moderationController;

  final LiveRoomUsersController _usersController =
      const LiveRoomUsersController();
  final LiveRoomSettingsController _settingsController =
      const LiveRoomSettingsController();
  final LiveRoomVibeSyncController _vibeSyncController =
      const LiveRoomVibeSyncController();
  final LiveRoomNavigationController _navigationController =
      const LiveRoomNavigationController();
  final ChatModerationApiService _chatModerationApi =
      const ChatModerationApiService();
  late final LiveRoomPresenceController _presenceController;

  _PendingSeatInvite? _pendingSeatInvite;
  Timer? _seatInviteAutoHideTimer;
  Timer? _hostSeatOneTimer;
  Timer? _hostSeatOneRetryTimer;
  VoidCallback? _seatInviteListener;
  VoidCallback? _roomMembershipListener;
  VoidCallback? _roomMemberRequestListener;

  SeatUser get _currentUser {
    return LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser ??
        _roomIdentityFallback;
  }