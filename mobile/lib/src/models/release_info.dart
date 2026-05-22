class ReleaseInfo {
  const ReleaseInfo({
    required this.id,
    required this.platform,
    required this.versionCode,
    required this.versionName,
    required this.fileSizeBytes,
    required this.sha256,
    required this.createdAt,
  });

  final String id;
  final String platform;
  final int versionCode;
  final String versionName;
  final int fileSizeBytes;
  final String sha256;
  final String createdAt;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      id: json['id'] as String,
      platform: json['platform'] as String,
      versionCode: json['version_code'] as int,
      versionName: json['version_name'] as String,
      fileSizeBytes: json['file_size_bytes'] as int,
      sha256: json['sha256'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
