import '../providers/app_provider.dart';

class WidgetService {
  /// Android recomputes from per-profile records without a Flutter engine.
  static Future<void> updateWidgets(AppProvider provider) =>
      provider.storage.syncNativeState();
}
