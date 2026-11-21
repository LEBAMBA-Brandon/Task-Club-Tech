import 'package:flutter_test/flutter_test.dart';
import 'package:task_ctech/presentation/auth/widgets/auth_widgets.dart';

/// Tests unitaires simples des validateurs (mêmes règles que l'API).
void main() {
  test('mot de passe : 8 caractères, majuscule, minuscule, chiffre', () {
    expect(Validators.password('abc'), isNotNull);
    expect(Validators.password('abcdefgh1'), isNotNull);
    expect(Validators.password('Abcdefgh1'), isNull);
  });

  test('code à 6 chiffres', () {
    expect(Validators.code('12345'), isNotNull);
    expect(Validators.code('123456'), isNull);
  });

  test('e-mail', () {
    expect(Validators.email('pas-un-mail'), isNotNull);
    expect(Validators.email('axel@ctech.ga'), isNull);
  });
}
