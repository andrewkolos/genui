import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

// import 'firebase_options_stub.dart';
import 'src/ui/game_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print(record.error);
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print(record.stackTrace);
    }
  });

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ColonyGameApp());
}

class ColonyGameApp extends StatelessWidget {
  const ColonyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Colony Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}
