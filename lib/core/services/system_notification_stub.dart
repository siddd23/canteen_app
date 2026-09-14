class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance = SystemNotificationService._();

  Future<void> requestPermission() async {}
  void show({required String title, required String body}) {}
}
