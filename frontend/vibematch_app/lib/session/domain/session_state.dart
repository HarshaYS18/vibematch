enum SessionStatus {
  unknown,
  restoring,
  authenticated,
  signedOut,
}

class SessionState {
  const SessionState({
    required this.status,
    this.accessToken,
    this.deviceSessionId,
    this.signedInUserId,
    this.failureMessage,
  });

  const SessionState.unknown() : this(status: SessionStatus.unknown);

  final SessionStatus status;
  final String? accessToken;
  final String? deviceSessionId;
  final int? signedInUserId;
  final String? failureMessage;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated &&
      accessToken?.trim().isNotEmpty == true &&
      signedInUserId != null;
}
