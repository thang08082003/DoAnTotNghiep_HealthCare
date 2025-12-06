import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/user_service.dart';
import '../../components/doctor/doctor_card.dart';
import '../appointments/book_appointment_screen.dart';
import 'doctor_detail_screen.dart';

/// Màn hình danh sách bác sĩ với filter theo chuyên môn
class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key});

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen>
    with SingleTickerProviderStateMixin {
  Specialty? _selectedSpecialty;
  List<DoctorModel> _allDoctors = [];
  bool _loading = true;
  bool _isFilterExpanded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final userService = UserService();
      final doctors = await userService.getAllDoctors();
      if (mounted) {
        setState(() {
          _allDoctors = doctors.whereType<DoctorModel>().toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách bác sĩ: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Removed following doctors loading and tab

  List<DoctorModel> get _filteredDoctors {
    if (_selectedSpecialty == null) {
      return _allDoctors;
    }
    return _allDoctors
        .where((doctor) => doctor.specialty == _selectedSpecialty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSpecialtyFilter(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildAllDoctorsTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.local_hospital), text: 'Đặt lịch khám'),
        ],
      ),
    );
  }

  Widget _buildSpecialtyFilter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedSpecialty == null
                            ? 'Lọc theo chuyên môn'
                            : _selectedSpecialty!.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isFilterExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          if (_isFilterExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSpecialtyChip(
                    label: 'Tất cả',
                    isSelected: _selectedSpecialty == null,
                    onTap: () {
                      setState(() {
                        _selectedSpecialty = null;
                        _isFilterExpanded = false;
                      });
                    },
                  ),
                  ...Specialty.values.map((specialty) {
                    return _buildSpecialtyChip(
                      label: specialty.displayName,
                      isSelected: _selectedSpecialty == specialty,
                      onTap: () {
                        setState(() {
                          _selectedSpecialty = specialty;
                          _isFilterExpanded = false;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecialtyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor
              : AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.primaryColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorsList() {
    return RefreshIndicator(
      onRefresh: _loadDoctors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDoctors.length,
        itemBuilder: (context, index) {
          final doctor = _filteredDoctors[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DoctorCard(
              doctor: doctor,
              showBookButton: true,
              onBookAppointment: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookAppointmentScreen(doctor: doctor),
                  ),
                );
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorDetailScreen(
                      doctorId: doctor.uid,
                      infoOnly: true,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllDoctorsTab() {
    return _filteredDoctors.isEmpty
        ? const _EmptyState(message: 'Không tìm thấy bác sĩ')
        : _buildDoctorsList();
  }

  // Following tab removed
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          // subtitle removed
        ],
      ),
    );
  }
}
