import 'package:oracular/utils/wizard_navigation.dart';
import 'package:test/test.dart';

void main() {
  group('BackNavigation', () {
    test('toString includes fromStep label when provided', () {
      const BackNavigation withStep = BackNavigation(fromStep: 'firebase project ID');
      expect(withStep.toString(), contains('firebase project ID'));
    });

    test('toString without fromStep is the bare class name', () {
      const BackNavigation bare = BackNavigation();
      expect(bare.toString(), equals('BackNavigation'));
    });
  });

  group('CancelNavigation', () {
    test('toString carries the reason when provided', () {
      const CancelNavigation cancel = CancelNavigation(reason: 'user typed quit');
      expect(cancel.toString(), contains('user typed quit'));
    });

    test('toString without reason is the bare class name', () {
      const CancelNavigation bare = CancelNavigation();
      expect(bare.toString(), equals('CancelNavigation'));
    });
  });

  group('WizardNav.backKeywords', () {
    test('recognizes standard back keywords', () {
      expect(WizardNav.backKeywords, containsAll(<String>['back', 'b', '<', ':back']));
    });

    test('recognizes standard cancel keywords', () {
      expect(
        WizardNav.cancelKeywords,
        containsAll(<String>['quit', 'q', ':q', ':quit', 'exit', 'cancel']),
      );
    });

    test('back and cancel keyword sets do not overlap', () {
      // Otherwise the wizard could not distinguish between rewinding and aborting.
      final Set<String> overlap =
          WizardNav.backKeywords.intersection(WizardNav.cancelKeywords);
      expect(overlap, isEmpty);
    });
  });

  group('WizardNav.backOptionLabel', () {
    test('uses the same return-arrow glyph the wizard advertises', () {
      expect(WizardNav.backOptionLabel, contains('Back'));
      expect(WizardNav.backOptionLabel, contains('\u21B5'));
    });
  });
}
