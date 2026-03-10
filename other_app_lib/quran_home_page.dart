import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qcf_quran/qcf_quran.dart';

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("المصحف الشريف — صفحة $_currentPage / $totalPagesCount"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: PageviewQuran(
        onPageChanged: (page) {
          setState(() => _currentPage = page);
        },
        sp: 1.sp,
        h: 1.h,
      ),
    );
  }
}
