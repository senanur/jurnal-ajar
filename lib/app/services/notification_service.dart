import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Links this device's FCM token to the signed-in user in `user_fcm_tokens`,
/// which is the only thing the `notify-jurnal-validated` edge function reads
/// from to know where to deliver a push when admin approves/rejects a jurnal.
/// The trigger/function/table/RLS side is already live — this service is
/// what was missing on the client.
class NotificationService extends GetxService {
  static NotificationService get to => Get.find<NotificationService>();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  // firebase_options.dart only defines Android/iOS configs (see
  // DefaultFirebaseOptions.currentPlatform), so Firebase.initializeApp() in
  // main() throws and is caught on every other platform (Windows/web/macOS
  // this app also builds for). Touching FirebaseMessaging.instance with no
  // default app registered throws too, so every entry point here must check
  // this first instead of assuming init succeeded.
  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    if (!_firebaseReady) return;
    _messaging.onTokenRefresh.listen(_saveToken);
    // FCM only auto-shows a system-tray notification when the app is
    // backgrounded/terminated. In the foreground it just fires this stream,
    // so surface it ourselves instead of silently dropping it.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  /// Requests notification permission and links this device's token to the
  /// current user. Call after every successful sign-in (password, Google, or
  /// session restore) — safe to call repeatedly, and never throws, since a
  /// user should still be able to use the app if push setup fails.
  Future<void> registerDeviceToken() async {
    if (!_firebaseReady || _supabase.auth.currentUser == null) return;

    try {
      final settings = await _messaging.requestPermission();
      final denied =
          settings.authorizationStatus == AuthorizationStatus.denied;
      if (denied) return;

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Removes this device's token so it stops receiving pushes meant for the
  /// account being signed out of. Must run before [SupabaseClient.auth]
  /// signs out — the delete's RLS check needs `auth.uid()` to still resolve.
  Future<void> deleteDeviceToken() async {
    if (!_firebaseReady) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _supabase
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('fcm_token', token);
    } catch (e) {
      debugPrint('Failed to delete FCM token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_fcm_tokens').upsert(
        {
          'user_id': user.id,
          'fcm_token': token,
          'device_info': defaultTargetPlatform.name,
        },
        onConflict: 'user_id,fcm_token',
      );
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    Get.snackbar(
      title ?? 'Notifikasi',
      body ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: MainColor.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}
