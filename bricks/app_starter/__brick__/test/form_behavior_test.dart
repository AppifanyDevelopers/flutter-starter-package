import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{project_name}}/core/build_variants/app_environment.dart';
import 'package:{{project_name}}/core/theme/app_palette.dart';
import 'package:{{project_name}}/core/theme/app_theme.dart';
import 'package:{{project_name}}/core/utils/keyboard.dart';
import 'package:{{project_name}}/core/validators/validators.dart';
import 'package:{{project_name}}/core/widgets/app_outlined_button.dart';
import 'package:{{project_name}}/core/widgets/app_text_form_field.dart';
import 'package:{{project_name}}/core/widgets/environment_banner.dart';
import 'package:{{project_name}}/core/widgets/password_rules_checklist.dart';

TextField _field(WidgetTester tester, String label) =>
    tester.widget<TextField>(find.descendant(of: find.widgetWithText(AppTextFormField, label), matching: find.byType(TextField)));

void main() {
  group('validation happens on submit, not while typing', () {
    testWidgets('no error appears as the user types; submit shows it', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: AppTextFormField.email(validator: Validators.email()),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email'), findsNothing);

      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('spaces only is caught on submit', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: AppTextFormField.name(validator: Validators.name()),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), '      ');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
    });
  });

  group('input types', () {
    testWidgets('name, email, phone get their own keyboard', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppTextFormField.name(),
              AppTextFormField.email(),
              AppTextFormField.phone(),
            ],
          ),
        ),
      ));

      final name = _field(tester, 'Full name');
      expect(name.keyboardType, TextInputType.name);
      expect(name.textCapitalization, TextCapitalization.words);

      final email = _field(tester, 'Email');
      expect(email.keyboardType, TextInputType.emailAddress);
      expect(email.textCapitalization, TextCapitalization.none);

      final phone = _field(tester, 'Phone number');
      expect(phone.keyboardType, TextInputType.phone);
    });

    testWidgets('email blocks spaces, phone blocks letters', (tester) async {
      final email = TextEditingController();
      final phone = TextEditingController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppTextFormField.email(controller: email),
              AppTextFormField.phone(controller: phone),
            ],
          ),
        ),
      ));
      await tester.enterText(find.widgetWithText(AppTextFormField, 'Email'), 'a b@c.com');
      await tester.enterText(find.widgetWithText(AppTextFormField, 'Phone number'), '04ab12 3-4+');
      expect(email.text, 'ab@c.com');
      expect(phone.text, '0412 3-4+');
    });
  });

  group('keyboard', () {
    testWidgets('pressing a button hides the keyboard', (tester) async {
      var pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppTextFormField.name(),
              AppOutlinedButton(label: 'Save', onPressed: () => pressed = true),
            ],
          ),
        ),
      ));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(pressed, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('tapping blank space hides the keyboard', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DismissKeyboardOnTap(
            child: Column(
              children: [
                AppTextFormField.name(),
                const Expanded(child: SizedBox.expand(key: Key('blank'))),
              ],
            ),
          ),
        ),
      ));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(const Key('blank')));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a loading button does nothing', (tester) async {
      var pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AppOutlinedButton(label: 'Save', isLoading: true, onPressed: () => pressed = true)),
      ));
      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, isFalse);
    });
  });

  group('password rules checklist', () {
    testWidgets('ticks each rule live as the password is typed', (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PasswordRulesChecklist(controller: c))));

      int met() => find.byIcon(Icons.check_circle).evaluate().length;
      expect(met(), 0);

      c.text = 'abcdefgh';
      await tester.pump();
      expect(met(), 2); // length + no spaces

      c.text = 'Abcdefg1';
      await tester.pump();
      expect(met(), 4); // + capital + number

      c.text = 'Abcdef1!';
      await tester.pump();
      expect(met(), 5);

      c.text = 'Abcdef 1!';
      await tester.pump();
      expect(met(), 4); // spaces rule fails
    });
  });

  group('theme', () {
    test('cursor and selection use the primary colour in light and dark', () {
      for (final theme in [AppTheme.light(const Color(0xFF32A852)), AppTheme.dark(const Color(0xFF32A852))]) {
        expect(theme.textSelectionTheme.cursorColor, theme.colorScheme.primary);
        expect(theme.textSelectionTheme.selectionHandleColor, theme.colorScheme.primary);
      }
    });
  });

  group('palette', () {
    test('text, hint and border colours come from the neutral ramp, not the seed', () {
      for (final seed in [const Color(0xFF32A852), const Color(0xFFD42B65)]) {
        final light = AppTheme.light(seed).colorScheme;
        expect(light.onSurface, AppPalette.neutral900);
        expect(light.onSurfaceVariant, AppPalette.neutral600);
        expect(light.outlineVariant, AppPalette.neutral200);

        final dark = AppTheme.dark(seed).colorScheme;
        expect(dark.onSurface, AppPalette.neutral50);
        expect(dark.onSurfaceVariant, AppPalette.neutral300);
      }
    });

    test('every colour the theme reads exists', () {
      expect([
        AppPalette.neutral50,
        AppPalette.neutral200,
        AppPalette.neutral300,
        AppPalette.neutral500,
        AppPalette.neutral600,
        AppPalette.neutral900,
      ], everyElement(isA<Color>()));
    });
  });

  group('environment banner', () {
    Future<Banner?> pump(WidgetTester tester, AppEnvironment env) async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: EnvironmentBanner(environment: env, child: const Scaffold(body: Text('app'))),
      ));
      final banners = find.byType(Banner);
      return banners.evaluate().isEmpty ? null : tester.widget<Banner>(banners);
    }

    testWidgets('staging: red STAGING at the top left', (tester) async {
      final b = await pump(tester, AppEnvironment.staging);
      expect(b!.message, 'STAGING');
      expect(b.location, BannerLocation.topStart);
      expect(b.color.toARGB32() & 0xFFFFFF, Colors.red.toARGB32() & 0xFFFFFF);
    });

    testWidgets('di: blue DI at the top left', (tester) async {
      final b = await pump(tester, AppEnvironment.di);
      expect(b!.message, 'DI');
      expect(b.location, BannerLocation.topStart);
      expect(b.color.toARGB32() & 0xFFFFFF, Colors.blue.toARGB32() & 0xFFFFFF);
    });

    testWidgets('production: no banner', (tester) async {
      expect(await pump(tester, AppEnvironment.production), isNull);
      expect(find.text('app'), findsOneWidget);
    });
  });
}
