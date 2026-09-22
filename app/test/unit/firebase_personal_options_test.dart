import 'package:flutter_test/flutter_test.dart';
import 'package:omi/firebase_options_personal.dart';

void main() {
  const valid = <String, String>{
    'apiKey': 'api-key',
    'appId': 'app-id',
    'messagingSenderId': 'sender-id',
    'projectId': 'personal-project',
    'storageBucket': 'bucket',
    'iosBundleId': 'jp.brainbase.omi.ksato.dev',
    'iosClientId': 'client-id',
  };

  test('constructs Firebase options from a complete private projection', () {
    final options = PersonalFirebaseOptions.fromValues(
      apiKey: valid['apiKey']!,
      appId: valid['appId']!,
      messagingSenderId: valid['messagingSenderId']!,
      projectId: valid['projectId']!,
      storageBucket: valid['storageBucket']!,
      iosBundleId: valid['iosBundleId']!,
      iosClientId: valid['iosClientId']!,
    );

    expect(options.projectId, 'personal-project');
    expect(options.iosBundleId, 'jp.brainbase.omi.ksato.dev');
  });

  test('fails closed when a private value is absent', () {
    expect(
      () => PersonalFirebaseOptions.fromValues(
        apiKey: '',
        appId: valid['appId']!,
        messagingSenderId: valid['messagingSenderId']!,
        projectId: valid['projectId']!,
        storageBucket: valid['storageBucket']!,
        iosBundleId: valid['iosBundleId']!,
        iosClientId: valid['iosClientId']!,
      ),
      throwsStateError,
    );
  });

  test('rejects a Firebase app from another project', () {
    expect(
      () => PersonalFirebaseOptions.validateProject('other-project', configuredProjectId: 'personal-project'),
      throwsStateError,
    );
    expect(
      () => PersonalFirebaseOptions.validateProject('personal-project', configuredProjectId: 'personal-project'),
      returnsNormally,
    );
  });
}
