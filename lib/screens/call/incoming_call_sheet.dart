import 'package:flutter/material.dart';

class IncomingCallSheet extends StatelessWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const IncomingCallSheet({
    super.key,
    required this.callerName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cuộc gọi đến',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 34,
                child: Text(
                  callerName.isNotEmpty
                      ? callerName.substring(0, 1).toUpperCase()
                      : '?',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                callerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: onAccept,
                    icon: const Icon(Icons.call),
                    label: const Text('Chấp nhận'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: onDecline,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Từ chối'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
