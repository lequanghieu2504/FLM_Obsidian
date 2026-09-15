import 'package:app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the FLM desktop shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlmObsidianApp()));

    expect(find.text('Subjects Catalog'), findsWidgets);
    expect(find.text('Search Chunks'), findsWidgets);
    expect(find.text('AI Chat (BYOK)'), findsWidgets);
    expect(find.text('Settings & Keys'), findsWidgets);
  });
}
