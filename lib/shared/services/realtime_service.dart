import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_constants.dart';
import 'token_storage_service.dart';

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  final _newOrders = StreamController<Map<String, dynamic>>.broadcast();
  final _orderUpdates = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newOrders => _newOrders.stream;
  Stream<Map<String, dynamic>> get orderUpdates => _orderUpdates.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connectOwner() async {
    final token = await TokenStorageService.instance.getToken();
    if (token == null || token.isEmpty) return;
    _connect({'token': token});
  }

  void connectEmployee({
    required String orderNumber,
    required String trackingToken,
  }) {
    _connect({'orderNumber': orderNumber, 'trackingToken': trackingToken});
  }

  void _connect(Map<String, dynamic> auth) {
    disconnect();
    final socket = io.io(
      ApiConstants.realtimeUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth(auth)
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    socket.on('order:new', (data) => _addMap(_newOrders, data));
    socket.on('order:updated', (data) => _addMap(_orderUpdates, data));
    socket.connect();
  }

  void _addMap(
    StreamController<Map<String, dynamic>> controller,
    dynamic data,
  ) {
    if (data is Map) controller.add(Map<String, dynamic>.from(data));
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
