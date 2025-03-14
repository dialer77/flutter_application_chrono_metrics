import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/main_menu_page.dart';
import 'package:provider/provider.dart';
import 'providers/user_state_provider.dart';
import 'commons/audio_recording_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowManager.instance.setMinimumSize(const Size(1280, 720));
    WindowManager.instance.setSize(const Size(1280, 720));
    WindowManager.instance.setTitle('Chrono Metrics');
  }

  // WidgetsBinding.instance에 AppLifecycleListener 추가
  final lifecycleListener = AppLifecycleListener(
    onDetach: () async {
      // 앱이 종료될 때 정리 작업 수행
      await AudioRecordingManager().cleanup();
    },
    onHide: () async {
      // 앱이 숨겨질 때도 정리 작업 수행 (일부 플랫폼에서 유용)
      await AudioRecordingManager().cleanup();
    },
    onPause: () async {
      // 앱이 일시 중지될 때도 정리 작업 수행
      await AudioRecordingManager().cleanup();
    },
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => UserStateProvider(),
        ),
      ],
      child: MyApp(lifecycleListener: lifecycleListener),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppLifecycleListener lifecycleListener;

  const MyApp({super.key, required this.lifecycleListener});

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
