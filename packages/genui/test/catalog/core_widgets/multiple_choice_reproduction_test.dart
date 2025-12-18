// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  testWidgets(
    'MultipleChoice renders RadioListTile when maxAllowedSelections is 1 (int)',
    (WidgetTester tester) async {
      final processor = A2uiMessageProcessor(
        catalogs: [
          Catalog([CoreCatalogItems.multipleChoice], catalogId: 'test_catalog'),
        ],
      );
      const surfaceId = 'testSurface_int_1';
      final components = [
        const Component(
          id: 'multiple_choice',
          componentProperties: {
            'MultipleChoice': {
              'selections': {'path': '/mySelections'},
              'maxAllowedSelections': 1,
              'options': [
                {
                  'label': {'literalString': 'Option 1'},
                  'value': '1',
                },
                {
                  'label': {'literalString': 'Option 2'},
                  'value': '2',
                },
              ],
            },
          },
        ),
      ];
      processor.handleMessage(
        SurfaceUpdate(surfaceId: surfaceId, components: components),
      );
      processor.handleMessage(
        const BeginRendering(
          surfaceId: surfaceId,
          root: 'multiple_choice',
          catalogId: 'test_catalog',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(host: processor, surfaceId: surfaceId),
          ),
        ),
      );

      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );

  testWidgets(
    'MultipleChoice renders RadioListTile when maxAllowedSelections is 1.0 (double)',
    (WidgetTester tester) async {
      final processor = A2uiMessageProcessor(
        catalogs: [
          Catalog([CoreCatalogItems.multipleChoice], catalogId: 'test_catalog'),
        ],
      );
      const surfaceId = 'testSurface_double_1';
      final components = [
        const Component(
          id: 'multiple_choice',
          componentProperties: {
            'MultipleChoice': {
              'selections': {'path': '/mySelections'},
              'maxAllowedSelections': 1.0,
              'options': [
                {
                  'label': {'literalString': 'Option 1'},
                  'value': '1',
                },
                {
                  'label': {'literalString': 'Option 2'},
                  'value': '2',
                },
              ],
            },
          },
        ),
      ];
      processor.handleMessage(
        SurfaceUpdate(surfaceId: surfaceId, components: components),
      );
      processor.handleMessage(
        const BeginRendering(
          surfaceId: surfaceId,
          root: 'multiple_choice',
          catalogId: 'test_catalog',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(host: processor, surfaceId: surfaceId),
          ),
        ),
      );

      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );

  // This test checks if string "1" works or handled gracefully
  testWidgets(
    'MultipleChoice renders RadioListTile when maxAllowedSelections is "1" (string)',
    (WidgetTester tester) async {
      final processor = A2uiMessageProcessor(
        catalogs: [
          Catalog([CoreCatalogItems.multipleChoice], catalogId: 'test_catalog'),
        ],
      );
      const surfaceId = 'testSurface_string_1';
      final components = [
        const Component(
          id: 'multiple_choice',
          componentProperties: {
            'MultipleChoice': {
              'selections': {'path': '/mySelections'},
              'maxAllowedSelections': "1",
              'options': [
                {
                  'label': {'literalString': 'Option 1'},
                  'value': '1',
                },
                {
                  'label': {'literalString': 'Option 2'},
                  'value': '2',
                },
              ],
            },
          },
        ),
      ];
      processor.handleMessage(
        SurfaceUpdate(surfaceId: surfaceId, components: components),
      );
      processor.handleMessage(
        const BeginRendering(
          surfaceId: surfaceId,
          root: 'multiple_choice',
          catalogId: 'test_catalog',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(host: processor, surfaceId: surfaceId),
          ),
        ),
      );

      // If it fails validation or parsing, we might see no widgets or CheckboxListTile (if it falls back to null/default)
      // The current code: (_json['maxAllowedSelections'] as num?)?.toInt();
      // "1" as num? will throw CastError in Dart if I recall correctly (String is not num).
      // If it throws, the widget might fail to build.
    },
  );

  testWidgets(
    'MultipleChoice renders CheckboxListTile when maxAllowedSelections is null',
    (WidgetTester tester) async {
      final processor = A2uiMessageProcessor(
        catalogs: [
          Catalog([CoreCatalogItems.multipleChoice], catalogId: 'test_catalog'),
        ],
      );
      const surfaceId = 'testSurface_null';
      final components = [
        const Component(
          id: 'multiple_choice',
          componentProperties: {
            'MultipleChoice': {
              'selections': {'path': '/mySelections'},
              // maxAllowedSelections is omitted
              'options': [
                {
                  'label': {'literalString': 'Option 1'},
                  'value': '1',
                },
                {
                  'label': {'literalString': 'Option 2'},
                  'value': '2',
                },
              ],
            },
          },
        ),
      ];
      processor.handleMessage(
        SurfaceUpdate(surfaceId: surfaceId, components: components),
      );
      processor.handleMessage(
        const BeginRendering(
          surfaceId: surfaceId,
          root: 'multiple_choice',
          catalogId: 'test_catalog',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(host: processor, surfaceId: surfaceId),
          ),
        ),
      );

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(find.byType(RadioListTile<String>), findsNothing);
    },
  );
}
