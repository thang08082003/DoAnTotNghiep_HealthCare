import 'package:flutter/material.dart';
import '../app_bar/custom_bottom_navigation_bar.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';

abstract class BasePage extends StatefulWidget {
  final String title; // Keep for backward compatibility but not used
  final UserRole userRole;

  const BasePage({super.key, required this.title, required this.userRole});
}

abstract class BasePageState<T extends BasePage> extends State<T> {
  int currentIndex = 0;

  // Abstract methods that child classes must implement
  List<Widget> buildPages();
  void onNavigationTap(int index);

  // Optional method for custom body
  Widget buildBody() {
    final pages = buildPages();
    return pages.isNotEmpty && currentIndex < pages.length
        ? pages[currentIndex]
        : const Center(child: Text('Không tìm thấy trang'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'HealthCare',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(child: buildBody()),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
          onNavigationTap(index);
        },
        userRole: widget.userRole,
      ),
    );
  }
}
