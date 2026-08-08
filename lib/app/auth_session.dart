import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Caches the signed-in user's `profiles.role` so [AdminOnlyMiddleware] can
/// check it synchronously (GetX's `redirect()` can't await a network call)
/// instead of re-querying the database on every navigation.
class AuthSession extends GetxService {
  static AuthSession get to => Get.find<AuthSession>();

  final Rx<String?> role = Rx<String?>(null);

  void setRole(String? value) => role.value = value;

  void clear() => role.value = null;
}

/// Blocks non-admin navigation into admin-only routes.
///
/// RLS already enforces this at the data layer, so this is a UX guard, not
/// the security boundary. It relies on [AuthSession.role] being populated at
/// login — the app currently has no session-restore path (splash always
/// routes to `/login`), so a role only ever needs to be looked up once, right
/// after `signInWithPassword`, before any admin route becomes reachable in
/// that app run.
class AdminOnlyMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const RouteSettings(name: Routes.login);
    }
    if (AuthSession.to.role.value != 'admin') {
      return const RouteSettings(name: Routes.dashboardGuru);
    }
    return null;
  }
}
