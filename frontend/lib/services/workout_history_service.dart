import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/run_history_item.dart';
import '../models/workout_history.dart';
import 'run_analysis_service.dart';

abstract interface class WorkoutHistoryStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesWorkoutStorage implements WorkoutHistoryStorage {
  SharedPreferencesWorkoutStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'runcoach.workout_history.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(_storageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(_storageKey, value);
}

class MemoryWorkoutStorage implements WorkoutHistoryStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class WorkoutHistoryService extends ChangeNotifier {
  WorkoutHistoryService({
    WorkoutHistoryStorage? storage,
    RunAnalysisService? historyApi,
    String language = 'en',
  })  : _storage = storage ?? SharedPreferencesWorkoutStorage(),
        _historyApi = historyApi,
        _language = language;

  final WorkoutHistoryStorage _storage;
  RunAnalysisService? _historyApi;
  String _language;
  List<WorkoutHistory> _workouts = const [];
  bool _isLoaded = false;
  String? _loadError;
  bool _isSyncedWithServer = false;

  List<WorkoutHistory> get workouts => List.unmodifiable(_workouts);
  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;
  bool get isSyncedWithServer => _isSyncedWithServer;

  void configureRemote({
    required RunAnalysisService historyApi,
    required String language,
  }) {
    _historyApi = historyApi;
    _language = language;
  }

  // Computed stats
  double get totalDistanceKm =>
      _workouts.fold(0, (sum, w) => sum + w.distanceKm);

  int get totalTimeSeconds =>
      _workouts.fold(0, (sum, w) => sum + w.timeSeconds);

  double get averagePaceMinPerKm {
    if (_workouts.isEmpty) return 0;
    final totalDistance = _workouts.fold(0.0, (sum, w) => sum + w.distanceKm);
    if (totalDistance == 0) return 0;
    final totalTime = _workouts.fold(0, (sum, w) => sum + w.timeSeconds);
    return (totalTime / 60.0) / totalDistance;
  }

  int get totalWorkouts => _workouts.length;

  Future<void> load() async {
    _loadError = null;
    try {
      final remoteRuns = await _fetchRemoteRuns();
      if (remoteRuns != null) {
        await _save(
          remoteRuns.map(_workoutFromRun).toList(growable: false),
          notify: false,
        );
        _isSyncedWithServer = true;
        return;
      }

      final stored = await _storage.read();
      if (stored != null) {
        final decoded = jsonDecode(stored);
        if (decoded is! List) {
          throw const FormatException(
              'Stored workout history has invalid shape.');
        }
        _workouts = decoded.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Stored workout entry is invalid.');
          }
          return WorkoutHistory.fromJson(item);
        }).toList(growable: false);
        // Sort by date descending (newest first)
        _workouts.sort((a, b) => b.date.compareTo(a.date));
      }
      _isSyncedWithServer = false;
    } on Exception catch (error) {
      _loadError = error.toString();
      _isSyncedWithServer = false;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> addWorkout({
    required double distanceKm,
    required int timeSeconds,
  }) async {
    if (!distanceKm.isFinite || distanceKm <= 0) {
      throw ArgumentError.value(
        distanceKm,
        'distanceKm',
        'Run distance must be greater than zero.',
      );
    }
    if (timeSeconds <= 0) {
      throw ArgumentError.value(
        timeSeconds,
        'timeSeconds',
        'Run time must be greater than zero.',
      );
    }

    final paceMinPerKm = (timeSeconds / 60.0) / distanceKm;

    final workout = WorkoutHistory(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      distanceKm: distanceKm,
      timeSeconds: timeSeconds,
      paceMinPerKm: paceMinPerKm,
    );

    final updated = [workout, ..._workouts];
    await _save(updated);
    _isSyncedWithServer = false;
  }

  Future<void> removeWorkout(String id) async {
    if (_isSyncedWithServer && _historyApi != null) {
      await _historyApi!.deleteRun(id);
    }
    final updated = _workouts.where((w) => w.id != id).toList();
    if (updated.length == _workouts.length) return;
    await _save(updated);
  }

  Future<void> clearHistory() async {
    _isSyncedWithServer = false;
    await _save(const []);
  }

  Future<void> _save(
    List<WorkoutHistory> workouts, {
    bool notify = true,
  }) async {
    await _storage.write(
      jsonEncode(
        workouts.map((w) => w.toJson()).toList(growable: false),
      ),
    );
    _workouts = List.unmodifiable(workouts);
    if (notify) notifyListeners();
  }

  Future<List<RunHistoryItem>?> _fetchRemoteRuns() async {
    final historyApi = _historyApi;
    if (historyApi == null) return null;
    try {
      return await historyApi.fetchRecentRuns(language: _language);
    } on RunAnalysisException catch (error) {
      _loadError = error.message;
      return null;
    }
  }

  WorkoutHistory _workoutFromRun(RunHistoryItem run) {
    return WorkoutHistory(
      id: run.id,
      date: run.date,
      distanceKm: run.distanceKm,
      timeSeconds: run.timeSeconds,
      paceMinPerKm: (run.timeSeconds / 60.0) / run.distanceKm,
    );
  }
}
