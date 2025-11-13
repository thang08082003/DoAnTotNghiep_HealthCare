import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/orders/doctor_orders_view_model.dart';
import '../../data/models/doctor_order.dart';
import '../../data/resources/gene/app_colors.dart';

class PatientOrdersListScreen extends ConsumerWidget {
  final String patientId;
  final String doctorId;
  const PatientOrdersListScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersVm = ref.watch(doctorOrdersViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả chỉ định'), centerTitle: true),
      body: StreamBuilder<List<DoctorOrder>>(
        stream: ordersVm.watchOrders(patientId: patientId, doctorId: doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data ?? const <DoctorOrder>[];
          if (orders.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: orders.length,
            itemBuilder: (context, index) => _OrderTile(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final DoctorOrder order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final created = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}'
        : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((order.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.notes!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                if (created.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    created,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Chưa có chỉ định nào'),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Khi bác sĩ tạo chỉ định, nội dung sẽ hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
