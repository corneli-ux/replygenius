import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/customer_message.dart';

/// Bridge to native Android code (MainActivity.kt).
///
/// Two channels:
///   1. `replygenius/bridge` (MethodChannel) — commands: requestPermissions,
///      openOverlay, closeOverlay, pushReplyToOverlay, openNotificationSettings
///   2. `replygenius/events` (EventChannel) — stream of incoming customer
///      messages captured by NotificationListenerService
class NativeBridgeService {
  static const _method = MethodChannel('replygenius/bridge');
  static const _events = EventChannel('replygenius/events');

  final _messageController = StreamController<CustomerMessage>.broadcast();
  Stream<CustomerMessage> get messageStream => _messageController.stream;

  StreamSubscription? _eventSub;

  NativeBridgeService() {
    _eventSub = _events.receiveBroadcastStream().listen(
      (data) {
        if (data is Map) {
          final msg = CustomerMessage.fromJson(
            Map<String, dynamic>.from(data),
          );
          _messageController.add(msg);
        }
      },
      onError: (e) {
        // Surface but do not crash.
        _messageController.addError(e);
      },
    );
  }

  /// Ask user to enable NotificationListenerService for our app
  /// (opens Android settings page).
  Future<bool> openNotificationListenerSettings() async {
    try {
      final result = await _method
          .invokeMethod<bool>('openNotificationListenerSettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check whether notification access is currently granted.
  Future<bool> isNotificationAccessGranted() async {
    try {
      return await _method.invokeMethod<bool>('isNotificationAccessGranted') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Ask user to grant SYSTEM_ALERT_WINDOW (draw over other apps).
  Future<bool> requestOverlayPermission() async {
    try {
      return await _method.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    try {
      return await _method.invokeMethod<bool>('isOverlayPermissionGranted') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Show the floating bubble over the active chat.
  Future<void> showOverlay({
    required String sender,
    required String message,
    required int angerScore,
    required List<Map<String, dynamic>> variants,
  }) async {
    await _method.invokeMethod('showOverlay', {
      'sender': sender,
      'message': message,
      'angerScore': angerScore,
      'variants': jsonEncode(variants),
    });
  }

  Future<void> closeOverlay() async {
    await _method.invokeMethod('closeOverlay');
  }

  void dispose() {
    _eventSub?.cancel();
    _messageController.close();
  }
}
