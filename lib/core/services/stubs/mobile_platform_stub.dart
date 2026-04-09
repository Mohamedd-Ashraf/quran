// Stub implementations of dart:io types for web compilation.
// None of these are ever called at runtime on web.

class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<File> delete({bool recursive = false}) async => this;
  Future<File> writeAsBytes(List<int> bytes,
      {int mode = 0, bool flush = false}) async => this;
  Future<int> length() async => 0;
}

// ignore: camel_case_types
class Directory {
  final String path;
  Directory(this.path);
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static String get version => '';
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => '';
  static Map<String, String> get environment => {};
  static List<String> get executableArguments => [];
  static String get executable => '';
  static String get resolvedExecutable => '';
  static Uri get script => Uri.base;
  static String? get localeName => null;
  static int get numberOfProcessors => 1;
  static String get localHostname => '';
  static String get pathSeparator => '/';
  static String get packageConfig => '';
}
