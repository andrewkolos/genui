import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
// import 'package:genui_firebase_ai/genui_firebase_ai.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';

import '../catalog/colony_catalog.dart';
import '../config/io_get_api_key.dart'
    if (dart.library.html) '../config/web_get_api_key.dart';
import '../logic/game_tools.dart';
import '../model/world_state.dart';
import 'map_legend.dart';
import 'map_widget.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final WorldState _worldState;
  late final GameTools _gameTools;
  late final A2uiMessageProcessor _a2uiMessageProcessor;
  late final GenUiConversation _genUiConversation;

  final List<TimelineItem> _timeline = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _worldState = WorldState.initial(20, 20);
    _gameTools = GameTools(
      worldState: _worldState,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onError: (error, stackTrace) {
        if (mounted) {
          _showErrorDialog(error, stackTrace);
        }
      },
    );

    _a2uiMessageProcessor = A2uiMessageProcessor(catalogs: [colonyCatalog]);

    final contentGenerator = GoogleGenerativeAiContentGenerator(
      apiKey: getApiKey(),
      modelName: 'models/gemini-2.5-pro',
      catalog: colonyCatalog,
      systemInstruction: '''
The player's goal is manage the colony so it can survive for 30 days.
Talk like a pragmatic pioneer/Game Master.

Game Flow (TURN-BASED):
1. **Planning Phase (CURRENT)**:
   - Queue actions for units.
   - **SUMMARIZE** what you queued. "u1 will move to (X,Y). u2 will build."
   - **ASK**: "Ready to End Day?"
   - **STOP.** Do NOT discuss Day X+1 yet.

2. **Execution Phase (WAIT FOR SYSTEM REPORT)**:
   - The user clicks "End Day". You receive a "System Report".
   - **THEN** and ONLY THEN, the day ends.
   - Review the report.
   - **MANDATORY**: Generate a Dynamic Event every day using the `surfaceUpdate` tool.
   - **MANDATORY**: Use the `DecisionCard` component.
   - **LIFECYCLE**:
     - The `SubmitButton` closes the dialog on the client.
     - **WAIT** for the user to click a button.
     - **STOP GENERATING** after `surfaceUpdate`.
     - **DO NOT** call `deleteSurface` immediately. Wait for the NEXT turn or user action.
     - When you receive the `UserActionEvent`, **THEN** call `deleteSurface`.

   **Example Tool Call (JSON):**
   ```json
   {
    "surfaceId": "event_modal",
    "components": [
      {
        "id": "event_root",
        "component": {
          "DecisionCard": {
            "title": "Merchant Arrival",
            "description": "A merchant offers 50 wood for 20 food.",
            "children": [
              {
                "id": "c1",
                "component": { "SubmitButton": { "label": "Accept", "actionName": "trade_wood", "payload": { "cost_food": 20, "gain_wood": 50 } } }
              },
              {
                "id": "c2",
                "component": { "SubmitButton": { "label": "Decline", "actionName": "decline_trade" } }
              }
            ]
          }
        }
      }
    ]
   }
   ```

**CRITICAL: UNIT IDs**
- Units have IDs like "u1", "u2", "u3".
- NEVER use coordinates (e.g. "11,5") as a unit ID.
- Example: `moveUnit(unitId: 'u1', ...)` is CORRECT.
- Example: `moveUnit(unitId: '11.0', ...)` is WRONG.

**CRITICAL: DAY RESET**
- When "--- Day X Ended ---" appears:
- **Reset your memory of current actions.** Previous orders are done.
- The units are waiting for *new* orders.

**CATALOG USAGE:**
- Use `EventCard` for major announcements.
- Use `MultipleChoice`, `IntegerInput`, etc. for user decisions.
- Be creative! Invent scenarios that test the user's resources (Food/Wood).

**INTELLIGENT REASONING:**
- Use `getMapDetails` before assuming where things are.
- Be proactive.
      ''',
      additionalTools: _gameTools.tools,
    );

    _genUiConversation = GenUiConversation(
      a2uiMessageProcessor: _a2uiMessageProcessor,
      contentGenerator: contentGenerator,
      onSurfaceAdded: (update) {
        if (update.surfaceId == 'event_modal') {
          if (mounted) {
            _showEventDialog();
          }
        } else {
          if (mounted) {
            setState(() {
              _timeline.add(SurfaceItem(update.surfaceId));
            });
            _scrollToBottom();
          }
        }
      },
      onSurfaceUpdated: (update) {
        if (update.surfaceId == 'event_modal') {
          // If it's not showing, show it.
          if (mounted &&
              (_eventDialogRoute == null || !_eventDialogRoute!.isActive)) {
            _showEventDialog();
          }
        }
      },
      onSurfaceDeleted: (update) {
        if (update.surfaceId == 'event_modal') {
          if (mounted &&
              _eventDialogRoute != null &&
              _eventDialogRoute!.isActive) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).removeRoute(_eventDialogRoute!);
            _eventDialogRoute = null;
          }
        }
        if (mounted) {
          setState(() {
            _timeline.removeWhere(
              (item) =>
                  item is SurfaceItem && item.surfaceId == update.surfaceId,
            );
          });
        }
      },
      onTextResponse: (text) {
        if (mounted) {
          setState(() {
            _timeline.add(TextItem(text, isUser: false));
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        genUiLogger.severe('Error:', error.error, error.stackTrace);
        if (mounted) {
          _showErrorDialog(error.error, error.stackTrace);
        }
      },
    );
  }

  Route? _eventDialogRoute;

  void _showEventDialog() {
    if (_eventDialogRoute != null && _eventDialogRoute!.isActive) return;

    _eventDialogRoute = DialogRoute(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.9,
              maxHeight: size.height * 0.9,
              minWidth: 400,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GenUiSurface(
                host: _a2uiMessageProcessor,
                surfaceId: 'event_modal',
              ),
            ),
          ),
        );
      },
    );

    Navigator.of(context, rootNavigator: true).push(_eventDialogRoute!).then((
      _,
    ) {
      _eventDialogRoute = null;
    });
  }

  bool _isErrorDialogOpen = false;

  void _showErrorDialog(Object error, StackTrace? stackTrace) {
    if (_isErrorDialogOpen) return;
    _isErrorDialogOpen = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Occurred'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
              if (stackTrace != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  stackTrace.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final text = 'Error: $error\n\nStack Trace:\n$stackTrace';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error details copied to clipboard'),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Details'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) {
      _isErrorDialogOpen = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.isEmpty) return;
    _textController.clear();
    setState(() {
      _timeline.add(TextItem(text, isUser: true));
    });
    _scrollToBottom();
    _genUiConversation.sendRequest(UserMessage.text(text));
  }

  @override
  void dispose() {
    _genUiConversation.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You are leading a settlement.'),
              SizedBox(height: 8),
              Text('• Ask "How much food do we have?" to see inventory.'),
              Text('• Say "Move the settlers to 5, 5" to explore.'),
              Text('• Say "Build a farm here" to grow food.'),
              SizedBox(height: 8),
              Text('The others will follow your lead.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_worldState.units.isNotEmpty) {
      print(
        'GamePage: Building. Day: ${_worldState.day} -- U1 Pos: (${_worldState.units[0].x}, ${_worldState.units[0].y})',
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Day ${_worldState.day} - ${_worldState.gameStatus.name.toUpperCase()}',
        ),
        backgroundColor: _worldState.gameStatus == GameStatus.lost
            ? Colors.red[100]
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: 'Game Hints',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Map
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Resource Pane (Top)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blueGrey[800],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        'Pop: ${_worldState.units.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Food: ${_worldState.resources['food']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Wood: ${_worldState.resources['wood']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Map Area
                Expanded(
                  child: Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: MapWidget(
                            worldState: _worldState,
                            onTileTap: (x, y) {
                              // Check if there's a unit here
                              final unit =
                                  _worldState.units.any(
                                    (u) => u.x == x && u.y == y,
                                  )
                                  ? 'The settler at '
                                  : '';

                              // Auto-fill chat input with coordinates
                              final currentText = _textController.text;
                              final newText = currentText.isEmpty
                                  ? '$unit($x, $y) '
                                  : '$currentText $unit($x, $y) ';
                              _textController.text = newText;
                              _textController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(offset: newText.length),
                                  );

                              if (!_inputFocusNode.hasFocus) {
                                _inputFocusNode.requestFocus();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom Control Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    border: Border(top: BorderSide(color: Colors.grey[400]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const MapLegend(),
                      FloatingActionButton.extended(
                        onPressed: _worldState.gameStatus == GameStatus.playing
                            ? () {
                                setState(() {
                                  final logs = _worldState.nextTurn();
                                  for (final log in logs) {
                                    _timeline.add(TextItem(log, isUser: false));
                                  }
                                  if (logs.isNotEmpty) {
                                    _genUiConversation.sendRequest(
                                      UserMessage.text(
                                        'System Report:\n${logs.join('\n')}\n'
                                        '-- Current State --\n'
                                        'Food: ${_worldState.food}\n'
                                        'Wood: ${_worldState.wood}\n'
                                        'Population: ${_worldState.population}',
                                      ),
                                    );
                                  }
                                });
                              }
                            : null,
                        label: const Text('End Day'),
                        icon: const Icon(Icons.nightlight_round),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Command Center
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _genUiConversation.isProcessing,
                    builder: (context, isProcessing, child) {
                      if (_timeline.isEmpty) {
                        return const Center(
                          child: Text(
                            'Welcome to the Settlement.\n'
                            'We need your guidance to survive.\n'
                            'Try: "Check our supplies" or "Move settlers to 5,5"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _timeline.length + (isProcessing ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _timeline.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = _timeline[index];
                          if (item is TextItem) {
                            return Align(
                              alignment: item.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item.isUser
                                      ? Colors.blue[100]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(item.text),
                              ),
                            );
                          } else if (item is SurfaceItem) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: GenUiSurface(
                                host: _genUiConversation.host,
                                surfaceId: item.surfaceId,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.enter) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                // Let system handle Shift+Enter (newline)
                                return KeyEventResult.ignored;
                              } else {
                                _sendMessage();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            focusNode: _inputFocusNode,
                            controller: _textController,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: 'What should we do next?',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                            // onSubmitted is not called for multiline usually, but we keep it just in case
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

abstract class TimelineItem {}

class TextItem extends TimelineItem {
  final String text;
  final bool isUser;
  TextItem(this.text, {required this.isUser});
}

class SurfaceItem extends TimelineItem {
  final String surfaceId;
  SurfaceItem(this.surfaceId);
}
