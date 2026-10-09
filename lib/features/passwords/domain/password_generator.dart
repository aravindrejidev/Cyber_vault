import 'dart:math';

/// Generates random passwords with [Random.secure]. Look-alike characters
/// (l, I, O, 0, 1) are left out so passwords are easy to read and type.
class PasswordGenerator {
  PasswordGenerator._();

  static const String _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const String _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const String _digits = '23456789';
  static const String _symbols = r'!@#$%^&*()-_=+[]{};:,.?';

  static String generate({
    int length = 20,
    bool lower = true,
    bool upper = true,
    bool digits = true,
    bool symbols = true,
  }) {
    final List<String> pools = <String>[
      if (lower) _lower,
      if (upper) _upper,
      if (digits) _digits,
      if (symbols) _symbols,
    ];
    if (pools.isEmpty) pools.add(_lower);

    final Random random = Random.secure();
    final int size = max(length, pools.length);
    final List<String> chars = <String>[];

    // One character from every selected group guarantees each group appears.
    for (final String pool in pools) {
      chars.add(pool[random.nextInt(pool.length)]);
    }
    final String all = pools.join();
    while (chars.length < size) {
      chars.add(all[random.nextInt(all.length)]);
    }

    // Fisher-Yates shuffle so the guaranteed characters are not predictable.
    for (int i = chars.length - 1; i > 0; i--) {
      final int j = random.nextInt(i + 1);
      final String tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
    return chars.join();
  }
}
