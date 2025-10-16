import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';

class EditPatientProfileScreen extends ConsumerStatefulWidget {
  const EditPatientProfileScreen({super.key});

  @override
  ConsumerState<EditPatientProfileScreen> createState() =>
      _EditPatientProfileScreenState();
}

class _EditPatientProfileScreenState
    extends ConsumerState<EditPatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'Khác';
  final _historyCtrl = TextEditingController();
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
      if (user == null || !user.isPatient) {
        setState(() {
          _error = 'Chỉ bệnh nhân mới có thể chỉnh sửa thông tin này';
          _loading = false;
        });
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      _phoneCtrl.text = (data['phone'] as String?) ?? '';
      _ageCtrl.text = (data['age'] is int)
          ? (data['age'] as int).toString()
          : ((data['age'] as String?) ?? '');
      _gender = (data['gender'] as String?)?.trim().isNotEmpty == true
          ? data['gender'] as String
          : 'Khác';
      _historyCtrl.text = (data['medicalHistory'] is String)
          ? (data['medicalHistory'] as String)
          : '';
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
      final updates = <String, dynamic>{
        'phone': _phoneCtrl.text.trim(),
        'gender': _gender.trim(),
        'medicalHistory': _historyCtrl.text.trim(),
      };
      final ageText = _ageCtrl.text.trim();
      if (ageText.isNotEmpty) {
        final age = int.tryParse(ageText);
        if (age != null) {
          updates['age'] = age;
        } else {
          updates['age'] = ageText; // fallback string
        }
      } else {
        updates['age'] = FieldValue.delete();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Lưu thất bại: $e';
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _historyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin bệnh nhân')),
      body: _loading
          ? const LoadingWidget()
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
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tuổi'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return int.tryParse(v.trim()) == null
                            ? 'Tuổi phải là số'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                        DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                        DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'Khác'),
                      decoration: const InputDecoration(labelText: 'Giới tính'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _historyCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Tiền sử bệnh',
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
