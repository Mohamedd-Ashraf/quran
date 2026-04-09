// Stubs for open_file and permission_handler on web.
// None of these are ever called at runtime on web.

class OpenFile {
  static Future<OpenResult> open(String filePath, {String? type}) async =>
      OpenResult(type: ResultType.noAppToOpen, message: 'Not supported on web');
}

class OpenResult {
  final ResultType type;
  final String message;
  OpenResult({required this.type, required this.message});
}

enum ResultType { done, fileNotFound, noAppToOpen, permissionDenied, error }

// ── permission_handler stubs ──────────────────────────────────────────────────

class PermissionStatus {
  final int _value;
  const PermissionStatus._(this._value);
  static const PermissionStatus denied = PermissionStatus._(0);
  static const PermissionStatus granted = PermissionStatus._(1);
  static const PermissionStatus restricted = PermissionStatus._(2);
  static const PermissionStatus limited = PermissionStatus._(3);
  static const PermissionStatus permanentlyDenied = PermissionStatus._(4);
  bool get isGranted => _value == 1;
  bool get isDenied => _value == 0;
}

class _PermissionWithStatus {
  const _PermissionWithStatus();
  Future<PermissionStatus> get status async => PermissionStatus.denied;
  Future<PermissionStatus> request() async => PermissionStatus.denied;
}

class Permission {
  static const _PermissionWithStatus requestInstallPackages =
      _PermissionWithStatus();
  static const _PermissionWithStatus storage = _PermissionWithStatus();
  static const _PermissionWithStatus manageExternalStorage =
      _PermissionWithStatus();
}
