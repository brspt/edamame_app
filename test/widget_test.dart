import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edamame_app/main.dart';

void main() {
  testWidgets('Sector dialog applies changes without mutating its input',
      (tester) async {
    final selected = ['20'];
    List<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return TextButton(
          onPressed: () async {
            result = await showDialog<List<String>>(
              context: context,
              builder: (_) => MultiSelectDialog(
                items: ['19', '20', '21'],
                initialSelectedItems: selected,
              ),
            );
          },
          child: const Text('Open sectors'),
        );
      }),
    ));
    await tester.tap(find.text('Open sectors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sektor 19'));
    await tester.tap(find.text('Sektor 20'));
    await tester.pump();
    expect(selected, ['20']);
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(result, ['19']);
  });
}
