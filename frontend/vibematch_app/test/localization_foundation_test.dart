import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/core/localization/funkey_localizations.dart';
import 'package:vibematch_app/core/localization/vm_locale_controller.dart';

void main() {
  test('language setting maps to the M4 supported locale foundation', () {
    expect(VmLocaleController.localeForLanguage('English').languageCode, 'en');
    expect(VmLocaleController.localeForLanguage('Hindi').languageCode, 'hi');
    expect(VmLocaleController.localeForLanguage('Telugu').languageCode, 'te');
    expect(VmLocaleController.localeForLanguage('Tamil').languageCode, 'en');
  });

  test('core navigation strings exist in English, Hindi and Telugu', () {
    const english = FunKeyLocalizations(Locale('en'));
    const hindi = FunKeyLocalizations(Locale('hi'));
    const telugu = FunKeyLocalizations(Locale('te'));

    expect(english.navHome, 'Home');
    expect(hindi.navHome, isNot('Home'));
    expect(telugu.navHome, isNot('Home'));
    expect(hindi.navInbox, isNotEmpty);
    expect(telugu.settingsTitle, isNotEmpty);
  });
}
