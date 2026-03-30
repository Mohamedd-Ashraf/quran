import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a persistent progress notification while an app update APK is
/// downloading. Mirrors the pattern used by [AudioDownloadNotificationService].
class UpdateDownloadNotificationService {
  static const int _notifId       = 9930;
  static const String _channelId  = 'app_update_download';
  static const String _channelName = 'App Update Download';
  static const String _channelDesc =
      'Shows progress while downloading an app update.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _channelCreated = false;
  int _lastNotifPct = -1;

  UpdateDownloadNotificationService(this._plugin);

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

  /// Show or update the download progress notification.
  /// [progress] is 0.0 → 1.0.
  Future<void> showProgress({
    required double progress,
    required String version,
    bool isArabic = true,
  }) async {
    final pct = (progress * 100).round();
    // Only update the notification when the percentage actually changes.
    // Android silently drops rapid updates, so throttling to 1% prevents
    // the notification appearing "frozen" until the app is backgrounded.
    if (pct == _lastNotifPct) return;
    _lastNotifPct = pct;

    await _ensureChannel();
    final title   = isArabic ? 'تحميل تحديث التطبيق' : 'Downloading App Update';
    final body    = isArabic
        ? 'الإصدار $version — $pct٪'
        : 'Version $version — $pct%';

    await _plugin.show(
      _notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: pct,
          indeterminate: pct == 0,
          onlyAlertOnce: true,
          enableVibration: false,
          playSound: false,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  /// Show "download complete — tap to install" notification.
  Future<void> showComplete({
    required String version,
    bool isArabic = true,
  }) async {
    await _ensureChannel();

    final title = isArabic ? 'اكتمل تحميل التحديث' : 'Update Downloaded';
    final body  = isArabic
        ? 'الإصدار $version جاهز — أعد تشغيل التطبيق للتثبيت'
        : 'Version $version ready — restart the app to install';

    await _plugin.show(
      _notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
          showProgress: false,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  /// Show "download failed" notification.
  Future<void> showError({bool isArabic = true}) async {
    await _ensureChannel();

    await _plugin.show(
      _notifId,
      isArabic ? 'فشل تحميل التحديث' : 'Update Download Failed',
      isArabic
          ? 'تحقق من الاتصال وأعد المحاولة من الإعدادات'
          : 'Check your connection and retry from Settings',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  /// Cancel the notification (e.g. user dismissed or install started).
  Future<void> cancel() {
    _lastNotifPct = -1;
    return _plugin.cancel(_notifId);
  }
}
