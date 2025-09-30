import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/base_page/base_page_scaffold.dart';
import '../../components/doctor/doctor_card.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';

class DoctorsPage extends BasePage {
  const DoctorsPage({
    super.key,
    required super.userRole,
  }) : super(
          title: 'Bác sĩ',
        );

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();

  // Static method for HomePage to extract content
  static Widget buildContent(BuildContext context, WidgetRef ref, dynamic user) {
    return _DoctorsContent();
  }
}

class _DoctorsPageState extends BasePageState<DoctorsPage> {
  @override
  List<Widget> buildPages() {
    return [_DoctorsContent()];
  }

  @override
  void onNavigationTap(int index) {
    // Navigation handled by HomePage
  }
}

class _DoctorsContent extends StatefulWidget {
  @override
  _DoctorsContentState createState() => _DoctorsContentState();
}

class _DoctorsContentState extends State<_DoctorsContent> {
  List<DoctorModel> _doctors = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedSpecialty;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // TODO: Implement API call to fetch doctors
      // final response = await doctorService.getDoctors();
      // final doctors = response.data;
      
      // For now, show empty list until API is implemented
      final doctors = <DoctorModel>[];
      
      if (mounted) {
        setState(() {
          _doctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Có lỗi xảy ra khi tải danh sách bác sĩ: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // Search bar
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bác sĩ...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Specialty filter
              DropdownButtonFormField<String>(
                value: _selectedSpecialty,
                onChanged: (value) {
                  setState(() {
                    _selectedSpecialty = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Chọn chuyên khoa',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tất cả chuyên khoa')),
                  DropdownMenuItem(value: 'stress', child: Text('Stress')),
                  DropdownMenuItem(value: 'cardiology', child: Text('Tim mạch')),
                  DropdownMenuItem(value: 'diagnosis', child: Text('Chuẩn đoán bệnh')),
                ],
              ),
            ],
          ),
        ),
        // Doctors list
        Expanded(
          child: _buildDoctorsList(),
        ),
      ],
    );
  }

  Widget _buildDoctorsList() {
    if (_isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDoctors,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final filteredDoctors = _doctors.where((doctor) {
      final matchesSearch = doctor.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSpecialty = _selectedSpecialty == null || doctor.specialty.name == _selectedSpecialty;
      return matchesSearch && matchesSpecialty;
    }).toList();

    if (filteredDoctors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy bác sĩ nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDoctors.length,
      itemBuilder: (context, index) {
        final doctor = filteredDoctors[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DoctorCard(doctor: doctor),
        );
      },
    );
  }
}