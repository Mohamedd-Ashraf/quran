import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show QuranPageView;

/// A stress test screen that rapidly cycles through all 604 Mushaf pages
/// to verify rendering correctness.
///
/// Each page is displayed for 500ms before advancing to the next.
/// The test can be paused/resumed and includes a progress indicator.
class MushafStressTestScreen extends StatefulWidget {
  const MushafStressTestScreen({super.key});

  @override
  State<MushafStressTestScreen> createState() => _MushafStressTestScreenState();
}

class _MushafStressTestScreenState extends State<MushafStressTestScreen> {
  static const int _totalPages = 604;
  static const Duration _pageInterval = Duration(milliseconds: 500);

  int _currentPage = 1;
  bool _isRunning = true;
  Timer? _timer;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pageController = PageController(initialPage: 0);

    // Start test after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTest();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startTest() {
    _timer = Timer.periodic(_pageInterval, (_) {
      if (!_isRunning) return;
      if (!mounted) return;

      if (_currentPage < _totalPages) {
        _goToPage(_currentPage + 1);
      } else {
        // Test completed - restart from page 1
        _goToPage(1);
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isRunning = !_isRunning;
    });
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      // Check if controller is attached before jumping
      if (_pageController.hasClients) {
        _pageController.jumpToPage(page - 1);
      }
      setState(() {
        _currentPage = page;
      });
    }
  }

  void _onPageChanged(int page) {
    // page is 1-indexed from QuranPageView
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _currentPage / _totalPages;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top controls bar
            Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),

                      const SizedBox(width: 8),

                      // Page counter
                      Expanded(
                        child: Text(
                          'صفحة $_currentPage / $_totalPages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),

                      // Pause/Play button
                      IconButton(
                        icon: Icon(
                          _isRunning ? Icons.pause_circle : Icons.play_circle,
                          size: 32,
                        ),
                        color: _isRunning ? Colors.orange : Colors.green,
                        onPressed: _togglePause,
                      ),

                      // Speed indicator
                      Text(
                        '0.5s',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Progress bar
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
            ),

            // Main page display - Expanded to fill remaining space
            Expanded(
              child: QuranPageView(
                pageController: _pageController,
                highlights: const [],
                isDarkMode: isDark,
                onPageChanged: _onPageChanged,
                onAyahTap: (s, v) {},
              ),
            ),

            // Bottom navigation
            Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Go to start
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    tooltip: 'البداية',
                    onPressed: () => _goToPage(1),
                  ),

                  // Previous page
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                  ),

                  // Page input
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '$_currentPage',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (value) {
                          final page = int.tryParse(value);
                          if (page != null) _goToPage(page);
                        },
                      ),
                    ),
                  ),

                  // Next page
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                  ),

                  // Go to end
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    tooltip: 'النهاية',
                    onPressed: () => _goToPage(_totalPages),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
