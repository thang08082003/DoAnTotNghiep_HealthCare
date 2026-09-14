import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/profile/patient_profile_view_model.dart';
import '../../components/allergic_medication_selector.dart';
import '../../data/repositories/patient_profile_repository.dart';

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
  List<String> _allergicMedications = [];
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
      final state = ref.read(patientProfileViewModelProvider(user.uid));
      _phoneCtrl.text = state.phone;
      _ageCtrl.text = state.ageText;
      _gender = state.gender;
      _historyCtrl.text = state.medicalHistory;

      // Load allergic medications
      if (user.allergicMedications != null) {
        _allergicMedications = List<String>.from(user.allergicMedications!);
      }

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
      final vm = ref.read(patientProfileViewModelProvider(user.uid).notifier);
      vm.setPhone(_phoneCtrl.text);
      vm.setAgeText(_ageCtrl.text);
      vm.setGender(_gender);
      vm.setHistory(_historyCtrl.text);
      await vm.save();

      // Save allergic medications
      await PatientProfileRepository().updateAllergicMedications(
        user.uid,
        _allergicMedications,
      );

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
                    const Text(
                      'Thuốc dị ứng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AllergicMedicationSelector(
                      selectedMedications: _allergicMedications,
                      onChanged: (medications) {
                        setState(() {
                          _allergicMedications = medications;
                        });
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
