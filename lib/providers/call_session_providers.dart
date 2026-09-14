import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/repositories/call_sessions_repository.dart';

final callSessionsRepositoryProvider = Provider<CallSessionsRepository>((ref) {
  return CallSessionsRepository(FirebaseFirestore.instance);
});
