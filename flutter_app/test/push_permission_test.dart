import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:house_kgz/push/firebase_push_messaging.dart';
import 'package:house_kgz/push/push_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'non-Android startup does not require Firebase platform configuration',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        expect(await FirebasePushMessaging.initialize(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('first undecided/denied permission asks once across restarts', () async {
    bool asked = false;
    int prompts = 0;
    Future<bool> run() => requestPushPermissionOnce(
      isAuthorized: () async => false,
      wasRequested: () => asked,
      markRequested: () async {
        asked = true;
      },
      request: () async {
        prompts++;
        return false;
      },
    );
    expect(await run(), false);
    expect(await run(), false);
    expect(prompts, 1);
  });
  test(
    'authorized permission and later grant in settings do not prompt',
    () async {
      int prompts = 0;
      expect(
        await requestPushPermissionOnce(
          isAuthorized: () async => true,
          wasRequested: () => true,
          markRequested: () async {},
          request: () async {
            prompts++;
            return true;
          },
        ),
        true,
      );
      expect(prompts, 0);
    },
  );
  test('a first grant permits registration', () async {
    expect(
      await requestPushPermissionOnce(
        isAuthorized: () async => false,
        wasRequested: () => false,
        markRequested: () async {},
        request: () async => true,
      ),
      true,
    );
  });
}
