
// Keeping the original implementation below for future use
/*
class QiblahScreenOriginal extends StatefulWidget {
  const QiblahScreenOriginal({super.key});

  @override
  State<QiblahScreenOriginal> createState() => _QiblahScreenState();
}

class _QiblahScreenState extends State<QiblahScreenOriginal> {
  final LocationService _location = const LocationService();

  bool _loading = true;
  String? _error;
  double? _bearing;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final permission = await _location.ensurePermission();
    if (!mounted) return;

    if (permission != LocationPermissionState.granted) {
      setState(() {
        _loading = false;
        _error = _permissionError(permission);
      });
      return;
    }

    try {
      final pos = await _location.getPosition();
      final coords = Coordinates(pos.latitude, pos.longitude);
      final qibla = Qibla(coords);
      final bearing = qibla.direction;

      // Save location to local storage for future use
      await di.sl<SettingsService>().setLastKnownCoordinates(
        pos.latitude,
        pos.longitude,
      );

      // Cache prayer times for next 30 days (offline support)
      await di.sl<PrayerTimesCacheService>().cachePrayerTimes(
        pos.latitude,
        pos.longitude,
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _lat = pos.latitude;
        _lng = pos.longitude;
        _bearing = bearing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is TimeoutException
            ? 'Timed out getting GPS fix. Try again or move to an open area.'
            : e.toString();
      });
    }
  }

  String _permissionError(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.serviceDisabled:
        return 'Location services are disabled.';
      case LocationPermissionState.denied:
        return 'Location permission denied.';
      case LocationPermissionState.deniedForever:
        return 'Location permission permanently denied.';
      case LocationPermissionState.granted:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5C43),
        foregroundColor: Colors.white,
        title: Text(isArabicUi ? 'القبلة' : 'Qiblah'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D5E3A),
                Color(0xFF1E5C43),
                Color(0xFF2E7D32),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? _ErrorState(
                  isArabicUi: isArabicUi,
                  message: _arabicOrEnglish(
                    isArabicUi,
                    ar: 'تعذر الحصول على الموقع/القبلة: $_error',
                    en: 'Could not get location/Qiblah: $_error',
                  ),
                  onOpenSettings: () async {
                    await _location.openAppSettings();
                  },
                  onOpenLocation: () async {
                    await _location.openLocationSettings();
                  },
                )
              : _QiblahBody(
                  isArabicUi: isArabicUi,
                  bearing: _bearing ?? 0,
                  lat: _lat,
                  lng: _lng,
                ),
    );
  }

  String _arabicOrEnglish(bool isArabicUi, {required String ar, required String en}) {
    return isArabicUi ? ar : en;
  }
}

class _QiblahBody extends StatefulWidget {
  final bool isArabicUi;
  final double bearing;
  final double? lat;
  final double? lng;

  const _QiblahBody({
    required this.isArabicUi,
    required this.bearing,
    required this.lat,
    required this.lng,
  });

  @override
  State<_QiblahBody> createState() => _QiblahBodyState();
}

class _QiblahBodyState extends State<_QiblahBody> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle between Compass and Map (segmented control)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFDAA520), width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => setState(() => _showMap = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showMap ? Colors.transparent : const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore, color: _showMap ? const Color(0xFF2E7D32) : Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            widget.isArabicUi ? 'البوصلة' : 'Compass',
                            style: TextStyle(
                              color: _showMap ? const Color(0xFF2E7D32) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => setState(() => _showMap = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showMap ? const Color(0xFF2E7D32) : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, color: _showMap ? Colors.white : const Color(0xFF2E7D32)),
                          const SizedBox(width: 6),
                          Text(
                            widget.isArabicUi ? 'الخريطة' : 'Map',
                            style: TextStyle(
                              color: _showMap ? Colors.white : const Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.lat != null && widget.lng != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.isArabicUi
                  ? 'الموقع: ${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)}'
                  : 'Location: ${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: _showMap
              ? _QiblahMap(
                  bearing: widget.bearing,
                  userLat: widget.lat!,
                  userLng: widget.lng!,
                  isArabicUi: widget.isArabicUi,
                )
              : _QiblahCompass(
                  bearing: widget.bearing,
                  isArabicUi: widget.isArabicUi,
                ),
        ),
      ],
    );
  }
}

class _QiblahCompass extends StatefulWidget {
  final double bearing;
  final bool isArabicUi;

  const _QiblahCompass({required this.bearing, required this.isArabicUi});

  @override
  State<_QiblahCompass> createState() => _QiblahCompassState();
}

class _QiblahCompassState extends State<_QiblahCompass> {
  double? _heading;
  double? _accuracy;
  bool _aligned = false;
  bool _vibrated = false;
  StreamSubscription<CompassEvent>? _sub;
  int _compassDesign = 0; // 0: Classic, 1: Modern, 2: Minimalist
  
  // Sensor smoothing
  final List<double> _headingHistory = [];
  static const int _smoothingWindow = 5;

  static double _normalize(double deg) {
    var v = deg % 360;
    if (v < 0) v += 360;
    return v;
  }

  double _smoothHeading(double newHeading) {
    _headingHistory.add(newHeading);
    if (_headingHistory.length > _smoothingWindow) {
      _headingHistory.removeAt(0);
    }
    
    // Circular average for angles
    double sinSum = 0;
    double cosSum = 0;
    for (final heading in _headingHistory) {
      final rad = heading * (math.pi / 180);
      sinSum += math.sin(rad);
      cosSum += math.cos(rad);
    }
    final avgRad = math.atan2(sinSum / _headingHistory.length, cosSum / _headingHistory.length);
    var avgDeg = avgRad * (180 / math.pi);
    if (avgDeg < 0) avgDeg += 360;
    return avgDeg;
  }

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      if (event.heading != null) {
        final smoothed = _smoothHeading(event.heading!);
        setState(() {
          _heading = smoothed;
          _accuracy = event.accuracy;
        });
        _checkAlignment();
      }
    });
  }

  void _checkAlignment() {
    if (_heading == null) return;
    final target = _normalize(widget.bearing);
    final h = _normalize(_heading!);
    var diff = (target - h).abs();
    if (diff > 180) diff = 360 - diff;
    final aligned = diff <= 5.0;
    if (aligned && !_vibrated) {
      HapticFeedback.vibrate();
      _vibrated = true;
    }
    if (!aligned) _vibrated = false;
    if (mounted) setState(() => _aligned = aligned);
  }

  String _getCardinalDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    return 'NW';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading ?? 0.0;
    final qiblahAngle = widget.bearing; // Qiblah direction from north
    final rotationDeg = _normalize(widget.bearing - heading); // Angle difference
    final accuracyGood = (_accuracy ?? 999) <= 15;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1F19),
            Color(0xFF1A3A2E),
            Color(0xFF2E5C47),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned.fill(
            child: CustomPaint(
              painter: _IslamicPatternPainter(),
            ),
          ),
          // Mosque silhouette background (smaller, top only)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: _MosqueBackgroundPainter(),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Title with Islamic decoration
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFD4AF37).withValues(alpha: 0.2),
                          Color(0xFFFFD700).withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color(0xFFD4AF37).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place, color: Color(0xFFFFD700), size: 20),
                        SizedBox(width: 8),
                        Text(
                          widget.isArabicUi ? 'اتجاه القبلة' : 'Qiblah Direction',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Metrics row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InfoCard(
                        icon: Icons.explore,
                        label: widget.isArabicUi ? 'اتجاه' : 'Direction',
                        value: '${widget.bearing.toStringAsFixed(1)}°',
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(width: 12),
                      _InfoCard(
                        icon: Icons.navigation,
                        label: widget.isArabicUi ? 'الانحراف' : 'Deviation',
                        value: '${rotationDeg.toStringAsFixed(1)}°',
                        color: Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Design selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DesignButton(
                        label: 'Classic',
                        isSelected: _compassDesign == 0,
                        onTap: () => setState(() => _compassDesign = 0),
                      ),
                      const SizedBox(width: 8),
                      _DesignButton(
                        label: 'Modern',
                        isSelected: _compassDesign == 1,
                        onTap: () => setState(() => _compassDesign = 1),
                      ),
                      const SizedBox(width: 8),
                      _DesignButton(
                        label: 'Minimal',
                        isSelected: _compassDesign == 2,
                        onTap: () => setState(() => _compassDesign = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Premium Compass with decorative frame
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF1A3A2E).withValues(alpha: 0.5),
                          Color(0xFF0A1F19).withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Color(0xFFD4AF37).withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer decorative ring
                        Container(
                          width: 340,
                          height: 340,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Color(0xFFD4AF37),
                                Color(0xFFFFD700),
                                Color(0xFFFFA500),
                                Color(0xFFFFD700),
                                Color(0xFFD4AF37),
                              ],
                              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFD4AF37).withValues(alpha: 0.4),
                                blurRadius: 25,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        // Inner background
                        Container(
                          width: 310,
                          height: 310,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0xFFFFF8E1),
                                Color(0xFFFFECB3),
                              ],
                            ),
                          ),
                        ),
                        // ROTATING compass dial (rotates with phone heading)
                        Transform.rotate(
                          angle: -heading * (math.pi / 180), // Rotate dial opposite to heading
                          child: SizedBox(
                            width: 310,
                            height: 310,
                            child: CustomPaint(
                              painter: _compassDesign == 0
                                  ? _ClassicCompassDialPainter()
                                  : _compassDesign == 1
                                      ? _ModernCompassDialPainter()
                                      : _MinimalCompassDialPainter(),
                            ),
                          ),
                        ),
                        // FIXED Qiblah indicator (points to Qiblah direction)
                        Transform.rotate(
                          angle: qiblahAngle * (math.pi / 180),
                          child: SizedBox(
                            width: 310,
                            height: 310,
                            child: CustomPaint(
                              painter: _QiblahIndicatorPainter(aligned: _aligned),
                            ),
                          ),
                        ),
                        // Center hub with Kaaba symbol
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _aligned
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
                                  ),
                            border: Border.all(
                              color: _aligned ? Color(0xFF1B5E20) : Color(0xFFD4AF37),
                              width: 3,
                            ),
                            boxShadow: _aligned
                                ? [
                                    BoxShadow(
                                      color: Color(0xFF4CAF50).withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                    )
                                  ],
                          ),
                          child: Icon(
                            _aligned ? Icons.check_circle : Icons.explore_outlined,
                            color: _aligned ? Colors.white : Color(0xFFD4AF37),
                            size: 36,
                          ),
                        ),
                        // Heading indicator at top - shows direction phone is pointing
                        Positioned(
                          top: 15,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(0xFF1A3A2E).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFFD4AF37).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _getCardinalDirection(heading),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD4AF37),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  '${heading.toStringAsFixed(0)}°',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Status and accuracy
                  if (accuracyGood)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(0xFF4CAF50).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.signal_cellular_alt, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 6),
                          Text(
                            widget.isArabicUi ? 'دقة عالية' : 'High Accuracy',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Alignment status
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _aligned
                          ? LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                            )
                          : LinearGradient(
                              colors: [
                                Color(0xFFFFFFFF).withValues(alpha: 0.95),
                                Color(0xFFF5F5F5).withValues(alpha: 0.95),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _aligned ? Color(0xFF1B5E20) : Color(0xFFD4AF37),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _aligned
                              ? Color(0xFF4CAF50).withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _aligned ? Icons.check_circle : Icons.my_location,
                          color: _aligned ? Colors.white : Color(0xFF2E7D32),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _aligned
                              ? (widget.isArabicUi ? 'القبلة مضبوطة ✓' : 'Qiblah Aligned ✓')
                              : (widget.isArabicUi ? 'قم بالدوران للمحاذاة' : 'Rotate to Align'),
                          style: TextStyle(
                            color: _aligned ? Colors.white : Color(0xFF2E7D32),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        label: widget.isArabicUi ? 'إعادة المعايرة' : 'Recalibrate',
                        icon: Icons.refresh,
                        isPrimary: false,
                        onPressed: () => HapticFeedback.lightImpact(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblahIndicatorPainter extends CustomPainter {
  final bool aligned;
  _QiblahIndicatorPainter({required this.aligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Qiblah indicator path - elegant pointed arrow
    final path = Path();
    path.moveTo(center.dx, center.dy - radius + 10); // tip pointing to Qiblah
    path.quadraticBezierTo(
      center.dx - 12,
      center.dy - radius * 0.3,
      center.dx - 3,
      center.dy + 15,
    );
    path.lineTo(center.dx + 3, center.dy + 15);
    path.quadraticBezierTo(
      center.dx + 12,
      center.dy - radius * 0.3,
      center.dx,
      center.dy - radius + 10,
    );
    path.close();

    canvas.drawPath(path, shadowPaint);

    // Gradient for Qiblah indicator
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: aligned
          ? [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)]
          : [Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFFB8860B)],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Highlight edge
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, edgePaint);

    // Counter-weight at bottom
    final counterPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(center.dx, center.dy + 15),
        radius: 5,
      ));
    final counterPaint = Paint()
      ..color = Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    canvas.drawPath(counterPath, counterPaint);

    // "Qiblah" label on the indicator
    if (!aligned) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Q',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - radius + 25,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ClassicCompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    final minorPaint = Paint()
      ..color = Color(0xFF8D6E63)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final majorPaint = Paint()
      ..color = Color(0xFF5D4037)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 360; i += 3) {
      final isMajor = i % 30 == 0;
      final isCardinal = i % 90 == 0;
      
      if (isCardinal) continue;
      
      final len = isMajor ? 16.0 : 8.0;
      final ang = (i - 90) * (math.pi / 180);
      final p1 = Offset(
        center.dx + (radius - len) * math.cos(ang),
        center.dy + (radius - len) * math.sin(ang),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(ang),
        center.dy + radius * math.sin(ang),
      );
      canvas.drawLine(p1, p2, isMajor ? majorPaint : minorPaint);
    }

    // Cardinal letters
    const cardinals = [
      {'label': 'N', 'angle': 0},
      {'label': 'E', 'angle': 90},
      {'label': 'S', 'angle': 180},
      {'label': 'W', 'angle': 270},
    ];

    for (final card in cardinals) {
      final ang = ((card['angle'] as int) - 90) * (math.pi / 180);
      final pos = Offset(
        center.dx + (radius - 32) * math.cos(ang),
        center.dy + (radius - 32) * math.sin(ang),
      );

      final bgPaint = Paint()
        ..color = Color(0xFFD4AF37).withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 14, bgPaint);

      final borderPaint = Paint()
        ..color = Color(0xFFD4AF37).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, 14, borderPaint);

      final textStyle = TextStyle(
        fontSize: card['label'] == 'N' ? 16 : 14,
        fontWeight: FontWeight.bold,
        color: card['label'] == 'N' ? Color(0xFFD32F2F) : Color(0xFF5D4037),
        letterSpacing: 0.5,
      );
      _paintText(canvas, card['label'] as String, pos, textStyle);
    }

    // Degree marks
    final degreeStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFF8D6E63),
    );

    for (var i = 45; i < 360; i += 45) {
      final ang = (i - 90) * (math.pi / 180);
      final pos = Offset(
        center.dx + (radius - 50) * math.cos(ang),
        center.dy + (radius - 50) * math.sin(ang),
      );
      _paintText(canvas, '$i°', pos, degreeStyle);
    }
  }

  void _paintText(Canvas canvas, String text, Offset pos, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModernCompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Modern sleek ticks
    final tickPaint = Paint()
      ..color = Color(0xFF37474F)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 360; i += 10) {
      final isMajor = i % 30 == 0;
      final len = isMajor ? 18.0 : 10.0;
      final ang = (i - 90) * (math.pi / 180);
      
      final p1 = Offset(
        center.dx + (radius - len) * math.cos(ang),
        center.dy + (radius - len) * math.sin(ang),
      );
      final p2 = Offset(
        center.dx + (radius - 2) * math.cos(ang),
        center.dy + (radius - 2) * math.sin(ang),
      );
      
      tickPaint.strokeWidth = isMajor ? 3 : 1.5;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Simplified cardinals
    const cardinals = ['N', 'E', 'S', 'W'];
    final textStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A237E),
    );

    for (var i = 0; i < 4; i++) {
      final ang = (i * 90 - 90) * (math.pi / 180);
      final pos = Offset(
        center.dx + (radius - 38) * math.cos(ang),
        center.dy + (radius - 38) * math.sin(ang),
      );
      _paintText(canvas, cardinals[i], pos, textStyle);
    }
  }

  void _paintText(Canvas canvas, String text, Offset pos, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MinimalCompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Only cardinal directions
    final linePaint = Paint()
      ..color = Color(0xFF424242)
      ..strokeWidth = 1.5;

    for (var i = 0; i < 4; i++) {
      final ang = (i * 90 - 90) * (math.pi / 180);
      final p1 = center;
      final p2 = Offset(
        center.dx + (radius - 20) * math.cos(ang),
        center.dy + (radius - 20) * math.sin(ang),
      );
      canvas.drawLine(p1, p2, linePaint);
    }

    // Large cardinals
    const cardinals = ['N', 'E', 'S', 'W'];
    final textStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w300,
      color: Color(0xFF212121),
      letterSpacing: 2,
    );

    for (var i = 0; i < 4; i++) {
      final ang = (i * 90 - 90) * (math.pi / 180);
      final pos = Offset(
        center.dx + (radius - 35) * math.cos(ang),
        center.dy + (radius - 35) * math.sin(ang),
      );
      _paintText(canvas, cardinals[i], pos, textStyle);
    }

    // Subtle degree ring
    final ringPaint = Paint()
      ..color = Color(0xFF9E9E9E).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 10, ringPaint);
  }

  void _paintText(Canvas canvas, String text, Offset pos, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DesignButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesignButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Color(0xFFD4AF37)
                : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PremiumNeedlePainter extends CustomPainter {
  final bool aligned;
  _PremiumNeedlePainter({required this.aligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Main needle path - elegant pointed design
    final path = Path();
    path.moveTo(center.dx, center.dy - radius + 10); // tip
    path.quadraticBezierTo(
      center.dx - 12,
      center.dy - radius * 0.3,
      center.dx - 3,
      center.dy + 15,
    );
    path.lineTo(center.dx + 3, center.dy + 15);
    path.quadraticBezierTo(
      center.dx + 12,
      center.dy - radius * 0.3,
      center.dx,
      center.dy - radius + 10,
    );
    path.close();

    canvas.drawPath(path, shadowPaint);

    // Gradient needle
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: aligned
          ? [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)]
          : [Color(0xFFFF6B6B), Color(0xFFD32F2F), Color(0xFF8B0000)],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Highlight edge
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, edgePaint);

    // Counter-weight at bottom
    final counterPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(center.dx, center.dy + 15),
        radius: 5,
      ));
    final counterPaint = Paint()
      ..color = Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    canvas.drawPath(counterPath, counterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumCompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Tick marks
    final minorPaint = Paint()
      ..color = Color(0xFF8D6E63)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final majorPaint = Paint()
      ..color = Color(0xFF5D4037)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 360; i += 3) {
      final isMajor = i % 30 == 0;
      final isCardinal = i % 90 == 0;
      
      if (isCardinal) continue; // Skip cardinals, we'll draw letters
      
      final len = isMajor ? 16.0 : 8.0;
      final ang = (i - 90) * (math.pi / 180);
      final p1 = Offset(
        center.dx + (radius - len) * math.cos(ang),
        center.dy + (radius - len) * math.sin(ang),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(ang),
        center.dy + radius * math.sin(ang),
      );
      canvas.drawLine(p1, p2, isMajor ? majorPaint : minorPaint);
    }

    // Cardinal letters with background
    const cardinals = [
      {'label': 'N', 'angle': 0},
      {'label': 'E', 'angle': 90},
      {'label': 'S', 'angle': 180},
      {'label': 'W', 'angle': 270},
    ];

    for (final card in cardinals) {
      final ang = ((card['angle'] as int) - 90) * (math.pi / 180);
      final pos = Offset(
        center.dx + (radius - 32) * math.cos(ang),
        center.dy + (radius - 32) * math.sin(ang),
      );

      // Background circle for letter
      final bgPaint = Paint()
        ..color = Color(0xFFD4AF37).withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 14, bgPaint);

      // Border
      final borderPaint = Paint()
        ..color = Color(0xFFD4AF37).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, 14, borderPaint);

      // Letter
      final textStyle = TextStyle(
        fontSize: card['label'] == 'N' ? 16 : 14,
        fontWeight: FontWeight.bold,
        color: card['label'] == 'N' ? Color(0xFFD32F2F) : Color(0xFF5D4037),
        letterSpacing: 0.5,
      );
      _paintText(canvas, card['label'] as String, pos, textStyle);
    }

    // Degree marks every 45 degrees
    final degreeStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFF8D6E63),
    );

    for (var i = 45; i < 360; i += 45) {
      final ang = (i - 90) * (math.pi / 180);
      final pos = Offset(
        center.dx + (radius - 50) * math.cos(ang),
        center.dy + (radius - 50) * math.sin(ang),
      );
      _paintText(canvas, '$i°', pos, degreeStyle);
    }
  }

  void _paintText(Canvas canvas, String text, Offset pos, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool aligned;
  final bool isArabicUi;
  const _StatusPill({required this.aligned, required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: aligned ? Colors.green : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: aligned ? Colors.green.shade700 : Colors.green, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(aligned ? Icons.check_circle : Icons.explore, color: aligned ? Colors.white : Colors.green, size: 22),
          const SizedBox(width: 8),
          Text(
            aligned ? (isArabicUi ? 'القبلة مضبوطة ✓' : 'Qiblah Aligned ✓') : (isArabicUi ? 'قم بالدوران للمحاذاة' : 'Rotate to align'),
            style: TextStyle(
              color: aligned ? Colors.white : const Color(0xFF2E7D32),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _SecondaryButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Colors.white70, width: 1.5),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _BackgroundPattern extends StatelessWidget {
  const _BackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackgroundPatternPainter());
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.2;

    for (double r = size.width * 0.25; r < size.width; r += 26) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r),
          -3.14, 3.14, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MosqueSilhouette extends StatelessWidget {
  const _MosqueSilhouette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _MosqueSilhouettePainter()));
  }
}

class _MosqueSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path();
    // Simple stylized mosque: base, dome, two minarets
    path.moveTo(w * 0.15, h * 0.95);
    path.lineTo(w * 0.85, h * 0.95);
    // Dome
    path.quadraticBezierTo(w * 0.5, h * 0.3, w * 0.15, h * 0.95);
    // Left minaret
    final leftMinaret = Path()
      ..moveTo(w * 0.22, h * 0.95)
      ..lineTo(w * 0.22, h * 0.55)
      ..lineTo(w * 0.26, h * 0.55)
      ..lineTo(w * 0.26, h * 0.95)
      ..close();
    // Right minaret
    final rightMinaret = Path()
      ..moveTo(w * 0.74, h * 0.95)
      ..lineTo(w * 0.74, h * 0.55)
      ..lineTo(w * 0.78, h * 0.55)
      ..lineTo(w * 0.78, h * 0.95)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(leftMinaret, paint);
    canvas.drawPath(rightMinaret, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MosqueSilhouettePainterStatic extends CustomPainter {
  const _MosqueSilhouettePainterStatic();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.1, h * 0.9);
    path.lineTo(w * 0.9, h * 0.9);
    path.quadraticBezierTo(w * 0.5, h * 0.25, w * 0.1, h * 0.9);
    final leftMinaret = Path()
      ..moveTo(w * 0.2, h * 0.9)
      ..lineTo(w * 0.2, h * 0.5)
      ..lineTo(w * 0.23, h * 0.5)
      ..lineTo(w * 0.23, h * 0.9)
      ..close();
    final rightMinaret = Path()
      ..moveTo(w * 0.77, h * 0.9)
      ..lineTo(w * 0.77, h * 0.5)
      ..lineTo(w * 0.8, h * 0.5)
      ..lineTo(w * 0.8, h * 0.9)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(leftMinaret, paint);
    canvas.drawPath(rightMinaret, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QiblahMap extends StatelessWidget {
  final double bearing;
  final double userLat;
  final double userLng;
  final bool isArabicUi;

  const _QiblahMap({
    required this.bearing,
    required this.userLat,
    required this.userLng,
    required this.isArabicUi,
  });

  @override
  Widget build(BuildContext context) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    final distance = _calculateDistance(userLat, userLng, kaabaLat, kaabaLng);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header card with location pin
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDAA520), Color(0xFFF4D03F)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.shade200.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    isArabicUi ? 'اتجاه الكعبة المشرفة' : 'Direction to Holy Kaaba',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Interactive map with markers and direction line
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: Stack(
                  children: [
                    // Decorative translucent mosque behind map
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.06,
                          child: CustomPaint(painter: const _MosqueSilhouettePainterStatic()),
                        ),
                      ),
                    ),
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: latlng.LatLng(userLat, userLng),
                        initialZoom: 12,
                        interactionOptions: const InteractionOptions(
                          flags: ~InteractiveFlag.rotate, // disable rotation for clarity
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.quraan.app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [
                                latlng.LatLng(userLat, userLng),
                                latlng.LatLng(kaabaLat, kaabaLng),
                              ],
                              strokeWidth: 3,
                              color: Colors.green,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latlng.LatLng(userLat, userLng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
                            ),
                            Marker(
                              point: latlng.LatLng(kaabaLat, kaabaLng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.place, color: Color(0xFFDAA520), size: 32),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Info overlay cards
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Distance card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.straighten, color: Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${distance.toStringAsFixed(0)} km',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Bearing card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFDAA520), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.explore, color: Colors.brown.shade700, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${bearing.toStringAsFixed(1)}°',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer with Kaaba icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: const Color(0xFFDAA520), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 9,
                        height: 1.5,
                        color: const Color(0xFFDAA520),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabicUi ? 'الكعبة المشرفة - مكة المكرمة' : 'Holy Kaaba - Makkah',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}

// Removed placeholder painter in favor of real interactive map

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isPrimary ? Color(0xFF2E7D32) : Colors.white.withValues(alpha: 0.15),
        foregroundColor: isPrimary ? Colors.white : Colors.white70,
        elevation: 0,
        side: BorderSide(
          color: isPrimary
              ? Color(0xFF1B5E20)
              : Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw geometric Islamic pattern
    final gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      for (double y = 0; y < size.height; y += gridSize) {
        // Draw star pattern
        final center = Offset(x + gridSize / 2, y + gridSize / 2);
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * 45) * math.pi / 180;
          final radius = gridSize * 0.3;
          final point = Offset(
            center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MosqueBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Central dome
    final domePath = Path()
      ..moveTo(w * 0.35, h * 0.6)
      ..quadraticBezierTo(w * 0.5, h * 0.2, w * 0.65, h * 0.6)
      ..lineTo(w * 0.65, h * 0.7)
      ..lineTo(w * 0.35, h * 0.7)
      ..close();
    canvas.drawPath(domePath, paint);

    // Left minaret
    final leftMinaret = Path()
      ..moveTo(w * 0.25, h * 0.4)
      ..lineTo(w * 0.25, h * 0.75)
      ..lineTo(w * 0.3, h * 0.75)
      ..lineTo(w * 0.3, h * 0.4)
      ..close();
    canvas.drawPath(leftMinaret, paint);

    // Right minaret
    final rightMinaret = Path()
      ..moveTo(w * 0.7, h * 0.4)
      ..lineTo(w * 0.7, h * 0.75)
      ..lineTo(w * 0.75, h * 0.75)
      ..lineTo(w * 0.75, h * 0.4)
      ..close();
    canvas.drawPath(rightMinaret, paint);

    // Minaret tops (crescents)
    final crescentPaint = Paint()
      ..color = Color(0xFFD4AF37).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.275, h * 0.38), 8, crescentPaint);
    canvas.drawCircle(Offset(w * 0.725, h * 0.38), 8, crescentPaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.18), 12, crescentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorState extends StatelessWidget {
  final bool isArabicUi;
  final String message;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocation;

  const _ErrorState({
    required this.isArabicUi,
    required this.message,
    required this.onOpenSettings,
    required this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 56, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: onOpenLocation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: Text(isArabicUi ? 'إعدادات الموقع' : 'Location Settings'),
              ),
              OutlinedButton(
                onPressed: onOpenSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: Text(isArabicUi ? 'إعدادات التطبيق' : 'App Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
*/
