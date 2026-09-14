import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class OrderSoundService {
  OrderSoundService._();

  static final OrderSoundService instance = OrderSoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool enabled = true;

  Future<void> playNewOrderBell() async {
    if (!enabled || _playing) return;
    _playing = true;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/order_bell.wav'), volume: 1);
    } catch (_) {
      // Retain a system-level fallback if an individual platform cannot load
      // the packaged asset for any reason.
      await SystemSound.play(SystemSoundType.alert);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _playing = false;
    }
  }

  Future<void> dispose() => _player.dispose();
}
