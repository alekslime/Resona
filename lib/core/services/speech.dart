abstract class SpeechOutput {
  /// Speak [text]. By default it cuts off whatever is being said; with [queue] it waits its turn.
  Future<void> speak(String text, {bool queue = false});
  Future<void> stop();
  bool get isSpeaking;

  /// Speech speed, 1.0 = normal. Resonant lets the right edge drag adjust this.
  double get rate;
  set rate(double value);
}

abstract class SpeechInput {
  /// Open the microphone. False if it is unavailable or not allowed.
  Future<bool> start();

  /// Close the microphone and return what was heard (empty if nothing).
  Future<String> stop();
}

/// The speech speed in words, ported from Resonant's AudioManager:
/// "normal speed", "double speed", "one point five times speed".
String speechSpeedLabel(double value) {
  // Keyed by the printed value: doubles cannot key a const map.
  const names = {
    '0.75': 'zero point seven five',
    '1.0': 'normal',
    '1.25': 'one point two five',
    '1.5': 'one point five',
    '1.75': 'one point seven five',
    '2.0': 'double',
    '2.5': 'two point five',
    '3.0': 'triple',
    '3.5': 'three point five',
    '4.0': 'quadruple',
  };
  final spoken = names[value.toString()] ?? value.toString();
  final whole = value == 1.0 || value == 2.0 || value == 3.0 || value == 4.0;
  return whole ? '$spoken speed' : '$spoken times speed';
}
