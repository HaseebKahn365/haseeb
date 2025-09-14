import 'dart:developer' as dev;
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// Reuse the same record instance pattern from the working sample
final _recorder = AudioRecorder();

class AudioTranscriptionService {
  final GenerativeModel model;
  bool _recording = false;
  bool _transcribing = false;

  AudioTranscriptionService(this.model);

  Future<void> startRecording() async {
    dev.log('AudioTranscriptionService.startRecording: requesting permission');

    if (_recording || _transcribing) {
      dev.log(
        'AudioTranscriptionService.startRecording: service busy (recording=$_recording transcribing=$_transcribing)',
      );
      throw Exception('Recording service is busy');
    }

    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission denied');
    }

    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/libs/recordings',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    dev.log('AudioTranscriptionService.startRecording: saving to $filePath');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 40000,
        sampleRate: 16000,
      ),
      path: filePath,
    );

    _recording = true;
  }

  Future<String> stopAndTranscribe() async {
    dev.log('AudioTranscriptionService.stopAndTranscribe: stopping');

    if (!_recording) {
      dev.log(
        'AudioTranscriptionService.stopAndTranscribe: not currently recording',
      );
      throw Exception('No active recording to stop');
    }

    final path = await _recorder.stop();
    _recording = false;
    _transcribing = true;

    if (path == null) {
      _transcribing = false;
      throw Exception('No recording produced');
    }

    dev.log('AudioTranscriptionService: recorded file at $path');

    final file = File(path);
    final audio = await file.readAsBytes();
    //size
    final audioSize = audio.lengthInBytes;
    dev.log('AudioTranscriptionService: audio size = $audioSize bytes');
    int secondsOfRecording = (audioSize / 5000).round(); // Rough estimate
    dev.log(
      'AudioTranscriptionService: estimated duration = $secondsOfRecording seconds',
    );

    final audioPart = InlineDataPart('audio/wav', audio);

    try {
      final prompt = TextPart('Please transcribe the audio into text.');
      final response = await model.generateContent([
        Content.multi([prompt, audioPart]),
      ]);

      final text = response.text ?? '';
      dev.log('AudioTranscriptionService: transcription length=${text.length}');

      try {
        await file.delete();
        dev.log('AudioTranscriptionService: recording file deleted');
      } catch (e) {
        dev.log('AudioTranscriptionService: failed to delete recording: $e');
      }

      return text;
    } catch (e) {
      dev.log('AudioTranscriptionService.stopAndTranscribe: error -> $e');
      rethrow;
    } finally {
      _transcribing = false;
    }
  }
}
