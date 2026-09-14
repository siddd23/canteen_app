// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance = SystemNotificationService._();

  Future<void> requestPermission() async {
    if (html.Notification.supported && html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  }

  void show({required String title, required String body}) {
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: '/icons/Icon-192.png');
    }
  }
}
