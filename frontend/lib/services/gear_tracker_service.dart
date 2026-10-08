import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/running_shoes.dart';

abstract interface class GearStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesGearStorage implements GearStorage {
  SharedPreferencesGearStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'runcoach.running_shoes.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(_storageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(_storageKey, value);
}

class MemoryGearStorage implements GearStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class GearTrackerService extends ChangeNotifier {
  GearTrackerService({GearStorage? storage})
      : _storage = storage ?? SharedPreferencesGearStorage();

  final GearStorage _storage;
  List<RunningShoes> _shoes = const [];
  String? _selectedShoeId;
  bool _isLoaded = false;
  String? _loadError;

  List<RunningShoes> get shoes => List.unmodifiable(_shoes);
  String? get selectedShoeId => _selectedShoeId;
  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;
  RunningShoes? get selectedShoe => _findShoe(_selectedShoeId);

  Future<void> load() async {
    _loadError = null;
    try {
      final stored = await _storage.read();
      if (stored != null) {
        final decoded = jsonDecode(stored);
        if (decoded is! Map<String, dynamic> ||
            decoded['shoes'] is! List ||
            (decoded['selected_shoe_id'] != null &&
                decoded['selected_shoe_id'] is! String)) {
          throw const FormatException('Stored shoe data has an invalid shape.');
        }
        final shoes = (decoded['shoes'] as List).map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Stored shoe entry is invalid.');
          }
          return RunningShoes.fromJson(item);
        }).toList(growable: false);
        final selectedId = decoded['selected_shoe_id'] as String?;
        _shoes = shoes;
        _selectedShoeId =
            shoes.any((shoe) => shoe.id == selectedId) ? selectedId : null;
      }
    } on Exception catch (error) {
      _loadError = error.toString();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> addShoe({
    required String name,
    double startingKilometers = 0,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Shoe name cannot be empty.');
    }
    if (!startingKilometers.isFinite || startingKilometers < 0) {
      throw ArgumentError.value(
        startingKilometers,
        'startingKilometers',
        'Starting mileage must be a non-negative number.',
      );
    }
    final shoe = RunningShoes(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: normalizedName,
      totalKilometers: startingKilometers,
    );
    final updated = [..._shoes, shoe];
    await _save(updated, _selectedShoeId ?? shoe.id);
  }

  Future<void> selectShoe(String? shoeId) async {
    if (shoeId != null && !_shoes.any((shoe) => shoe.id == shoeId)) {
      throw ArgumentError.value(shoeId, 'shoeId', 'Shoe does not exist.');
    }
    await _save(_shoes, shoeId);
  }

  Future<RunningShoes?> recordRunDistance(
    double distanceKm, {
    String? shoeId,
  }) async {
    if (!distanceKm.isFinite || distanceKm <= 0) {
      throw ArgumentError.value(
        distanceKm,
        'distanceKm',
        'Run distance must be greater than zero.',
      );
    }
    final selectedId = shoeId ?? _selectedShoeId;
    final shoe = _findShoe(selectedId);
    if (shoe == null) return null;

    final updated = _shoes
        .map((item) =>
            item.id == shoe.id ? item.addKilometers(distanceKm) : item)
        .toList(growable: false);
    await _save(updated, _selectedShoeId);
    return _findShoe(shoe.id);
  }

  Future<void> removeShoe(String shoeId) async {
    final updated = _shoes.where((shoe) => shoe.id != shoeId).toList();
    if (updated.length == _shoes.length) return;
    await _save(updated, _selectedShoeId == shoeId ? null : _selectedShoeId);
  }

  RunningShoes? _findShoe(String? id) {
    if (id == null) return null;
    for (final shoe in _shoes) {
      if (shoe.id == id) return shoe;
    }
    return null;
  }

  Future<void> _save(List<RunningShoes> shoes, String? selectedId) async {
    await _storage.write(
      jsonEncode({
        'shoes': shoes.map((shoe) => shoe.toJson()).toList(growable: false),
        'selected_shoe_id': selectedId,
      }),
    );
    _shoes = List.unmodifiable(shoes);
    _selectedShoeId = selectedId;
    notifyListeners();
  }
}
