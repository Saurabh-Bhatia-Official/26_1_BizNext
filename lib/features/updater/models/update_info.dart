class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String apkUrl;
  final String exeUrl;
  final DateTime releaseDate;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.apkUrl,
    required this.exeUrl,
    required this.releaseDate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      releaseNotes: json['releaseNotes'] as String,
      apkUrl: json['apkUrl'] as String,
      exeUrl: json['exeUrl'] as String,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'releaseNotes': releaseNotes,
      'apkUrl': apkUrl,
      'exeUrl': exeUrl,
      'releaseDate': releaseDate.toIso8601String(),
    };
  }
}
