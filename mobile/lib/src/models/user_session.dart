class UserSession {
  const UserSession({
    required this.userId,
    required this.identifier,
    this.displayName,
    required this.sessionToken,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['user_id'] as String,
      identifier: json['identifier'] as String,
      displayName: json['display_name'] as String?,
      sessionToken: json['session_token'] as String,
    );
  }

  final String userId;
  final String identifier;
  final String? displayName;
  final String sessionToken;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'identifier': identifier,
      'display_name': displayName,
      'session_token': sessionToken,
    };
  }
}
