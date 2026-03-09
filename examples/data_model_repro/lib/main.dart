import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ReproPage());
  }
}

class ReproPage extends StatefulWidget {
  const ReproPage({super.key});

  @override
  State<ReproPage> createState() => _ReproPageState();
}

class _ReproPageState extends State<ReproPage> {
  final DataModel _dataModel = InMemoryDataModel();
  late final ValueNotifier<Object?> _rootNotifier;
  int _notifyCount = 0;
  int _updateCount = 0;

  @override
  void initState() {
    super.initState();
    _rootNotifier = _dataModel.subscribe<Object?>(DataPath.root);
    _rootNotifier.addListener(_onRootChanged);
  }

  void _onRootChanged() {
    setState(() => _notifyCount++);
  }

  void _updateChildPath() {
    _updateCount++;
    _dataModel.update(DataPath('/key$_updateCount'), 'value$_updateCount');
    // Force a rebuild so we can show the current data model state
    // even if the listener didn't fire.
    setState(() {});
  }

  @override
  void dispose() {
    _rootNotifier.removeListener(_onRootChanged);
    _rootNotifier.dispose();
    _dataModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _dataModel.getValue<Object?>(DataPath.root);
    final dataJson = const JsonEncoder.withIndent('  ').convert(data);
    final bugPresent = _updateCount > 0 && _notifyCount == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('DataModel Root Subscription Bug')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bugPresent ? 'BUG: Root listener never fired!' : 'Status OK',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: bugPresent ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text('Updates performed: $_updateCount'),
            Text('Root listener notifications: $_notifyCount'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateChildPath,
              child: const Text('Update a child path'),
            ),
            const SizedBox(height: 24),
            const Text('Data model (read directly via getValue):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade200,
                child: SingleChildScrollView(
                  child: Text(dataJson, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
