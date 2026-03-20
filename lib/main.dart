import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/datasources/local_database.dart';
import 'presentation/providers/photo_provider.dart';
import 'presentation/providers/trash_provider.dart';
import 'presentation/providers/stats_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库
  await LocalDatabase.instance.init();

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => TrashProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: const PhotoSwipeApp(),
    ),
  );
}
