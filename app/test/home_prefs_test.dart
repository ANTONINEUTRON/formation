import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/features/home/data/home_prefs.dart';
import 'package:formation/features/shared/domain/models.dart';

void main() {
  test('nothing is remembered before the first pick', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await HomePrefs().lastSport(), isNull);
  });

  test('remembers the last sport picked', () async {
    SharedPreferences.setMockInitialValues({});
    await HomePrefs().setLastSport(SportMode.basketball);
    expect(await HomePrefs().lastSport(), SportMode.basketball);
    await HomePrefs().setLastSport(SportMode.americanFootball);
    expect(await HomePrefs().lastSport(), SportMode.americanFootball);
  });

  test('ignores a value this version does not know', () async {
    SharedPreferences.setMockInitialValues({'formation.home.sport': 'cricket'});
    expect(await HomePrefs().lastSport(), isNull);
  });
}
