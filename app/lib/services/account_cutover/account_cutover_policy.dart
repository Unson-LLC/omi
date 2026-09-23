import 'package:omi/firebase_options_personal.dart';

/// Keeps the upstream Omi account-cutover control plane out of private builds.
///
/// Personal Brainbase builds use their own Firebase project and Cloudflare
/// ingest path, so an upstream migration state must not suspend their product
/// traffic or offline upload recovery.
abstract final class AccountCutoverPolicy {
  static String? ownerFor(
    String? uid, {
    bool personalFirebaseEnabled = PersonalFirebaseOptions.enabled,
  }) {
    if (personalFirebaseEnabled || uid == null || uid.isEmpty) return null;
    return uid;
  }
}
