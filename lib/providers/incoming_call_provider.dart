import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/call_session.dart';
import 'user_provider.dart';

/// Provider that watches for incoming calls for the current user
/// Returns the latest ringing call session or null
final incomingCallProvider = StreamProvider.autoDispose<CallSession?>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);

  return currentUserAsync.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }

      // Listen to call_sessions where current user is the callee and status is ringing
      return FirebaseFirestore.instance
          .collection('call_sessions')
          .where('calleeId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'ringing')
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) return null;

            // Return the most recent ringing call
            final sorted = snapshot.docs.toList()
              ..sort((a, b) {
                final aTime =
                    (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime(2000);
                final bTime =
                    (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime(2000);
                return bTime.compareTo(aTime);
              });

            return CallSession.fromDoc(sorted.first);
          });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});
