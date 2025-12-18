import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui/src/catalog/core_widgets/widget_helpers.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final resourceDisplay = CatalogItem(
  name: 'ResourceDisplay',
  dataSchema: S.object(
    description: 'Displays the current global resources (food, wood).',
    properties: {
      'food': S.number(description: 'Amount of food'),
      'wood': S.number(description: 'Amount of wood'),
    },
    required: ['food', 'wood'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>? ?? {};
    final foodData = data['food'];
    final foodNotifier = foodData is num
        ? ValueNotifier<num?>(foodData)
        : context.dataContext.subscribe<num>(DataPath('food'));

    final woodData = data['wood'];
    final woodNotifier = woodData is num
        ? ValueNotifier<num?>(woodData)
        : context.dataContext.subscribe<num>(DataPath('wood'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ResourceItem(
              icon: Icons.lunch_dining,
              label: 'Food',
              valueNotifier: foodNotifier,
              color: Colors.orange,
            ),
            _ResourceItem(
              icon: Icons.forest,
              label: 'Wood',
              valueNotifier: woodNotifier,
              color: Colors.brown,
            ),
          ],
        ),
      ),
    );
  },
  exampleData: [
    () => '''
      {
        "ResourceDisplay": {
          "food": {"literalNumber": 100},
          "wood": {"literalNumber": 50}
        }
      }
    ''',
  ],
);

class _ResourceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ValueNotifier<num?> valueNotifier;
  final Color color;

  const _ResourceItem({
    required this.icon,
    required this.label,
    required this.valueNotifier,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<num?>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        return Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  '${value ?? 0}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

final eventCard = CatalogItem(
  name: 'EventCard',
  dataSchema: S.object(
    description: 'A card to display important game events or decisions.',
    properties: {
      'title': S.string(),
      'description': S.string(),
      'severity': S.string(
        description: 'info, warning, or critical',
        enumValues: ['info', 'warning', 'critical'],
      ),
    },
    required: ['title', 'description'],
  ),
  widgetBuilder: (context) {
    // simplified schema definition for now
    final data = context.data as Map<String, dynamic>? ?? {};
    final titleData = data['title'];
    final titleNotifier = titleData is String
        ? ValueNotifier<String?>(titleData)
        : context.dataContext.subscribe<String>(DataPath('title'));

    final descriptionData = data['description'];
    final descriptionNotifier = descriptionData is String
        ? ValueNotifier<String?>(descriptionData)
        : context.dataContext.subscribe<String>(DataPath('description'));
    // Severity could be used for color

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: titleNotifier,
              builder: (context, title, _) => Text(
                title ?? 'Event',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.red),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: descriptionNotifier,
              builder: (context, desc, _) => Text(desc ?? ''),
            ),
          ],
        ),
      ),
    );
  },
);

final submitButton = CatalogItem(
  name: 'SubmitButton',
  dataSchema: S.object(
    description: 'A button that submits a decision and closes the dialog.',
    properties: {
      'label': S.string(),
      'actionName': S.string(),
      'payload': S.object(),
    },
    required: ['label', 'actionName'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>? ?? {};
    final label = data['label'] as String? ?? 'Submit';
    final actionName = data['actionName'] as String? ?? 'submit';
    final payload = data['payload'] as Map<String, dynamic>? ?? {};

    return ElevatedButton(
      onPressed: () {
        context.dispatchEvent(
          UserActionEvent(
            name: actionName,
            context: payload,
            sourceComponentId: context.id,
          ),
        );
        print('DecisionCard: Closing dialog via Navigator.pop');
        Navigator.of(context.buildContext).pop();
      },
      child: Text(label),
    );
  },
);

final colonyCatalog = Catalog([
  CoreCatalogItems.button,
  CoreCatalogItems.card,
  CoreCatalogItems.checkBox,
  CoreCatalogItems.column,
  CoreCatalogItems.dateTimeInput,
  CoreCatalogItems.divider,
  CoreCatalogItems.icon,
  CoreCatalogItems.image,
  CoreCatalogItems.list,
  CoreCatalogItems.modal,
  CoreCatalogItems.multipleChoice,
  CoreCatalogItems.row,
  CoreCatalogItems.slider,
  CoreCatalogItems.tabs,
  CoreCatalogItems.text,
  CoreCatalogItems.textField,
  // Excluding video and audioPlayer
  resourceDisplay,
  eventCard,
  decisionCard,
  submitButton,
], catalogId: 'colony_catalog');

final decisionCard = CatalogItem(
  name: 'DecisionCard',
  dataSchema: S.object(
    description: 'A card to display an event with arbitrary content.',
    properties: {
      'title': S.string(),
      'description': S.string(),
      'children': A2uiSchemas.componentArrayReference(
        description: 'Content widgets (e.g. TextFields, Buttons).',
      ),
    },
    required: ['title', 'description', 'children'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>? ?? {};
    final title = data['title'] as String? ?? 'Decision';
    final description = data['description'] as String? ?? '';
    final childrenData = data['children'];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  itemContext.buildContext,
                ).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(description, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ComponentChildrenBuilder(
                childrenData: childrenData,
                dataContext: itemContext.dataContext,
                buildChild: itemContext.buildChild,
                getComponent: itemContext.getComponent,
                explicitListBuilder: (childIds, buildChild, getComponent, _) {
                  return Column(
                    children: childIds.map((id) => buildChild(id)).toList(),
                  );
                },
                templateListWidgetBuilder:
                    (context, list, componentId, binding) {
                      return Column(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            itemContext.buildChild(componentId),
                        ],
                      );
                    },
              ),
            ],
          ),
        ),
      ),
    );
  },
);
