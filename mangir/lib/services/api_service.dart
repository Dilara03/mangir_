import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Geliştirme ortamı için emulator adresi
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // ============================================
  // TOKEN YÖNETİMİ
  // ============================================

  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // Token ile header oluştur
  static Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // AUTH ENDPOİNTS
  // ============================================

  static Future<Map<String, dynamic>> register({
    required String email,
    required String fullName,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'full_name': fullName,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Kayıt başarısız',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access_token'], data['refresh_token']);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Giriş başarısız',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        return {'success': false, 'message': 'Refresh token bulunamadı'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access_token'], data['refresh_token']);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Token yenileme başarısız'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        // Token expired, try refresh
        final refreshResult = await refreshAccessToken();
        if (refreshResult['success']) {
          return getCurrentUser(); // Retry
        }
        return {'success': false, 'message': 'Oturum süresi doldu'};
      } else {
        return {'success': false, 'message': 'Kullanıcı bilgisi alınamadı'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? profileImage,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {'full_name': fullName};
      if (profileImage != null) {
        body['profile_image'] = profileImage;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Profil güncellenemedi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Şifre başarıyla değiştirildi'};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Şifre değiştirilemedi',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password?email=$email'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'İşlem başarısız'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'reset_code': resetCode,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'İşlem başarısız',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<void> logout() async {
    await clearTokens();
  }

  // ============================================
  // CATEGORY ENDPOİNTS
  // ============================================

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Kategoriler alınamadı'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> seedCategories() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/categories/seed'));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Kategoriler eklenemedi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  // ============================================
  // TRANSACTION ENDPOİNTS
  // ============================================

  static Future<Map<String, dynamic>> createTransaction({
    required int categoryId,
    required double amount,
    required String transactionDate,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: headers,
        body: jsonEncode({
          'category_id': categoryId,
          'amount': amount,
          'transaction_date': transactionDate,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'İşlem eklenemedi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTransactions({
    int skip = 0,
    int limit = 100,
    int? year,
    int? month,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/transactions?skip=$skip&limit=$limit';

      // Ay filtresi ekle
      if (year != null && month != null) {
        url += '&year=$year&month=$month';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        final refreshResult = await refreshAccessToken();
        if (refreshResult['success']) {
          return getTransactions(
            skip: skip,
            limit: limit,
            year: year,
            month: month,
          );
        }
        return {'success': false, 'message': 'Oturum süresi doldu'};
      } else {
        return {'success': false, 'message': 'İşlemler alınamadı'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateTransaction({
    required int transactionId,
    required int categoryId,
    required double amount,
    required String transactionDate,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/transactions/$transactionId'),
        headers: headers,
        body: jsonEncode({
          'category_id': categoryId,
          'amount': amount,
          'transaction_date': transactionDate,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'İşlem güncellenemedi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTransaction(
    int transactionId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/transactions/$transactionId'),
        headers: headers,
      );

      if (response.statusCode == 204) {
        return {'success': true, 'message': 'İşlem silindi'};
      } else {
        return {'success': false, 'message': 'İşlem silinemedi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  // ============================================
  // STATİSTİCS ENDPOİNTS
  // ============================================

  static Future<Map<String, dynamic>> getPeriodStats({
    String period = 'monthly', // weekly, monthly, yearly
    int? year,
    int? month,
    String? weekStart,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/stats/period?period=$period';

      if (year != null && month != null) {
        url += '&year=$year&month=$month';
      } else if (year != null) {
        url += '&year=$year';
      }

      if (weekStart != null) {
        url += '&week_start=$weekStart';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'İstatistikler alınamadı'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  static Future<Map<String, dynamic>> getStatsByCategoryPeriod({
    String period = 'monthly',
    int? year,
    int? month,
    String? weekStart,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/stats/by-category-period?period=$period';

      if (year != null && month != null) {
        url += '&year=$year&month=$month';
      } else if (year != null) {
        url += '&year=$year';
      }

      if (weekStart != null) {
        url += '&week_start=$weekStart';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'İstatistikler alınamadı'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }
}
