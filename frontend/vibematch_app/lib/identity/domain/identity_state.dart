import '../../features/auth/models/current_user.dart';
import '../../features/auth/models/user_identity_snapshot.dart';

class IdentityAvatar {
  const IdentityAvatar({
    required this.url,
    required this.thumbnailUrl,
    required this.version,
  });

  final String? url;
  final String? thumbnailUrl;
  final int version;
}

class IdentityState {
  const IdentityState({
    required this.user,
    required this.snapshot,
    required this.avatar,
    required this.profileSetupCompleted,
    required this.profileVersion,
  });

  const IdentityState.empty()
      : user = null,
        snapshot = null,
        avatar = const IdentityAvatar(
          url: null,
          thumbnailUrl: null,
          version: 0,
        ),
        profileSetupCompleted = false,
        profileVersion = 0;

  final CurrentUser? user;
  final UserIdentitySnapshot? snapshot;
  final IdentityAvatar avatar;
  final bool profileSetupCompleted;
  final int profileVersion;

  factory IdentityState.fromUser(CurrentUser user) {
    final version = user.updatedAt.millisecondsSinceEpoch;
    return IdentityState(
      user: user,
      snapshot: UserIdentitySnapshot.fromJson(user.toJson()),
      avatar: IdentityAvatar(
        url: user.avatarUrl,
        thumbnailUrl: user.avatarUrl,
        version: version,
      ),
      profileSetupCompleted: user.profileSetupCompleted,
      profileVersion: version,
    );
  }
}
