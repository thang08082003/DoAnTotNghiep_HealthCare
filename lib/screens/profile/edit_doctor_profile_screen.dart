import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';

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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      _nameCtrl.text = user.name;
      _yearsCtrl.text = (data['yearsExperience']?.toString() ?? '');
      final specStr = data['specialty'] as String?;
      _specialty = specStr != null
          ? Specialty.fromString(specStr)
          : (user is DoctorModel ? user.specialty : null);
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
      final updates = <String, dynamic>{'name': _nameCtrl.text.trim()};
      if (_specialty != null) updates['specialty'] = _specialty!.englishName;
      final yearsText = _yearsCtrl.text.trim();
      if (yearsText.isNotEmpty) {
        final y = int.tryParse(yearsText);
        if (y != null) updates['yearsExperience'] = y;
      } else {
        updates['yearsExperience'] = FieldValue.delete();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);
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
