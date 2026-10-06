import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class FunKeyLocalizations {
  const FunKeyLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  static const LocalizationsDelegate<FunKeyLocalizations> delegate =
      _FunKeyLocalizationsDelegate();

  static FunKeyLocalizations of(BuildContext context) {
    return Localizations.of<FunKeyLocalizations>(
          context,
          FunKeyLocalizations,
        ) ??
        const FunKeyLocalizations(Locale('en'));
  }

  String _pick({
    required String en,
    required String hi,
    required String te,
  }) {
    return switch (locale.languageCode) {
      'hi' => hi,
      'te' => te,
      _ => en,
    };
  }

  String get appTitle => 'FunKey';

  String get navHome => _pick(en: 'Home', hi: 'होम', te: 'హోమ్');
  String get navVibes => _pick(en: 'Vibes', hi: 'वाइब्स', te: 'వైబ్స్');
  String get navInbox => _pick(en: 'Inbox', hi: 'इनबॉक्स', te: 'ఇన్‌బాక్స్');
  String get navMe => _pick(en: 'Me', hi: 'मैं', te: 'నేను');

  String get settingsTitle =>
      _pick(en: 'Settings', hi: 'सेटिंग्स', te: 'సెట్టింగ్స్');
  String get language => _pick(en: 'Language', hi: 'भाषा', te: 'భాష');
  String get languageSaved => _pick(
        en: 'Language saved.',
        hi: 'भाषा सहेजी गई।',
        te: 'భాష సేవ్ అయింది.',
      );

  String languageName(String canonicalName) {
    return switch (canonicalName) {
      'English' => _pick(en: 'English', hi: 'अंग्रेज़ी', te: 'ఇంగ్లీష్'),
      'Hindi' => _pick(en: 'Hindi', hi: 'हिन्दी', te: 'హిందీ'),
      'Telugu' => _pick(en: 'Telugu', hi: 'तेलुगु', te: 'తెలుగు'),
      'Tamil' => _pick(en: 'Tamil', hi: 'तमिल', te: 'తమిళం'),
      'Kannada' => _pick(en: 'Kannada', hi: 'कन्नड़', te: 'కన్నడ'),
      'Malayalam' => _pick(en: 'Malayalam', hi: 'मलयालम', te: 'మలయాళం'),
      _ => canonicalName,
    };
  }

  String profileShareText(String displayName, String link) => _pick(
        en: 'See $displayName on FunKey\n$link',
        hi: 'FunKey पर $displayName की प्रोफ़ाइल देखें\n$link',
        te: 'FunKey లో $displayName ప్రొఫైల్ చూడండి\n$link',
      );

  String get shareOpened => _pick(
        en: 'Share options opened.',
        hi: 'शेयर विकल्प खुल गए।',
        te: 'షేర్ ఎంపికలు తెరవబడ్డాయి.',
      );

  String get linkCopied => _pick(
        en: 'Link copied.',
        hi: 'लिंक कॉपी हो गया।',
        te: 'లింక్ కాపీ అయింది.',
      );
}

class _FunKeyLocalizationsDelegate
    extends LocalizationsDelegate<FunKeyLocalizations> {
  const _FunKeyLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return const <String>{'en', 'hi', 'te'}.contains(locale.languageCode);
  }

  @override
  Future<FunKeyLocalizations> load(Locale locale) {
    return SynchronousFuture<FunKeyLocalizations>(
      FunKeyLocalizations(locale),
    );
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<FunKeyLocalizations> old,
  ) => false;
}
