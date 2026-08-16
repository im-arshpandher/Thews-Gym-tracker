import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final soundsDir = Directory('assets/sounds');
  if (!soundsDir.existsSync()) {
    soundsDir.createSync(recursive: true);
  }

  // 1. Generate metronome_click.wav (1050 Hz, 35 ms snappy tick)
  final clickBytes = generateWavBytes(
    frequency: 1050.0,
    durationMs: 35,
    sampleRate: 44100,
    decayRate: 0.006,
  );
  File('assets/sounds/metronome_click.wav').writeAsBytesSync(clickBytes);

  // 2. Generate metronome_accent.wav (1750 Hz, 45 ms crisp high pitch downbeat)
  final accentBytes = generateWavBytes(
    frequency: 1750.0,
    durationMs: 45,
    sampleRate: 44100,
    decayRate: 0.009,
  );
  File('assets/sounds/metronome_accent.wav').writeAsBytesSync(accentBytes);
}

Uint8List generateWavBytes({
  required double frequency,
  required int durationMs,
  required int sampleRate,
  required double decayRate,
}) {
  final numSamples = (sampleRate * (durationMs / 1000.0)).round();
  final subChunk2Size = numSamples * 2; // 16-bit mono = 2 bytes per sample
  final chunkSize = 36 + subChunk2Size;

  final buffer = ByteData(44 + subChunk2Size);

  // RIFF Chunk
  buffer.setUint8(0, 0x52); // 'R'
  buffer.setUint8(1, 0x49); // 'I'
  buffer.setUint8(2, 0x46); // 'F'
  buffer.setUint8(3, 0x46); // 'F'
  buffer.setUint32(4, chunkSize, Endian.little);
  buffer.setUint8(8, 0x57);  // 'W'
  buffer.setUint8(9, 0x41);  // 'A'
  buffer.setUint8(10, 0x56); // 'V'
  buffer.setUint8(11, 0x45); // 'E'

  // fmt subchunk
  buffer.setUint8(12, 0x66); // 'f'
  buffer.setUint8(13, 0x6D); // 'm'
  buffer.setUint8(14, 0x74); // 't'
  buffer.setUint8(15, 0x20); // ' '
  buffer.setUint32(16, 16, Endian.little); // Subchunk1Size = 16 for PCM
  buffer.setUint16(20, 1, Endian.little);  // AudioFormat = 1 (PCM)
  buffer.setUint16(22, 1, Endian.little);  // NumChannels = 1 (Mono)
  buffer.setUint32(24, sampleRate, Endian.little); // SampleRate
  buffer.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (SampleRate * NumChannels * BitsPerSample/8)
  buffer.setUint16(32, 2, Endian.little);  // BlockAlign (NumChannels * BitsPerSample/8)
  buffer.setUint16(34, 16, Endian.little); // BitsPerSample = 16

  // data subchunk
  buffer.setUint8(36, 0x64); // 'd'
  buffer.setUint8(37, 0x61); // 'a'
  buffer.setUint8(38, 0x74); // 't'
  buffer.setUint8(39, 0x61); // 'a'
  buffer.setUint32(40, subChunk2Size, Endian.little);

  // Generate PCM samples with fast attack & exponential decay
  final maxAmplitude = 30000.0;
  final attackSamples = (sampleRate * 0.0015).round(); // 1.5ms attack ramp

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate.toDouble();
    // Fast attack ramp to prevent click distortion at start
    double envelope = 1.0;
    if (i < attackSamples) {
      envelope = i / attackSamples.toDouble();
    } else {
      envelope = exp(-(t - (attackSamples / sampleRate)) / decayRate);
    }

    // Sine wave sample
    final sampleValue = (sin(2 * pi * frequency * t) * maxAmplitude * envelope).clamp(-32768.0, 32767.0).round();
    buffer.setInt16(44 + (i * 2), sampleValue, Endian.little);
  }

  return buffer.buffer.asUint8List();
}
