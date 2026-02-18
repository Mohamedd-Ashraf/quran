import 'package:equatable/equatable.dart';

/// Model representing app update information
class AppUpdateInfo extends Equatable {
  /// Latest version available
  final String latestVersion;

  /// Current version of the app
  final String currentVersion;

  /// Minimum required version (if user's version is below this, update is mandatory)
  final String? minimumVersion;

  /// Whether this update is mandatory
  final bool isMandatory;

  /// URL to download the update (Play Store, App Store, or direct download)
  final String? downloadUrl;

  /// Changelog or update message (supports Arabic and English)
  final Map<String, String>? changelogByLanguage;

  /// Release date
  final DateTime? releaseDate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    this.minimumVersion,
    required this.isMandatory,
    this.downloadUrl,
    this.changelogByLanguage,
    this.releaseDate,
  });

  /// Check if an update is available
  bool get hasUpdate {
    return _compareVersions(currentVersion, latestVersion) < 0;
  }

  /// Check if the current version is below minimum required
  bool get isBelowMinimum {
    if (minimumVersion == null) return false;
    return _compareVersions(currentVersion, minimumVersion!) < 0;
  }

  /// Compare two version strings (e.g., "1.2.3")
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    final maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }

    return 0;
  }

  /// Get changelog for specific language, with fallback
  String getChangelog(String languageCode) {
    if (changelogByLanguage == null) return '';
    
    // Try exact match
    if (changelogByLanguage!.containsKey(languageCode)) {
      return changelogByLanguage![languageCode]!;
    }

    // Try language prefix (e.g., 'ar' for 'ar_SA')
    final prefix = languageCode.split('_').first;
    if (changelogByLanguage!.containsKey(prefix)) {
      return changelogByLanguage![prefix]!;
    }

    // Fallback to English or first available
    if (changelogByLanguage!.containsKey('en')) {
      return changelogByLanguage!['en']!;
    }

    return changelogByLanguage!.values.first;
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String currentVersion) {
    return AppUpdateInfo(
      latestVersion: json['latestVersion'] as String,
      currentVersion: currentVersion,
      minimumVersion: json['minimumVersion'] as String?,
      isMandatory: json['isMandatory'] as bool? ?? false,
      downloadUrl: json['downloadUrl'] as String?,
      changelogByLanguage: json['changelog'] != null
          ? Map<String, String>.from(json['changelog'] as Map)
          : null,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latestVersion': latestVersion,
      'currentVersion': currentVersion,
      'minimumVersion': minimumVersion,
      'isMandatory': isMandatory,
      'downloadUrl': downloadUrl,
      'changelog': changelogByLanguage,
      'releaseDate': releaseDate?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        latestVersion,
        currentVersion,
        minimumVersion,
        isMandatory,
        downloadUrl,
        changelogByLanguage,
        releaseDate,
      ];
}
