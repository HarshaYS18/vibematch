import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_budget.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';

void main() {
  test('every resource kind has a positive M14 budget', () {
    expect(
      MediaResourceBudgetPolicy.budgets.keys.toSet(),
      MediaResourceKind.values.toSet(),
    );
    for (final budget in MediaResourceBudgetPolicy.budgets.values) {
      expect(budget.recommendedMaxActive, greaterThan(0));
      expect(budget.rationale.trim(), isNotEmpty);
    }
  });
}
