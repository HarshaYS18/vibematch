class FamilyId {
  const FamilyId._();

  static final RegExp pattern = RegExp(r'^[A-Z]{3}[0-9]{4}$');

  /// Family IDs must be exactly 3 uppercase letters followed by 4 numbers.
  /// Examples: VMF2048, FAM6922, SKY1056.
  static bool isValid(String value) => pattern.hasMatch(value.trim());

  static String normalize(String value) => value.trim().toUpperCase();

  /// Local mock generator for UI/testing only.
  /// Backend must generate and reserve unique IDs transactionally.
  static String generateMock({String prefix = 'FAM', DateTime? now}) {
    final safePrefix = _safePrefix(prefix);
    final source = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final number = (source % 10000).toString().padLeft(4, '0');
    return '$safePrefix$number';
  }

  static String _safePrefix(String prefix) {
    final lettersOnly = prefix.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
    if (lettersOnly.length >= 3) return lettersOnly.substring(0, 3);
    return lettersOnly.padRight(3, 'F');
  }
}
