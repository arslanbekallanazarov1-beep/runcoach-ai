import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

abstract interface class CoachSpeechService {
  Future<void> speak({
    required String text,
    required String languageCode,
  });

  Future<void> stop();
}

class FlutterCoachSpeechService implements CoachSpeechService {
  FlutterCoachSpeechService({
    FlutterTts? textToSpeech,
  }) : _textToSpeech = textToSpeech ?? FlutterTts() {
    _textToSpeech.setCompletionHandler(_finishSpeech);
    _textToSpeech.setCancelHandler(_finishSpeech);
    _textToSpeech.setErrorHandler(
      (_) => _finishSpeech(const CoachSpeechException()),
    );
  }

  final FlutterTts _textToSpeech;
  Completer<Exception?>? _speechCompletion;

  @override
  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    await _textToSpeech.awaitSpeakCompletion(false);
    await _textToSpeech.setLanguage(languageCode == 'ru' ? 'ru-RU' : 'en-US');
    final completion = Completer<Exception?>();
    _speechCompletion = completion;
    try {
      final result = await _textToSpeech.speak(text);
      if (result == 0) {
        _finishSpeech(const CoachSpeechException());
      }
      final error = await completion.future;
      if (error != null) throw error;
    } on Exception catch (error) {
      _finishSpeech(error);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _textToSpeech.stop();
    } finally {
      _finishSpeech();
    }
  }

  void _finishSpeech([Exception? error]) {
    final completion = _speechCompletion;
    _speechCompletion = null;
    if (completion == null || completion.isCompleted) return;
    completion.complete(error);
  }
}

class CoachSpeechException implements Exception {
  const CoachSpeechException();
}