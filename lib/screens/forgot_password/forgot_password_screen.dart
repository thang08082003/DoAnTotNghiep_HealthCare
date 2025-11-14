import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import '../../components/buttons/primary_button.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
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

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text.trim());

      setState(() {
        _isLoading = false;
        _emailSent = true;
      });

      if (mounted) {
        _showSnackBar('Email đặt lại mật khẩu đã được gửi!', isError: false);
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        String errorMessage = 'Đã có lỗi xảy ra';
        if (e.toString().contains('user-not-found')) {
          errorMessage = 'Email không tồn tại';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Email không hợp lệ';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Quá nhiều yêu cầu, vui lòng thử lại sau';
        }
        _showSnackBar(errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Quên Mật Khẩu'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _emailSent ? _buildSuccessView() : _buildFormView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_reset, size: 80, color: AppColors.primaryColor),
          const SizedBox(height: 16),
          const Text(
            'Đặt Lại Mật Khẩu',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập email của bạn để nhận link đặt lại mật khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 24),

          // Send button
          PrimaryButton(
            text: 'Gửi Email',
            onPressed: _sendResetEmail,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          // Back to login link
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Quay lại đăng nhập',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read, size: 80, color: AppColors.success),
        const SizedBox(height: 16),
        const Text(
          'Email Đã Được Gửi!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chúng tôi đã gửi link đặt lại mật khẩu đến\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        const Text(
          'Vui lòng kiểm tra email của bạn và làm theo hướng dẫn để đặt lại mật khẩu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        // Back to login button
        PrimaryButton(
          text: 'Quay Lại Đăng Nhập',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 16),

        // Resend email link
        TextButton(
          onPressed: () {
            setState(() => _emailSent = false);
          },
          child: const Text(
            'Gửi lại email',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
