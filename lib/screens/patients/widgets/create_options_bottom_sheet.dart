import 'package:flutter/material.dart';
import '../../../data/resources/gene/app_colors.dart';
import 'create_prescription_bottom_sheet.dart';

class CreateOptionsBottomSheet extends StatelessWidget {
  final VoidCallback onCreateCarePlan;
  final String patientId;

  const CreateOptionsBottomSheet({
    super.key,
    required this.onCreateCarePlan,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(
              Icons.medication,
              color: AppColors.primaryColor,
            ),
            title: const Text('Tạo chỉ định thuốc'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    CreatePrescriptionBottomSheet(patientId: patientId),
              );
            },
          ),
        ],
      ),
    );
  }
}
