import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/profile/doctor_profile_view_model.dart';

class EditDoctorProfileScreen extends ConsumerStatefulWidget {
  const EditDoctorProfileScreen({super.key});

  @override
  ConsumerState<EditDoctorProfileScreen> createState() =>
      _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState
    extends ConsumerState<EditDoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Specialty? _specialty;
  bool _loading = true;
  String? _error;

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
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null || !user.isDoctor) {
        setState(() {
          _error = 'Chỉ bác sĩ mới có thể chỉnh sửa thông tin này';
          _loading = false;
        });
        return;
      }
      final state = ref.read(doctorProfileViewModelProvider(user.uid));
      _nameCtrl.text = state.name;
      _yearsCtrl.text = state.yearsExperience?.toString() ?? '';
      _descCtrl.text = state.description;
      _specialty =
          state.specialty ?? (user is DoctorModel ? user.specialty : null);
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi tải dữ liệu: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) throw 'Không xác định được người dùng';
      final vm = ref.read(doctorProfileViewModelProvider(user.uid).notifier);
      vm.setName(_nameCtrl.text);
      vm.setSpecialty(_specialty);
      vm.setYears(_yearsCtrl.text);
      vm.setDescription(_descCtrl.text);
      await vm.save();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Lưu thất bại: $e';
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin bác sĩ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tên'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Specialty>(
                      value: _specialty,
                      items: Specialty.allSpecialties
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.vietnameseName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _specialty = v),
                      decoration: const InputDecoration(
                        labelText: 'Chuyên khoa',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _yearsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số năm kinh nghiệm',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return int.tryParse(v.trim()) == null
                            ? 'Phải là số'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả / Giới thiệu',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Lưu thay đổi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
