import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voxel/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoxelApp()));
    // Should show login screen initially
    expect(find.text('VOXEL'), findsOneWidget); 
  });
}
