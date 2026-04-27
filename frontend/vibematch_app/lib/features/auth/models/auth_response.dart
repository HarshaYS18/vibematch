class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int userId;
  final int publicUserId;
  final List<String> roles;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userId,
    required this.publicUserId,
    required this.roles,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      userId: json['user_id'] as int,
      publicUserId: json['public_user_id'] as int,
      roles: List<String>.from(json['roles'] as List),
    );
  }
}