import 'package:flutter_test/flutter_test.dart';
import 'package:aeroreal_app/utils/error_mapper.dart';
import 'package:aeroreal_app/utils/number_formatting.dart';

void main() {
  test('maps insufficient balance to a friendly message', () {
    final error = ErrorMapper.map('ERC20InsufficientBalance');

    expect(error.title, 'Insufficient balance');
    expect(error.message, contains('enough tokens'));
  });

  test('maps revert warnings to transaction failed copy', () {
    final error = ErrorMapper.map('Transaction reverted: 0x40dd');

    expect(error.title, 'Transaction failed');
    expect(error.message, contains('sufficient balance'));
  });

  test('formats price numbers with thousands separators', () {
    expect(NumberFormatting.withCommas(4000), '4,000');
    expect(NumberFormatting.money(4000), '\$4,000.00');
  });
}
