import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';
import 'auth_provider.dart';

// User Repository Provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// Current User Provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authProvider);
  
  if (!authState.isAuthenticated || authState.uid == null) {
    return null;
  }

  final userRepository = ref.watch(userRepositoryProvider);
  return await userRepository.getUserById(authState.uid!);
});

// User State Provider
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return UserNotifier(userRepository);
});

// User State
class UserState {
  final bool isLoading;
  final UserModel? currentUser;
  final List<UserModel> doctors;
  final List<UserModel> patients;
  final String? errorMessage;

  const UserState({
    this.isLoading = false,
    this.currentUser,
    this.doctors = const [],
    this.patients = const [],
    this.errorMessage,
  });

  UserState copyWith({
    bool? isLoading,
    UserModel? currentUser,
    List<UserModel>? doctors,
    List<UserModel>? patients,
    String? errorMessage,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser ?? this.currentUser,
      doctors: doctors ?? this.doctors,
      patients: patients ?? this.patients,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// User Notifier
class UserNotifier extends StateNotifier<UserState> {
  final UserRepository _userRepository;

  UserNotifier(this._userRepository) : super(const UserState());

  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
    String? diseaseFocus,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      await _userRepository.createUser(
        uid: uid,
        name: name,
        email: email,
        role: role,
        diseaseFocus: diseaseFocus,
      );
      
      // Refresh current user
      await loadCurrentUser(uid);
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadCurrentUser(String uid) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final user = await _userRepository.getUserById(uid);
      state = state.copyWith(
        isLoading: false,
        currentUser: user,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadDoctors() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final doctors = await _userRepository.getUsersByRole(UserRole.doctor);
      state = state.copyWith(
        isLoading: false,
        doctors: doctors,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadPatients() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final patients = await _userRepository.getUsersByRole(UserRole.patient);
      state = state.copyWith(
        isLoading: false,
        patients: patients,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateUser(UserModel user) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      await _userRepository.updateUser(user);
      state = state.copyWith(
        isLoading: false,
        currentUser: user,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}