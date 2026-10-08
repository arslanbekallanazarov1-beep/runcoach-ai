import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';
import 'run_analysis_service.dart';

class AuthService {
  AuthService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = RunAnalysisService.normalizeBaseUrl(
          baseUrl ?? RunAnalysisService.baseUrl,
        );

  static const _tokenKey = 'runcoach.auth.token';
  static const _userKey = 'runcoach.auth.user';

  final http.Client _client;
  final String _baseUrl;

  AuthUser? _user;
  String? _accessToken;

  AuthUser? get currentUser => _user;
  String? get accessToken => _accessToken;

  void close() => _client.close();

  Future<AuthUser?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final encodedUser = preferences.getString(_userKey);
    if (token == null && encodedUser == null) return null;
    if (token == null || encodedUser == null) {
      throw const AuthException('The saved sign-in session is incomplete.');
    }
    final decoded = jsonDecode(encodedUser);
    if (decoded is! Map<String, dynamic>) {
      throw const AuthException('The saved account data is invalid.');
    }
    _user = AuthUser.fromJson(decoded);
    _accessToken = token;
    return _user;
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) =>
      _authenticate(
        endpoint: '/api/v1/auth/login',
        payload: {'email': email.trim(), 'password': password},
      );

  Future<AuthUser> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) =>
      _authenticate(
        endpoint: '/api/v1/auth/register',
        payload: {
          'email': email.trim(),
          'password': password,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        },
      );

  Future<AuthUser> updateProfile({
    String? firstName,
    String? lastName,
    String? goal,
    String? experienceLevel,
    double? weeklyMileageKm,
    int? maxHr,
    bool clearMaxHr = false,
    int? age,
    bool clearAge = false,
    List<String>? availableTrainingDays,
  }) async {
    late final http.Response response;
    try {
      final payload = <String, Object?>{};
      if (firstName != null) payload['first_name'] = firstName.trim();
      if (lastName != null) payload['last_name'] = lastName.trim();
      if (goal != null) payload['goal'] = goal.trim();
      if (experienceLevel != null) {
        payload['experience_level'] = experienceLevel;
      }
      if (weeklyMileageKm != null) {
        payload['weekly_mileage_km'] = weeklyMileageKm;
      }
      if (maxHr != null || clearMaxHr) payload['max_hr'] = maxHr;
      if (age != null || clearAge) payload['age'] = age;
      if (availableTrainingDays != null) {
        payload['available_training_days'] = availableTrainingDays.join(',');
      }
      response = await _client
          .patch(
            Uri.parse('$_baseUrl/api/v1/profile'),
            headers: await _headers(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (error) {
      throw AuthException('Could not reach the RunCoach server.', cause: error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        'Could not update profile (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['user'] is! Map<String, dynamic>) {
        throw const FormatException('Expected an account object.');
      }
      final user = AuthUser.fromJson(decoded['user'] as Map<String, dynamic>);
      await _saveSession(user, _accessToken ?? '');
      _user = user;
      return user;
    } on FormatException catch (error) {
      throw AuthException('The server returned invalid account data.',
          cause: error);
    }
  }

  Future<Map<String, Map<String, int>>> fetchHeartRateZones() async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$_baseUrl/api/v1/heart-rate-zones'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));
    } on Exception catch (error) {
      throw AuthException('Could not load heart rate zones.', cause: error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        'Could not load heart rate zones (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['zones'] is! List) {
        throw const FormatException('Expected a list of heart rate zones.');
      }
      final zones = <String, Map<String, int>>{};
      for (final value in decoded['zones'] as List) {
        if (value is! Map<String, dynamic> ||
            value['zone'] is! String ||
            value['min_bpm'] is! num ||
            value['max_bpm'] is! num) {
          throw const FormatException('A heart rate zone has invalid fields.');
        }
        zones[value['zone'] as String] = {
          'min': (value['min_bpm'] as num).toInt(),
          'max': (value['max_bpm'] as num).toInt(),
        };
      }
      return zones;
    } on FormatException catch (error) {
      throw AuthException(
        'The server returned invalid heart rate zones.',
        cause: error,
      );
    }
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    final tokenRemoved = await preferences.remove(_tokenKey);
    final userRemoved = await preferences.remove(_userKey);
    if (!tokenRemoved || !userRemoved) {
      throw const AuthException('Could not clear the saved sign-in session.');
    }
    _accessToken = null;
    _user = null;
  }

  Future<AuthUser> _authenticate({
    required String endpoint,
    required Map<String, Object> payload,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (error) {
      throw AuthException('Could not reach the RunCoach server.', cause: error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        'Authentication failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['user'] is! Map<String, dynamic> ||
          decoded['token'] is! String ||
          (decoded['token'] as String).isEmpty) {
        throw const FormatException('Expected an account and access token.');
      }
      final user = AuthUser.fromJson(decoded['user'] as Map<String, dynamic>);
      final token = decoded['token'] as String;
      await _saveSession(user, token);
      _user = user;
      _accessToken = token;
      return user;
    } on FormatException catch (error) {
      throw AuthException('The server returned invalid account data.',
          cause: error);
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> _saveSession(AuthUser user, String token) async {
    final preferences = await SharedPreferences.getInstance();
    final tokenSaved = await preferences.setString(_tokenKey, token);
    final userSaved = await preferences.setString(
      _userKey,
      jsonEncode(user.toJson()),
    );
    if (!tokenSaved || !userSaved) {
      await preferences.remove(_tokenKey);
      await preferences.remove(_userKey);
      throw const AuthException('Could not save the sign-in session.');
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
