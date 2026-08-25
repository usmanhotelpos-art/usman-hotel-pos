import 'dart:math';
import 'dart:typed_data';

/// Builds a WAV file (mono, 16-bit PCM) replicating the web playLoudAlert():
/// 10 square-wave tones alternating 900/1400 Hz, each starting at i*0.26s,
/// lasting 0.24s with an exponential gain envelope 1.0 -> 0.01.
Uint8List buildSirenWav({int sampleRate = 22050}) {
  const int count = 10;
  const double gap = 0.26;
  const double toneDur = 0.24;
  final double totalDur = gap * (count - 1) + toneDur + 0.05;
  final int totalSamples = (totalDur * sampleRate).round();

  final Int16List samples = Int16List(totalSamples);
  for (int i = 0; i < totalSamples; i++) {
    final double t = i / sampleRate;
    final int idx = (t / gap).floor();
    double value = 0;
    if (idx < count) {
      final double local = t - idx * gap;
      if (local < toneDur) {
        final double freq = idx % 2 == 1 ? 1400 : 900;
        final double phase = 2 * pi * freq * local;
        final double square = sin(phase) >= 0 ? 1.0 : -1.0;
        final double env = pow(10, -2 * local / toneDur).toDouble();
        value = square * env * 0.85;
      }
    }
    samples[i] = (value.clamp(-1.0, 1.0) * 32767).round();
  }

  return wrapPcm16Wav(samples.buffer.asUint8List(), sampleRate);
}

Uint8List buildPaidWav({int sampleRate = 22050}) =>
    _buildToneSequence([880, 1175], sampleRate: sampleRate);

Uint8List buildServedWav({int sampleRate = 22050}) =>
    _buildToneSequence([660, 880, 990], sampleRate: sampleRate, toneDur: .12);

Uint8List buildDeleteWav({int sampleRate = 22050}) =>
    _buildToneSequence([440, 330], sampleRate: sampleRate, toneDur: .18);

Uint8List _buildToneSequence(
  List<double> frequencies, {
  int sampleRate = 22050,
  double toneDur = .14,
  double gap = .17,
}) {
  final double totalDur = gap * (frequencies.length - 1) + toneDur + .04;
  final int totalSamples = (totalDur * sampleRate).round();
  final Int16List samples = Int16List(totalSamples);
  for (int i = 0; i < totalSamples; i++) {
    final double t = i / sampleRate;
    final int idx = (t / gap).floor();
    double value = 0;
    if (idx < frequencies.length) {
      final double local = t - idx * gap;
      if (local < toneDur) {
        final double env = pow(10, -1.4 * local / toneDur).toDouble();
        value = sin(2 * pi * frequencies[idx] * local) * env * .75;
      }
    }
    samples[i] = (value.clamp(-1.0, 1.0) * 32767).round();
  }
  return wrapPcm16Wav(samples.buffer.asUint8List(), sampleRate);
}

Uint8List wrapPcm16Wav(Uint8List pcm, int sampleRate) {
  final int dataLen = pcm.length;
  final ByteData header = ByteData(44);
  void writeStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  header.setUint32(4, 36 + dataLen, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  writeStr(36, 'data');
  header.setUint32(40, dataLen, Endian.little);

  final bytes = Uint8List(44 + dataLen);
  bytes.setAll(0, header.buffer.asUint8List());
  bytes.setAll(44, pcm);
  return bytes;
}
