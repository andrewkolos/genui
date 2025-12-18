import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import '../model/world_state.dart';

class GameTools {
  final WorldState worldState;
  final void Function() onStateChanged;
  final void Function(Object error, StackTrace stackTrace)? onError;

  GameTools({
    required this.worldState,
    required this.onStateChanged,
    this.onError,
  });

  List<AiTool> get tools => [
    _moveUnitTool,
    _buildStructureTool,
    _getResourcesTool,
    _getMapDetailsTool,
  ];

  late final AiTool _getResourcesTool = DynamicAiTool(
    name: 'getResources',
    description: 'Returns the current global resources.',
    parameters: S.object(properties: {}, required: []),
    invokeFunction: (Map<String, Object?> args) async {
      try {
        return {'resources': worldState.resources};
      } catch (e, s) {
        onError?.call(e, s);
        rethrow;
      }
    },
  );

  late final AiTool _moveUnitTool = DynamicAiTool(
    name: 'moveUnit',
    description: 'Moves a unit to a specific coordinate.',
    parameters: S.object(
      properties: {
        'unitId': S.string(description: 'ID of the unit to move'),
        'x': S.integer(description: 'Target X coordinate'),
        'y': S.integer(description: 'Target Y coordinate'),
      },
      required: ['unitId', 'x', 'y'],
    ),
    invokeFunction: (Map<String, Object?> args) async {
      try {
        final unitId = args['unitId'] as String;
        final x = (args['x'] as num).toInt();
        final y = (args['y'] as num).toInt();

        final unit = worldState.units.firstWhere(
          (u) => u.id == unitId,
          orElse: () => throw Exception('Unit not found'),
        );

        // onStateChanged(); // No state change yet!
        unit.pendingAction = MoveAction(x, y);
        print('DEBUG: Queued move for $unitId to $x,$y');
        return {
          'result':
              'Queued move order for unit $unitId to ($x, $y). Execution awaits End Day.',
        };
      } catch (e, s) {
        final detailedError = 'Tool: moveUnit\nArgs: $args\nError: $e';
        onError?.call(detailedError, s);
        rethrow;
      }
    },
  );

  late final AiTool _getMapDetailsTool = DynamicAiTool(
    name: 'getMapDetails',
    description: 'Returns map dimensions and terrain grid.',
    parameters: S.object(properties: {}, required: []),
    invokeFunction: (Map<String, Object?> args) async {
      try {
        final water = <Map<String, int>>[];
        final mountains = <Map<String, int>>[];

        for (int y = 0; y < worldState.height; y++) {
          for (int x = 0; x < worldState.width; x++) {
            final t = worldState.terrain[y][x];
            if (t == TileType.water) {
              water.add({'x': x, 'y': y});
            } else if (t == TileType.mountain) {
              mountains.add({'x': x, 'y': y});
            }
          }
        }

        return {
          'width': worldState.width,
          'height': worldState.height,
          'defaultTile': 'Grass',
          'units': worldState.units
              .map(
                (u) => {
                  'id': u.id,
                  'x': u.x,
                  'y': u.y,
                  'type': u.type.name,
                  'pendingAction': u.pendingAction != null
                      ? 'Start of Day Action Queued'
                      : 'Idle',
                },
              )
              .toList(),
          'structures': worldState.structures
              .map((s) => {'id': s.id, 'x': s.x, 'y': s.y, 'type': s.type.name})
              .toList(),
          'water_tiles': water,
          'mountain_tiles': mountains,
        };
      } catch (e, s) {
        onError?.call(e, s);
        rethrow;
      }
    },
  );

  late final AiTool _buildStructureTool = DynamicAiTool(
    name: 'buildStructure',
    description:
        'Creates a structure at a location. Costs resources. Validates terrain and occupancy.',
    parameters: S.object(
      properties: {
        'unitId': S.string(
          description: 'ID of the unit building the structure',
        ),
        'type': S.string(
          description: 'Type of structure (base, farm)',
          enumValues: ['base', 'farm'],
        ),
        'x': S.integer(description: 'X coordinate (0-19)'),
        'y': S.integer(description: 'Y coordinate (0-19)'),
      },
      required: ['unitId', 'type', 'x', 'y'],
    ),
    invokeFunction: (Map<String, Object?> args) async {
      try {
        final unitId = args['unitId'] as String;
        final typeStr = args['type'] as String;
        final x = (args['x'] as num).toInt();
        final y = (args['y'] as num).toInt();

        final unit = worldState.units.firstWhere(
          (u) => u.id == unitId,
          orElse: () => throw Exception('Unit not found'),
        );

        // Queue action
        final type = StructureType.values.firstWhere((e) => e.name == typeStr);
        unit.pendingAction = BuildAction(type, x, y);

        // State check logic removed for now as it will happen at runtime
        // But we could keep some pre-checks if desired.
        // For now, just queue it.

        return {
          'result':
              'Queued build order for unit $unitId to build $typeStr at ($x, $y). Execution awaits End Day.',
        };
      } catch (e, s) {
        final detailedError = 'Tool: buildStructure\nArgs: $args\nError: $e';
        onError?.call(detailedError, s);
        rethrow;
      }
    },
  );
}
