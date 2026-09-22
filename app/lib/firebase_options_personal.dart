// Firebase options for the private Brainbase/Omi build.
// Values are injected at build time with --dart-define-from-file and are never
// committed to the repository.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class PersonalFirebaseOptions {
  static const enabled = bool.fromEnvironment('BRAINBASE_PERSONAL_FIREBASE');
  static const _apiKey = String.fromEnvironment('BRAINBASE_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('BRAINBASE_FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment('BRAINBASE_FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('BRAINBASE_FIREBASE_PROJECT_ID');
  static const _storageBucket = String.fromEnvironment('BRAINBASE_FIREBASE_STORAGE_BUCKET');
  static const _iosBundleId = String.fromEnvironment('BRAINBASE_FIREBASE_IOS_BUNDLE_ID');
  static const _iosClientId = String.fromEnvironment('BRAINBASE_FIREBASE_IOS_CLIENT_ID');

  static FirebaseOptions get currentPlatform {
    if (!enabled) {
      throw StateError('Personal Firebase options were requested without enabling the personal build.');
    }
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS)) {
      throw UnsupportedError('Personal Firebase is configured only for Apple mobile builds.');
    }
    return fromValues(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket,
      iosBundleId: _iosBundleId,
      iosClientId: _iosClientId,
    );
  }

  static FirebaseOptions fromValues({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    required String storageBucket,
    required String iosBundleId,
    required String iosClientId,
  }) {
    final values = <String, String>{
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'storageBucket': storageBucket,
      'iosBundleId': iosBundleId,
      'iosClientId': iosClientId,
    };
    final missing = values.entries.where((entry) => entry.value.trim().isEmpty).map((entry) => entry.key).toList();
    if (missing.isNotEmpty) {
      throw StateError('Personal Firebase configuration is incomplete: ${missing.join(', ')}.');
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      iosBundleId: iosBundleId,
      iosClientId: iosClientId,
    );
  }

  static void validateProject(String initializedProjectId, {String configuredProjectId = _projectId}) {
    if (configuredProjectId.trim().isEmpty || initializedProjectId != configuredProjectId) {
      throw StateError('The initialized Firebase project does not match the personal build configuration.');
    }
  }
}
