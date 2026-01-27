import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailController.text.isEmpty) {
      _showError('Lütfen email adresinizi girin');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.forgotPassword(_emailController.text);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _codeSent = true;
        });
      } else {
        _showError(result['message'] ?? 'Kod gönderilemedi');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.isEmpty || _newPasswordController.text.isEmpty) {
      _showError('Lütfen tüm alanları doldurun');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showError('Şifre en az 6 karakter olmalı');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.resetPassword(
        email: _emailController.text,
        resetCode: _codeController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['data']['message'] ?? 'Şifre başarıyla sıfırlandı',
            ), // ✅ data içindeki message
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        final errorMessage = result['message'];
        if (errorMessage is List) {
          _showError(errorMessage.first ?? 'Şifre sıfırlanamadı');
        } else if (errorMessage is String) {
          _showError(errorMessage);
        } else {
          _showError('Şifre sıfırlanamadı');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Şifremi Unuttum',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),

            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF5B8DEF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 50,
                color: Color(0xFF5B8DEF),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Şifrenizi mi unuttunuz?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Email adresinize sıfırlama kodu göndereceğiz',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF7A8B9A)),
            ),

            const SizedBox(height: 40),

            // Email Field
            TextField(
              controller: _emailController,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'E-Mail',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: _codeSent ? Colors.grey[200] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF5B8DEF)),
                ),
              ),
            ),

            if (_codeSent) ...[
              const SizedBox(height: 16),

              // Code Field
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Sıfırlama Kodu (6 haneli)',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5B8DEF)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // New Password Field
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Yeni Şifre (en az 6 karakter)',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5B8DEF)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Button
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_codeSent ? _resetPassword : _sendCode),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8DEF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                disabledBackgroundColor: Colors.grey[400],
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _codeSent ? 'Şifreyi Sıfırla' : 'Kod Gönder',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            if (_codeSent) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _codeSent = false;
                      _codeController.clear();
                      _newPasswordController.clear();
                    });
                  },
                  child: const Text(
                    'Farklı email ile dene',
                    style: TextStyle(color: Color(0xFF5B8DEF)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
