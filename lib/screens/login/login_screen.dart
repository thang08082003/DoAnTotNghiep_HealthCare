import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import 'package:healthcare/data/resources/gene/app_text_styles.dart';
import 'package:healthcare/data/resources/gene/app_dimensions.dart';
import 'package:healthcare/router/app_router.dart';

import 'package:healthcare/screens/home/home_page.dart';
import 'package:healthcare/data/models/user_model.dart';
import '../../components/buttons/index.dart';
import '../../viewmodels/auth/auth_view_model.dart';
import '../../viewmodels/auth/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _navigated = false; // tránh điều hướng lặp lại trong một phiên đăng nhập

  // Note: Do not use ref.listen in initState (Riverpod restriction). We'll listen in build.

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authViewModelProvider.notifier)
        .login(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(authViewModelProvider);

    // Listen to auth state changes (safe inside build)
    ref.listen<AuthViewState>(authViewModelProvider, (previous, next) async {
      if ((next.error ?? '').isNotEmpty && next.error != previous?.error) {
        // Reset navigation flag when there's an error
        _navigated = false;
        if (mounted) _showSnackBar(next.error!);
        ref.read(authViewModelProvider.notifier).clearError();
        return; // Don't proceed with navigation
      }
      final readyToNavigate =
          next.isAuthenticated == true && !next.isLoading && next.uid != null;
      if (!_navigated && readyToNavigate) {
        if (!mounted) return;
        _navigated = true;
        if (next.needsSetup) {
          AppRouter.pushUserSetup(
            context,
            uid: next.uid!,
            email: next.email ?? '',
          );
        } else {
          final role = next.role ?? UserRole.patient;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomePage(userRole: role)),
            (route) => false,
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppDimensions.paddingAllLarge,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: AppDimensions.borderRadiusLarge,
              ),
              child: Padding(
                padding: AppDimensions.paddingAllLarge,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_hospital,
                        size: 80,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(height: AppDimensions.spacingMedium),
                      Text('Đăng Nhập', style: AppTextStyles.heading1),
                      SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        'Chào mừng bạn trở lại!',
                        style: AppTextStyles.body1Secondary,
                      ),
                      SizedBox(height: AppDimensions.spacingXLarge),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: AppDimensions.borderRadiusMedium,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppDimensions.borderRadiusMedium,
                            borderSide: const BorderSide(
                              color: AppColors.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppDimensions.spacingMedium),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppDimensions.borderRadiusMedium,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppDimensions.borderRadiusMedium,
                            borderSide: const BorderSide(
                              color: AppColors.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (value.length < 6) {
                            return 'Mật khẩu phải có ít nhất 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppDimensions.spacingSmall),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/forgot-password');
                          },
                          child: Text(
                            'Quên mật khẩu?',
                            style: AppTextStyles.body2Bold.copyWith(
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppDimensions.spacingMedium),

                      // Login button
                      PrimaryButton(
                        text: 'Đăng Nhập',
                        onPressed: _login,
                        isLoading: vmState.isLoading,
                      ),
                      SizedBox(height: AppDimensions.spacingMedium),

                      // Register link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: AppTextStyles.body2Secondary,
                          ),
                          TextButton(
                            onPressed: () {
                              AppRouter.pushRegister(context);
                            },
                            child: Text(
                              'Đăng ký ngay',
                              style: AppTextStyles.body2Bold.copyWith(
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
