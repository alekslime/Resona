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
