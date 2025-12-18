import 'dart:math';

class WorldState {
  final int width;
  final int height;
  final List<List<TileType>> terrain;
  final List<Unit> units;
  final List<Structure> structures;
  final Map<String, int> resources;
  int day;
  GameStatus gameStatus;
  final List<String> logs;

  WorldState({
    required this.width,
    required this.height,
    required this.terrain,
    required this.units,
    required this.structures,
    required this.resources,
    this.day = 1,
    this.gameStatus = GameStatus.playing,
    this.logs = const [],
  });

  int get food => resources['food'] ?? 0;
  int get wood => resources['wood'] ?? 0;
  int get population => units.length; // Simplified for now

  factory WorldState.initial(int width, int height) {
    final random = Random();
    final terrain = List.generate(height, (y) {
      return List.generate(width, (x) {
        final noise = random.nextDouble();
        if (noise < 0.1) return TileType.mountain;
        if (noise < 0.3) return TileType.water;
        return TileType.grass;
      });
    });

    // Ensure valid start positions
    int startX, startY;
    do {
      startX = random.nextInt(width);
      startY = random.nextInt(height);
    } while (terrain[startY][startX] != TileType.grass);

    // Helper to find valid grass neighbors
    List<Point<int>> findGrassNeighbors(int cx, int cy, int count) {
      final valid = <Point<int>>[];
      // Directions: right, left, down, up, and diagonals if needed
      final dirs = [
        const Point(1, 0),
        const Point(-1, 0),
        const Point(0, 1),
        const Point(0, -1),
        const Point(1, 1),
        const Point(-1, -1),
        const Point(1, -1),
        const Point(-1, 1),
      ];

      for (final d in dirs) {
        if (valid.length >= count) break;
        final nx = cx + d.x;
        final ny = cy + d.y;

        if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
          if (terrain[ny][nx] == TileType.grass) {
            valid.add(Point(nx, ny));
          }
        }
      }
      return valid;
    }

    final neighbors = findGrassNeighbors(startX, startY, 2);
    // If we can't find enough neighbors, just stack them (fallback) or retry?
    // For simplicity, if we fail, just use startX/startY (better than mountain)
    // or search wider.
    // Let's just use startX,startY as fallback for safety to avoid infinite loops or complex retry logic here.

    final u2Pos = neighbors.isNotEmpty ? neighbors[0] : Point(startX, startY);
    final basePos = neighbors.length > 1 ? neighbors[1] : Point(startX, startY);

    return WorldState(
      width: width,
      height: height,
      terrain: terrain,
      units: [
        Unit(id: 'u1', x: startX, y: startY, type: UnitType.colonist),
        Unit(id: 'u2', x: u2Pos.x, y: u2Pos.y, type: UnitType.colonist),
      ],
      structures: [
        Structure(
          id: 's1',
          x: basePos.x,
          y: basePos.y,
          type: StructureType.base,
        ),
      ],
      resources: {'food': 50, 'wood': 100},
      logs: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'terrain': terrain.map((row) => row.map((t) => t.name).toList()).toList(),
      'units': units.map((u) => u.toJson()).toList(),
      'structures': structures.map((s) => s.toJson()).toList(),
      'resources': resources,
      'day': day,
      'status': gameStatus.name,
      'logs': logs,
    };
  }

  List<String> nextTurn() {
    if (gameStatus != GameStatus.playing) return [];

    final newLogs = <String>[];
    newLogs.add('--- Day $day Ended ---');

    // 0. Execute Pending Actions
    print('WorldState: processing ${units.length} units');
    for (final unit in units) {
      if (unit.pendingAction == null) {
        newLogs.add('${unit.id} did nothing.');
        continue;
      }

      final action = unit.pendingAction!;
      print(
        'WorldState: ${unit.id} has action $action (${action.runtimeType})',
      );
      if (action is MoveAction) {
        // Validate
        if (action.x >= 0 &&
            action.x < width &&
            action.y >= 0 &&
            action.y < height) {
          // For now, no collision check with other units for movement simplicity?
          // Or basic terrain check
          if (terrain[action.y][action.x] != TileType.mountain &&
              terrain[action.y][action.x] != TileType.water) {
            unit.x = action.x;
            unit.y = action.y;
            newLogs.add('${unit.id} moved to (${action.x}, ${action.y}).');
          } else {
            newLogs.add(
              '${unit.id} tried to move to invalid terrain at (${action.x}, ${action.y}).',
            );
          }
        } else {
          newLogs.add('${unit.id} tried to move out of bounds.');
        }
      } else if (action is BuildAction) {
        // Check resources (simple check logs if failed)
        // Simplified: We assume farms are free or cheap? No, explicit check needed if we want logic.
        // Let's assume farms cost 10 wood?
        // User didn't specify costs, but previously it was implicit.
        // I will just allow it for now or check if there is a structure there.
        final existing = structures.any(
          (s) => s.x == action.x && s.y == action.y,
        );
        if (existing) {
          newLogs.add('${unit.id} tried to build on occupied tile.');
        } else {
          structures.add(
            Structure(
              id: 's_${day}_${unit.id}',
              x: action.x,
              y: action.y,
              type: action.type,
            ),
          );
          newLogs.add(
            '${unit.id} built a ${action.type.name} at (${action.x}, ${action.y}).',
          );
        }
      }
      unit.pendingAction = null; // Reset
    }
    int food = resources['food'] ?? 0;
    int wood = resources['wood'] ?? 0;
    final population = units.length;
    final foodConsumed = population * 2; // Increased consumption

    food -= foodConsumed;
    newLogs.add('Colonists ate $foodConsumed food.');

    if (food < 0) {
      final deaths = ((-food) / 2).ceil();
      food = 0;
      int unitsToKill = min(deaths, units.length);
      if (unitsToKill > 0) {
        units.removeRange(0, unitsToKill);
        newLogs.add('$unitsToKill colonists died of starvation!');
      }
    }

    // 2. Production
    int foodProduced = 0;
    for (final struct in structures) {
      if (struct.type == StructureType.farm) {
        foodProduced += 10; // Farms produce 10 food
      }
    }
    food += foodProduced;
    if (foodProduced > 0) {
      newLogs.add('Farms produced $foodProduced food.');
    }

    // 3. Update Resources
    resources['food'] = food;
    resources['wood'] = wood;

    // 4. Update Cycle
    day++;
    logs.addAll(newLogs);

    // 5. Win/Loss Check
    if (units.isEmpty) {
      gameStatus = GameStatus.lost;
      logs.add('GAME OVER: All colonists have perished.');
    } else if (day > 30) {
      gameStatus = GameStatus.won;
      logs.add('VICTORY: You survived 30 days!');
    }
    return newLogs;
  }
}

enum GameStatus { playing, won, lost }

enum TileType { grass, water, mountain }

enum UnitType { colonist }

class Unit {
  final String id;
  int x;
  int y;
  final UnitType type;
  UnitAction? pendingAction;

  Unit({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    this.pendingAction,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'type': type.name,
    'pendingAction': pendingAction?.toString(),
  };
}

sealed class UnitAction {}

class MoveAction extends UnitAction {
  final int x;
  final int y;
  MoveAction(this.x, this.y);
}

class BuildAction extends UnitAction {
  final StructureType type;
  final int x;
  final int y;
  BuildAction(this.type, this.x, this.y);
}

enum StructureType { base, farm }

class Structure {
  final String id;
  final int x;
  final int y;
  final StructureType type;

  Structure({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'type': type.name,
  };
}
