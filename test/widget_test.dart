import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_swipe/app.dart';
import 'package:photo_swipe/presentation/providers/photo_provider.dart';
import 'package:photo_swipe/presentation/providers/stats_provider.dart';
import 'package:photo_swipe/presentation/providers/trash_provider.dart';

class _TestPhotoProvider extends PhotoProvider {
  @override
  Future<void> loadPhotos({String? mediaType}) async {}

  @override
  Future<void> loadMore() async {}
}

class _TestStatsProvider extends StatsProvider {
  @override
  Future<void> loadStats() async {}
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.fluttercandies/photo_manager'),
      (call) async => 2,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PhotoProvider>.value(
              value: _TestPhotoProvider()),
          ChangeNotifierProvider<TrashProvider>.value(value: TrashProvider()),
          ChangeNotifierProxyProvider2<PhotoProvider, TrashProvider,
              StatsProvider>(
            create: (_) => _TestStatsProvider(),
            update: (_, photos, trash, stats) {
              stats!.bindProviders(photos, trash);
              return stats;
            },
          ),
        ],
        child: const PhotoSwipeApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(PhotoSwipeApp), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.fluttercandies/photo_manager'),
      null,
    );
  });
}
