import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/medication_prescription_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../data/database/medication_database.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/user_provider.dart';
import '../../../viewmodels/prescription/prescription_viewmodel.dart';

class CreatePrescriptionBottomSheet extends ConsumerStatefulWidget {
  final String patientId;
  final MedicationPrescription?
  existingPrescription; // null = create, not null = edit

  const CreatePrescriptionBottomSheet({
    super.key,
    required this.patientId,
    this.existingPrescription,
  });

  @override
  ConsumerState<CreatePrescriptionBottomSheet> createState() =>
      _CreatePrescriptionBottomSheetState();
}

class _CreatePrescriptionBottomSheetState
    extends ConsumerState<CreatePrescriptionBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _medicationNameController = TextEditingController();
  final _concentrationController = TextEditingController();
  final _quantityController = TextEditingController();
  final _dosageController = TextEditingController();
  final _routeController = TextEditingController();
  final _timingController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  final _durationController = TextEditingController();
  final _renewalWindowController = TextEditingController(text: '3');

  DateTime _startDate = DateTime.now();
  List<String> _availableMedications = [];
  UserModel? _patientData;
  bool _showAllergicWarning = false;
  List<TimeOfDay> _reminderTimes = []; // Danh sách giờ nhậc

  bool get _isEditMode => widget.existingPrescription != null;

  @override
  void initState() {
    super.initState();
    _loadMedications();
    _loadPatientData();
    _initializeFromExisting();
  }

  void _initializeFromExisting() {
    final prescription = widget.existingPrescription;
    if (prescription != null) {
      _medicationNameController.text = prescription.medicationName;
      _concentrationController.text = prescription.concentration ?? '';
      _quantityController.text = prescription.quantity ?? '';
      _dosageController.text = prescription.dosage;
      _routeController.text = prescription.route;
      _timingController.text = prescription.timing ?? '';
      _specialInstructionsController.text =
          prescription.specialInstructions ?? '';
      _durationController.text = prescription.durationDays.toString();
      _renewalWindowController.text = prescription.renewalWindowDays.toString();
      _startDate = prescription.startDate;

      // Load reminder times
      if (prescription.reminderTimes != null) {
        _reminderTimes = prescription.reminderTimes!.map((timeStr) {
          final parts = timeStr.split(':');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }).toList();
      }

      _checkAllergicMedication(prescription.medicationName);
    }
  }

  Future<void> _loadMedications() async {
    final db = MedicationDatabase.instance;
    final medications = await db.getAllMedications();
    setState(() {
      _availableMedications = medications;
    });
  }

  Future<void> _loadPatientData() async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final patient = await repo.getUserById(widget.patientId);
      setState(() {
        _patientData = patient;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  void _checkAllergicMedication(String medicationName) {
    final allergicMeds = _patientData?.allergicMedications ?? [];
    setState(() {
      _showAllergicWarning = allergicMeds.any(
        (med) => med.toLowerCase() == medicationName.toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _medicationNameController.dispose();
    _concentrationController.dispose();
    _quantityController.dispose();
    _dosageController.dispose();
    _routeController.dispose();
    _timingController.dispose();
    _specialInstructionsController.dispose();
    _durationController.dispose();
    _renewalWindowController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(prescriptionViewModelProvider);
    final durationDays = int.parse(_durationController.text);
    final renewalWindowDays = int.parse(_renewalWindowController.text);

    // Convert TimeOfDay to HH:mm string format
    final reminderTimesStr = _reminderTimes.map((time) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }).toList();

    bool success;
    if (_isEditMode) {
      // Update existing prescription
      success = await viewModel.updatePrescription(
        prescriptionId: widget.existingPrescription!.id,
        patientId: widget.patientId,
        medicationName: _medicationNameController.text.trim(),
        concentration: _concentrationController.text.trim(),
        quantity: _quantityController.text.trim(),
        dosage: _dosageController.text.trim(),
        route: _routeController.text.trim(),
        timing: _timingController.text.trim(),
        specialInstructions: _specialInstructionsController.text.trim(),
        startDate: _startDate,
        durationDays: durationDays,
        renewalWindowDays: renewalWindowDays,
        reminderTimes: reminderTimesStr.isNotEmpty ? reminderTimesStr : null,
        currentVersion: widget.existingPrescription!.version,
      );
    } else {
      // Create new prescription
      success = await viewModel.createPrescription(
        patientId: widget.patientId,
        medicationName: _medicationNameController.text.trim(),
        concentration: _concentrationController.text.trim(),
        quantity: _quantityController.text.trim(),
        dosage: _dosageController.text.trim(),
        route: _routeController.text.trim(),
        timing: _timingController.text.trim(),
        specialInstructions: _specialInstructionsController.text.trim(),
        startDate: _startDate,
        durationDays: durationDays,
        renewalWindowDays: renewalWindowDays,
        reminderTimes: reminderTimesStr.isNotEmpty ? reminderTimesStr : null,
      );
    }

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Đã cập nhật chỉ định thuốc thành công'
                  : 'Đã tạo chỉ định thuốc thành công',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${viewModel.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final endDate = _startDate.add(
      Duration(days: int.tryParse(_durationController.text) ?? 0),
    );
    final viewModel = ref.watch(prescriptionViewModelProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode
                          ? 'Chỉnh sửa chỉ định thuốc'
                          : 'Tạo chỉ định thuốc',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _availableMedications.where((medication) {
                            return medication.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          _medicationNameController.text = selection;
                          _checkAllergicMedication(selection);
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              // Sync with our controller
                              controller.text = _medicationNameController.text;
                              controller.addListener(() {
                                _medicationNameController.text =
                                    controller.text;
                                _checkAllergicMedication(controller.text);
                              });
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Tên thuốc *',
                                  hintText: 'Tìm kiếm thuốc',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  errorBorder: _showAllergicWarning
                                      ? const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                        )
                                      : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập tên thuốc';
                                  }
                                  return null;
                                },
                              );
                            },
                      ),
                      if (_showAllergicWarning) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CẢNH BÁO: BỆNH NHÂN DỊ ỨNG!',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bệnh nhân đã khai báo dị ứng với thuốc này. Vui lòng kiểm tra kỹ trước khi kê đơn.',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _concentrationController,
                        decoration: const InputDecoration(
                          labelText: 'Hàm lượng/Nồng độ',
                          hintText: 'VD: 500mg, 10ml',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng',
                          hintText: 'VD: 30 viên, 2 hộp',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Liều dùng *',
                          hintText: 'VD: 1 viên/lần, 2 lần/ngày',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập liều dùng';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _routeController,
                        decoration: const InputDecoration(
                          labelText: 'Đường dùng *',
                          hintText: 'Uống, tiêm, đặt, xịt...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập đường dùng';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _timingController,
                        decoration: const InputDecoration(
                          labelText: 'Thời điểm dùng',
                          hintText: 'Trước ăn, sau ăn, khi đau...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _specialInstructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Lưu ý đặc biệt',
                          hintText: 'VD: Không dùng với sữa, uống nhiều nước',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectStartDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Ngày bắt đầu',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(_startDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Thời hạn sử dụng (ngày) *',
                          hintText: 'VD: 7, 30',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập thời hạn sử dụng';
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) {
                            return 'Vui lòng nhập số ngày hợp lệ';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ngày kết thúc: ${DateFormat('dd/MM/yyyy').format(endDate)}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _renewalWindowController,
                        decoration: const InputDecoration(
                          labelText: 'Cửa sổ gia hạn (ngày) *',
                          hintText: 'Số ngày trước khi hết hạn để thông báo',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {}); // Cập nhật UI khi thay đổi
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập cửa sổ gia hạn';
                          }
                          final renewalDays = int.tryParse(value);
                          if (renewalDays == null || renewalDays < 0) {
                            return 'Vui lòng nhập số ngày hợp lệ';
                          }
                          // Validate: renewalWindowDays phải nhỏ hơn durationDays
                          final durationDays = int.tryParse(
                            _durationController.text,
                          );
                          if (durationDays != null &&
                              renewalDays >= durationDays) {
                            return 'Cửa sổ gia hạn phải nhỏ hơn thời hạn sử dụng ($durationDays ngày)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bệnh nhân sẽ nhận thông báo gia hạn ${_renewalWindowController.text} ngày trước khi hết thuốc',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reminder times section
                      Text(
                        'Giờ nhắc uống thuốc (tùy chọn)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Display selected reminder times
                      if (_reminderTimes.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _reminderTimes.map((time) {
                            return Chip(
                              label: Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              avatar: const Icon(Icons.access_time, size: 18),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _reminderTimes.remove(time);
                                });
                              },
                              backgroundColor: AppColors.primaryColor
                                  .withValues(alpha: 0.1),
                              deleteIconColor: AppColors.primaryColor,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Add reminder time button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            setState(() {
                              // Check if time already exists
                              if (!_reminderTimes.any(
                                (t) =>
                                    t.hour == time.hour &&
                                    t.minute == time.minute,
                              )) {
                                _reminderTimes.add(time);
                                // Sort times
                                _reminderTimes.sort((a, b) {
                                  if (a.hour != b.hour)
                                    return a.hour.compareTo(b.hour);
                                  return a.minute.compareTo(b.minute);
                                });
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.add_alarm),
                        label: Text(
                          _reminderTimes.isEmpty
                              ? 'Thêm giờ nhắc'
                              : 'Thêm giờ nhắc khác',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          side: const BorderSide(color: AppColors.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      if (_reminderTimes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bệnh nhân sẽ nhận ${_reminderTimes.length} thông báo mỗi ngày để nhắc uống thuốc',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: viewModel.isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: viewModel.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _isEditMode
                                    ? 'Cập nhật chỉ định'
                                    : 'Tạo chỉ định',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
