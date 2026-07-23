import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ЗАМЕНИТЕ ЭТОТ URL НА ВАШ АДРЕС ПОСЛЕ РАЗВЕРТЫВАНИЯ БЭКЕНДА В ОБЛАКЕ (например, Render.com)
  static const String productionUrl = 'https://uzdf-1.up.railway.app';


  static String? _resolvedBaseUrl;
  static String? token;
  static final tokenNotifier = ValueNotifier<String?>(null);
  static Map<String, dynamic>? currentUser;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
      tokenNotifier.value = token;
      final userStr = prefs.getString('current_user');
      if (userStr != null) {
        currentUser = jsonDecode(userStr) as Map<String, dynamic>?;
      }
      debugPrint('ApiService init: loaded token: ${token != null ? "YES" : "NO"}');
    } catch (e) {
      debugPrint('ApiService init error: $e');
    }
  }

  static Future<void> saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('auth_token', token!);
      } else {
        await prefs.remove('auth_token');
      }
      tokenNotifier.value = token;
      if (currentUser != null) {
        await prefs.setString('current_user', jsonEncode(currentUser));
      } else {
        await prefs.remove('current_user');
      }
    } catch (e) {
      debugPrint('ApiService saveSession error: $e');
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('current_user');
      token = null;
      tokenNotifier.value = null;
      currentUser = null;
    } catch (e) {
      debugPrint('ApiService clearSession error: $e');
    }
  }

  static Future<String> getBaseUrl() async {
    if (_resolvedBaseUrl != null) return _resolvedBaseUrl!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString('custom_api_url');
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        _resolvedBaseUrl = customUrl.trim();
        debugPrint('Using user-configured API Base URL: $_resolvedBaseUrl');
        return _resolvedBaseUrl!;
      }
    } catch (_) {}

    final candidates = <String>[
      productionUrl,
      'http://190.191.3.112:3000',
      'http://10.0.2.2:3000',
      'http://localhost:3000',
    ];

    final uniqueCandidates = candidates.toSet().toList();
    final completer = Completer<String>();
    int completedCount = 0;

    for (final url in uniqueCandidates) {
      http.get(Uri.parse('$url/news')).timeout(const Duration(seconds: 3)).then((response) {
        if (response.statusCode == 200 && !completer.isCompleted) {
          completer.complete(url);
        }
      }).catchError((_) {
        // Ignore connection errors
      }).whenComplete(() {
        completedCount++;
        if (completedCount == uniqueCandidates.length && !completer.isCompleted) {
          completer.completeError('No host responded');
        }
      });
    }

    try {
      final resolved = await completer.future;
      _resolvedBaseUrl = resolved;
      debugPrint('Successfully resolved API Base URL: $_resolvedBaseUrl');
      return _resolvedBaseUrl!;
    } catch (_) {
      // Default fallback — use production URL for all real devices (iOS and Android)
      // localhost only makes sense in a web browser context
      if (kIsWeb) {
        _resolvedBaseUrl = 'http://localhost:3000';
      } else if (!kIsWeb && Platform.isAndroid) {
        // Android emulator: 10.0.2.2 maps to host machine localhost
        _resolvedBaseUrl = productionUrl;
      } else {
        // iOS real device / iPad — always use production
        _resolvedBaseUrl = productionUrl;
      }
      debugPrint('Fallback API Base URL: $_resolvedBaseUrl');
      return _resolvedBaseUrl!;
    }
  }

  static Future<bool> testAndSetCustomBaseUrl(String url) async {
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    // Remove trailing slash if any
    cleanUrl = cleanUrl.replaceAll(RegExp(r'/$'), '');
    try {
      final response = await http.get(Uri.parse('$cleanUrl/news')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_api_url', cleanUrl);
        _resolvedBaseUrl = cleanUrl;
        return true;
      }
    } catch (e) {
      debugPrint('testAndSetCustomBaseUrl connection error: $e');
    }
    return false;
  }

  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('ApiService.resetBaseUrl: removing custom_api_url');
    final success = await prefs.remove('custom_api_url');
    debugPrint('ApiService.resetBaseUrl: remove success: $success');
    _resolvedBaseUrl = null;
  }

  static Future<List<dynamic>> fetchNews() async {
    try {
      final url = await getBaseUrl();
      final response = await http.get(Uri.parse('$url/news'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchCourses() async {
    try {
      final url = await getBaseUrl();
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(Uri.parse('$url/courses'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchProducts() async {
    try {
      final url = await getBaseUrl();
      final response = await http.get(Uri.parse('$url/products'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchZones() async {
    try {
      final url = await getBaseUrl();
      final response = await http.get(Uri.parse('$url/zones'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching zones: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchProductDetail(int id) async {
    try {
      final url = await getBaseUrl();
      final response = await http.get(Uri.parse('$url/products/$id'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching product detail: $e');
    }
    return null;
  }

  static Future<bool> login(String email, String password) async {
    try {
      final url = await getBaseUrl();
      debugPrint('Login attempt to: $url/auth/login');
      final response = await http.post(
        Uri.parse('$url/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('Login response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'];
        currentUser = data['user'] as Map<String, dynamic>?;
        await saveSession();
        return true;
      } else {
        debugPrint('Login error body: ${response.body}');
      }
    } on SocketException catch (e) {
      debugPrint('Login SocketException (no network/server unreachable): $e');
      // Reset cached URL so next attempt re-discovers
      _resolvedBaseUrl = null;
    } on TimeoutException catch (e) {
      debugPrint('Login TimeoutException: $e');
      _resolvedBaseUrl = null;
    } catch (e) {
      debugPrint('Login error: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>?> register(String name, String email, String password, String phone) async {
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password, 'phone': phone}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        try {
          final errData = jsonDecode(response.body);
          if (errData is Map && errData.containsKey('error')) {
            return {'error': errData['error']};
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Register error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> verifyCode(String email, String code) async {
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        token = data['token'];
        currentUser = data['user'] as Map<String, dynamic>?;
        await saveSession();
        return {'success': true};
      } else {
        if (data is Map && data.containsKey('error')) {
          return {'error': data['error']};
        }
      }
    } catch (e) {
      debugPrint('VerifyCode error: $e');
    }
    return null;
  }

  static Future<bool> loginWithGoogle(String name, String email) async {
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'];
        currentUser = data['user'] as Map<String, dynamic>?;
        await saveSession();
        return true;
      }
    } catch (e) {
      debugPrint('Google Login error: $e');
    }
    return false;
  }

  static Future<bool> loginWithGoogleReal(String idToken) async {
    try {
      final url = await getBaseUrl();
      debugPrint('Google login attempt to: $url/auth/google-real');
      final response = await http.post(
        Uri.parse('$url/auth/google-real'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      ).timeout(const Duration(seconds: 15));
      debugPrint('Google login response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'];
        currentUser = data['user'] as Map<String, dynamic>?;
        await saveSession();
        return true;
      } else {
        debugPrint('Google login error body: ${response.body}');
      }
    } on SocketException catch (e) {
      debugPrint('Google login SocketException: $e');
      _resolvedBaseUrl = null;
    } on TimeoutException catch (e) {
      debugPrint('Google login TimeoutException: $e');
    } catch (e) {
      debugPrint('Google Real Login error: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>?> fetchProfile() async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$url/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        currentUser = jsonDecode(response.body) as Map<String, dynamic>?;
        await saveSession();
        return currentUser;
      }
    } catch (e) {
      debugPrint('Fetch profile error: $e');
    }
    return null;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (token == null) return false;
    try {
      final url = await getBaseUrl();
      final response = await http.put(
        Uri.parse('$url/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        currentUser = jsonDecode(response.body) as Map<String, dynamic>?;
        await saveSession();
        return true;
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    if (token == null) return {'error': 'Not authorized'};
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'error': data['error'] ?? 'Ошибка при смене пароля'};
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      return {'error': e.toString()};
    }
  }

  static Future<bool> sendSupportRequest(String message) async {
    try {
      final url = await getBaseUrl();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.post(
        Uri.parse('$url/support'),
        headers: headers,
        body: jsonEncode({'message': message}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending support request: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>?> completeStep(int stepId, int answer) async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/courses/steps/$stepId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'answer': answer}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('currentExp') && currentUser != null) {
          currentUser!['exp'] = data['currentExp'];
          currentUser!['level'] = data['currentLevel'];
          // Merge achievements if present
          if (data.containsKey('newlyUnlocked')) {
            final list = currentUser!['achievements'] as List<dynamic>? ?? [];
            final newly = data['newlyUnlocked'] as List<dynamic>;
            for (var achId in newly) {
              if (!list.any((a) => a['achievementId'] == achId)) {
                list.add({'achievementId': achId, 'unlockedAt': DateTime.now().toIso8601String()});
              }
            }
            currentUser!['achievements'] = list;
          }
          await saveSession();
        }
        return data;
      }
    } catch (e) {
      debugPrint('Error completing step: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> startStep(int stepId) async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/courses/steps/$stepId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      } else {
        return {'error': data['error'] ?? 'Ошибка запуска урока'};
      }
    } catch (e) {
      debugPrint('Error starting step: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> completeStepSecure({
    required int stepId,
    required bool scrollCompleted,
    required int timeSpentSeconds,
  }) async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/courses/steps/$stepId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'scrollCompleted': scrollCompleted,
          'timeSpentSeconds': timeSpentSeconds,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (data.containsKey('currentExp') && currentUser != null) {
          currentUser!['exp'] = data['currentExp'];
          currentUser!['level'] = data['currentLevel'];
          if (data.containsKey('newlyUnlocked')) {
            final list = currentUser!['achievements'] as List<dynamic>? ?? [];
            final newly = data['newlyUnlocked'] as List<dynamic>;
            for (var achId in newly) {
              if (!list.any((a) => a['achievementId'] == achId)) {
                list.add({'achievementId': achId, 'unlockedAt': DateTime.now().toIso8601String()});
              }
            }
            currentUser!['achievements'] = list;
          }
          await saveSession();
        }
        return data;
      } else {
        return {'error': data['error'] ?? 'Ошибка завершения шага'};
      }
    } catch (e) {
      debugPrint('Error completing step secure: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchQuiz(int stepId) async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$url/courses/steps/$stepId/quiz'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      } else {
        return {'error': data['error'] ?? 'Ошибка получения вопросов квиза'};
      }
    } catch (e) {
      debugPrint('Error fetching quiz: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> submitQuiz(int stepId, List<Map<String, dynamic>> answers) async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/courses/steps/$stepId/quiz-submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'answers': answers}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (currentUser != null) {
          if (data.containsKey('courseLives')) {
            currentUser!['courseLives'] = data['courseLives'];
          }
          if (data.containsKey('currentExp')) {
            currentUser!['exp'] = data['currentExp'];
            currentUser!['level'] = data['currentLevel'];
          }
          if (data.containsKey('newlyUnlocked')) {
            final list = currentUser!['achievements'] as List<dynamic>? ?? [];
            final newly = data['newlyUnlocked'] as List<dynamic>;
            for (var achId in newly) {
              if (!list.any((a) => a['achievementId'] == achId)) {
                list.add({'achievementId': achId, 'unlockedAt': DateTime.now().toIso8601String()});
              }
            }
            currentUser!['achievements'] = list;
          }
          await saveSession();
        }
        return data;
      } else {
        return {'error': data['error'] ?? 'Ошибка сдачи квиза'};
      }
    } catch (e) {
      debugPrint('Error submitting quiz: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> logViolation(int stepId) async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/courses/steps/$stepId/violation'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error logging violation: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> triggerWeatherCheck() async {
    if (token == null) return null;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/users/action/trigger-weather'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('currentExp') && currentUser != null) {
          currentUser!['exp'] = data['currentExp'];
          currentUser!['level'] = data['currentLevel'];
          if (data.containsKey('newlyUnlocked')) {
            final list = currentUser!['achievements'] as List<dynamic>? ?? [];
            final newly = data['newlyUnlocked'] as List<dynamic>;
            for (var achId in newly) {
              if (!list.any((a) => a['achievementId'] == achId)) {
                list.add({'achievementId': achId, 'unlockedAt': DateTime.now().toIso8601String()});
              }
            }
            currentUser!['achievements'] = list;
          }
          await saveSession();
        }
        return data;
      }
    } catch (e) {
      debugPrint('Error triggering weather check: $e');
    }
    return null;
  }

  /// Fetch current user's orders from backend
  static Future<List<dynamic>> fetchMyOrders() async {
    if (token == null) return [];
    try {
      final url = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$url/orders/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchCompletions() async {
    if (token == null) return [];
    try {
      final url = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$url/courses/completions/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching completions: $e');
    }
    return [];
  }

  /// Save delivery address for an order
  static Future<bool> updateOrderDelivery(int orderId, String address, String city, String contact) async {
    if (token == null) return false;
    try {
      final url = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$url/orders/$orderId/delivery'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'deliveryAddress': address, 'deliveryCity': city, 'deliveryContact': contact}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating delivery: $e');
    }
    return false;
  }

  /// Open Telegram support bot
  static String get telegramBotUrl => 'https://t.me/uzdf_support_bot';
}

