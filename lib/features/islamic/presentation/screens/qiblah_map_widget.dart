import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MAP QIBLA VIEW
//  Interactive dark-themed map that draws the great-circle (geodesic) path
//  from the user's current location to the Kaaba in Mecca, along with
//  animated user marker, Mecca pin, distance and bearing info card.
// ─────────────────────────────────────────────────────────────────────────────

class QiblahMapWidget extends StatefulWidget {
  final double userLat;
  final double userLng;
  final double qiblahAngle; // degrees clockwise from North
  final bool isAr;

  const QiblahMapWidget({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.qiblahAngle,
    required this.isAr,
  });

  @override
  State<QiblahMapWidget> createState() => _QiblahMapWidgetState();
}

class _QiblahMapWidgetState extends State<QiblahMapWidget>
    with SingleTickerProviderStateMixin {
  // Al-Masjid al-Haram (Kaaba) precise coordinates
  static const double _meccaLat = 21.4225;
  static const double _meccaLng = 39.8262;

  late final MapController _mapCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Precomputed once in initState
  late final List<LatLng> _geodesicPath;
  late final double _distKm;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _geodesicPath = _buildGeodesicPath(50);
    _distKm = _haversineKm();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ── Great-circle intermediate points ──────────────────────────────────────

  List<LatLng> _buildGeodesicPath(int steps) {
    final lat1 = widget.userLat * math.pi / 180;
    final lon1 = widget.userLng * math.pi / 180;
    const lat2 = _meccaLat * math.pi / 180;
    const lon2 = _meccaLng * math.pi / 180;

    final d = 2 *
        math.asin(math.sqrt(
          math.pow(math.sin((lat2 - lat1) / 2), 2) +
              math.cos(lat1) *
                  math.cos(lat2) *
                  math.pow(math.sin((lon2 - lon1) / 2), 2),
        ));

    if (d < 1e-8) {
      return [
        LatLng(widget.userLat, widget.userLng),
        const LatLng(_meccaLat, _meccaLng),
      ];
    }

    final pts = <LatLng>[];
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final A = math.sin((1 - f) * d) / math.sin(d);
      final B = math.sin(f * d) / math.sin(d);
      final x = A * math.cos(lat1) * math.cos(lon1) +
          B * math.cos(lat2) * math.cos(lon2);
      final y = A * math.cos(lat1) * math.sin(lon1) +
          B * math.cos(lat2) * math.sin(lon2);
      final z = A * math.sin(lat1) + B * math.sin(lat2);
      pts.add(LatLng(
        math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi,
        math.atan2(y, x) * 180 / math.pi,
      ));
    }
    return pts;
  }

  double _haversineKm() {
    const R = 6371.0;
    final lat1 = widget.userLat * math.pi / 180;
    const lat2 = _meccaLat * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = (_meccaLng - widget.userLng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _fitBounds() {
    final bounds = LatLngBounds.fromPoints([
      LatLng(widget.userLat, widget.userLng),
      const LatLng(_meccaLat, _meccaLng),
    ]);
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 80, 60, 180),
      ),
    );
  }

  /// Zoom in on the user's own location.
  void _goToMe() {
    _mapCtrl.move(
      LatLng(widget.userLat, widget.userLng),
      14.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPos = LatLng(widget.userLat, widget.userLng);
    const meccaPos = LatLng(_meccaLat, _meccaLng);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tile background colour: matches the CartoDB tile canvas colour
    final tileBg = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF0EBE0);

    return Stack(
      children: [
        // ── Dark interactive map ──────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: LatLng(
              (widget.userLat + _meccaLat) / 2,
              (widget.userLng + _meccaLng) / 2,
            ),
            initialZoom: 4,
            minZoom: 2,
            maxZoom: 18,
            // Canvas colour prevents flashing while tiles load
            backgroundColor: tileBg,
            onMapReady: _fitBounds,
          ),
          children: [
            // CartoDB nolabels base – geography only, no country text at all.
            // Using nolabels eliminates any possibility of "Israel" or any
            // other country label appearing; the Qibla map only needs
            // geographic shapes + our custom overlay layers.
            TileLayer(
              urlTemplate: isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
              userAgentPackageName: 'com.nooraliman.quran',
              minNativeZoom: 0,
              maxNativeZoom: 18,
              maxZoom: 19,
              minZoom: 2,
              errorTileCallback: (tile, error, stackTrace) {},
              tileBuilder: (ctx, tileWidget, tile) => ColoredBox(
                color: tileBg,
                child: tileWidget,
              ),
            ),

            // Gold geodesic Qibla path
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _geodesicPath,
                  color: AppColors.secondary.withValues(alpha: 0.88),
                  strokeWidth: 2.6,
                  isDotted: true,
                ),
              ],
            ),

            // Markers
            MarkerLayer(
              markers: [
                // ── Animated user location marker ─────────────────────
                Marker(
                  point: userPos,
                  width: 68,
                  height: 68,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) => Stack(
                      alignment: Alignment.center,
                      children: [
                        // Expanding ring
                        Opacity(
                          opacity: (1 - _pulseAnim.value) * 0.8 + 0.05,
                          child: SizedBox.square(
                            dimension: 56 * _pulseAnim.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary
                                    .withValues(alpha: 0.18),
                                border: Border.all(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Inner glow ring
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondary.withValues(alpha: 0.12),
                          ),
                        ),
                        // Core dot with Qibla arrow
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.secondary,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary
                                    .withValues(alpha: 0.65),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Transform.rotate(
                              angle: widget.qiblahAngle * math.pi / 180,
                              child: Icon(
                                Icons.navigation,
                                color: AppColors.primary,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Mecca / Kaaba marker ──────────────────────────────
                Marker(
                  point: meccaPos,
                  width: 60,
                  height: 75,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.3),
                            colors: [Color(0xFF1E2D3D), Color(0xFF0C1018)],
                          ),
                          border: Border.all(
                            color: AppColors.secondary,
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.70),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.25),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mosque_rounded,
                          color: AppColors.secondary,
                          size: 30,
                        ),
                      ),
                      // Pin tail
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Top label ─────────────────────────────────────────────────────
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F1419).withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mosque_rounded,
                    color: AppColors.secondary.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isAr ? 'طريق مكة المكرمة' : 'Path to Makkah',
                    style: GoogleFonts.amiri(
                      color: AppColors.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Right-side control buttons ─────────────────────────────────────
        Positioned(
          right: 14,
          bottom: 156,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // My Location button
              _MapControlButton(
                icon: Icons.my_location_rounded,
                tooltip: widget.isAr ? 'موقعي' : 'My Location',
                onTap: _goToMe,
              ),
              const SizedBox(height: 8),
              // Fit-both-points button
              _MapControlButton(
                icon: Icons.fullscreen_rounded,
                tooltip: widget.isAr ? 'عرض المسار كاملاً' : 'Fit Route',
                onTap: _fitBounds,
              ),
            ],
          ),
        ),

        // ── Bottom info card ──────────────────────────────────────────────
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildInfoCard(),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final isAr = widget.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Format distance nicely
    final distText = _distKm >= 1000
        ? '${(_distKm / 1000).toStringAsFixed(2)}K km'
        : '${_distKm.toStringAsFixed(0)} km';
    final distTextAr = _distKm >= 1000
        ? '${(_distKm / 1000).toStringAsFixed(2)} ألف كم'
        : '${_distKm.toStringAsFixed(0)} كم';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1419).withValues(alpha: 0.97)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 4,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Distance ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_rounded,
                  color: AppColors.secondary.withValues(alpha: 0.65),
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  isAr ? 'المسافة إلى مكة' : 'Distance to Mecca',
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  isAr ? distTextAr : distText,
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // Gradient divider
          Container(
            width: 1,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.secondary.withValues(alpha: 0.40),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── Qibla bearing ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: widget.qiblahAngle * math.pi / 180,
                  child: Icon(
                    Icons.navigation_rounded,
                    color: AppColors.secondary.withValues(alpha: 0.65),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr ? 'اتجاه القبلة' : 'Qibla Bearing',
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.qiblahAngle.toStringAsFixed(1)}°',
                  style: GoogleFonts.cairo(
                    color: AppColors.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAP CONTROL BUTTON  –  icon button floating over the map, theme-aware
// ─────────────────────────────────────────────────────────────────────────────

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151E27) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.18),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppColors.secondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

