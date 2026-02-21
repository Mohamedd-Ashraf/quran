import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows / updates / cancels a persistent progress notification during
/// offline audio download.  Uses an ongoing (non-dismissable) notification
/// while the download is in progress so the user can always see it in the
/// system tray and tap back into the app.
class AudioDownloadNotificationService {
  static const int _notifId = 9921;
  static const String _channelId = 'audio_download_progress';
  static const String _channelName = 'Audio Download';
  static const String _channelDesc = 'Shows progress for offline Quran audio downloads.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _channelCreated = false;

  AudioDownloadNotificationService(this._plugin);

  Future<void> _ensureChannel() async {
    if (_channelCreated) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _channelCreated = true;
  }

  /// Show or update the ongoing download notification.
  ///
  /// [completed] and [total] are file counts.
  Future<void> showProgress({
    required int completed,
    required int total,
    required String reciterName,
    bool isArabicUi = false,
  }) async {
    await _ensureChannel();

    final pct = total > 0 ? (completed * 100 ~/ total) : 0;
    final title = isArabicUi ? 'تحميل الصوت القرآني' : 'Downloading Quran Audio';
    final body = isArabicUi
        ? '$reciterName — $pct% ($completed / $total ملف)'
        : '$reciterName — $pct% ($completed / $total files)';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: total,
      progress: completed,
      indeterminate: total == 0,
      onlyAlertOnce: true,
      enableVibration: false,
      playSound: false,
      icon: '@drawable/ic_notification',
    );

    await _plugin.show(
      _notifId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Show a one-shot "resumed" notification after app restart.
  Future<void> showResumeAvailable({
    required int remainingSurahs,
    required String reciterName,
    bool isArabicUi = false,
  }) async {
    await _ensureChannel();

    final title = isArabicUi ? 'تحميل غير مكتمل' : 'Incomplete Download';
    final body = isArabicUi
        ? '$reciterName — $remainingSurahs سورة متبقية، افتح التطبيق للاستكمال'
        : '$reciterName — $remainingSurahs surahs remaining, open app to resume';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      enableVibration: false,
      playSound: false,
      icon: '@drawable/ic_notification',
    );

    await _plugin.show(
      _notifId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Call when download finishes or is cancelled.
  Future<void> showCompleted({
    required String reciterName,
    required int totalFiles,
    bool isArabicUi = false,
  }) async {
    await _ensureChannel();

    final title = isArabicUi ? '✅ اكتمل التحميل' : '✅ Download Complete';
    final body = isArabicUi
        ? '$reciterName — $totalFiles ملف جاهز للاستماع بدون إنترنت'
        : '$reciterName — $totalFiles files ready for offline playback';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      icon: '@drawable/ic_notification',
    );

    await _plugin.show(
      _notifId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Remove the notification immediately.
  Future<void> cancel() async {
    await _plugin.cancel(_notifId);
  }
}
