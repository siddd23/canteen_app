import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class OrderSoundService {
  OrderSoundService._();

  static final OrderSoundService instance = OrderSoundService._();

  final AudioPlayer _player = AudioPlayer();
  final Set<String> _pendingOrderIds = <String>{};
  bool _enabled = true;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) unawaited(stopAllAlerts());
  }

  Future<void> startPendingOrderAlert(String orderId) async {
    if (!_enabled || orderId.isEmpty) return;
    final wasEmpty = _pendingOrderIds.isEmpty;
    _pendingOrderIds.add(orderId);
    if (!wasEmpty) return;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/order_bell.wav'), volume: 1);
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> stopPendingOrderAlert(String orderId) async {
    _pendingOrderIds.remove(orderId);
    if (_pendingOrderIds.isEmpty) await _player.stop();
  }

  Future<void> stopAllAlerts() async {
    _pendingOrderIds.clear();
    await _player.stop();
  }

  Future<void> dispose() async {
    await stopAllAlerts();
    await _player.dispose();
  }
}
