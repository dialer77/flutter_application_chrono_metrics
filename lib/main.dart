import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/main_menu_page.dart';
import 'package:provider/provider.dart';
import 'providers/user_state_provider.dart';
import 'package:flutter/services.dart';
import 'commons/audio_recording_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowManager.instance.setMinimumSize(const Size(1200, 700));
    WindowManager.instance.setMaximumSize(const Size(1200, 700));
    WindowManager.instance.setSize(const Size(1200, 700));
    WindowManager.instance.setTitle('Chrono Metrics');
  }

  // 앱 종료 리스너 추가
  SystemChannels.lifecycle.setMessageHandler((message) async {
    if (message == AppLifecycleState.detached.toString()) {
      // 앱이 종료될 때 정리 작업 수행
      await AudioRecordingManager().cleanup();
    }
    return null;
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => UserStateProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chrono Metrics',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainMenuPage(title: 'Chrono Metrics'),
    );
  }
}
