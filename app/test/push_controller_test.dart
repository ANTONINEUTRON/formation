import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/features/notifications/data/push_controller.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';

class _FakeClient implements PushClient {
  _FakeClient({this.granted = true});

  final bool granted;
  final refresh = StreamController<String>.broadcast();
  final messages = StreamController<void>.broadcast();

  @override
  Future<({String token, String platform})?> token() async =>
      granted ? (token: 'token-1', platform: 'android') : null;

  @override
  Stream<String> get tokenRefresh => refresh.stream;

  @override
  Stream<void> get foreground => messages.stream;
}

class _RecordingRepository extends FixtureRepository {
  _RecordingRepository() : super(walletAddress: 'TestWallet1111111111111111111111111111111');

  final registered = <String>[];
  final unregistered = <String>[];

  @override
  Future<void> registerPushDevice({required String token, required String platform, String? timeZone}) async =>
      registered.add(token);

  @override
  Future<void> unregisterPushDevice(String token) async => unregistered.add(token);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('turning pushes on registers the device and remembers it', () async {
    final repo = _RecordingRepository();
    var bells = 0;
    final client = _FakeClient();
    final controller = PushController(repository: repo, onMessage: () => bells++, client: client);

    expect(await controller.enabledToken(), isNull);
    expect(await controller.enable(), isTrue);
    expect(repo.registered, ['token-1']);
    expect(await controller.enabledToken(), 'token-1');

    // A rotated token is registered too, and a foreground push rings the bell.
    client.refresh.add('token-2');
    client.messages.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(repo.registered, ['token-1', 'token-2']);
    expect(bells, 1);

    await controller.disable();
    expect(repo.unregistered, ['token-2']);
    expect(await controller.enabledToken(), isNull);
  });

  test('a refused permission registers nothing', () async {
    final repo = _RecordingRepository();
    final controller = PushController(repository: repo, onMessage: () {}, client: _FakeClient(granted: false));
    expect(await controller.enable(), isFalse);
    expect(repo.registered, isEmpty);
  });

  test('resume only re-registers where pushes were turned on', () async {
    final repo = _RecordingRepository();
    await PushController(repository: repo, onMessage: () {}, client: _FakeClient()).resume();
    expect(repo.registered, isEmpty);

    SharedPreferences.setMockInitialValues({'push_enabled_token': 'old'});
    await PushController(repository: repo, onMessage: () {}, client: _FakeClient()).resume();
    expect(repo.registered, ['token-1']);
  });

  test('maps the device offset to an IANA zone for quiet hours', () {
    expect(deviceTimeZone(Duration.zero), 'UTC');
    expect(deviceTimeZone(const Duration(hours: 1)), 'Etc/GMT-1'); // Lagos
    expect(deviceTimeZone(const Duration(hours: -5)), 'Etc/GMT+5');
    expect(deviceTimeZone(const Duration(hours: 5, minutes: 30)), 'UTC');
  });
}
