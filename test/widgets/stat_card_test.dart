import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/widgets/stat_card.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('StatCard displays title, value and icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const StatCard(
          title: 'Consommation',
          value: '120 kWh',
          icon: Icons.bolt,
          color: Colors.blue,
          trend: 0.0,
        ),
      ),
    );

    expect(find.text('Consommation'), findsOneWidget);
    expect(find.text('120 kWh'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.byIcon(Icons.trending_down), findsNothing);
  });

  testWidgets('StatCard shows positive trend with green color and trending_up icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const StatCard(
          title: 'Consommation',
          value: '120 kWh',
          icon: Icons.bolt,
          color: Colors.blue,
          trend: 5.5,
        ),
      ),
    );

    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    expect(find.text('5.5%'), findsOneWidget);

    final Text trendText = tester.widget(find.text('5.5%'));
    expect(trendText.style?.color, Colors.green);
  });

  testWidgets('StatCard shows negative trend with red color and trending_down icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const StatCard(
          title: 'Consommation',
          value: '120 kWh',
          icon: Icons.bolt,
          color: Colors.blue,
          trend: -3.2,
        ),
      ),
    );

    expect(find.byIcon(Icons.trending_down), findsOneWidget);
    expect(find.text('3.2%'), findsOneWidget);

    final Text trendText = tester.widget(find.text('3.2%'));
    expect(trendText.style?.color, Colors.red);
  });

  testWidgets('StatCard triggers onTap callback when tapped', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      buildTestableWidget(
        StatCard(
          title: 'Consommation',
          value: '120 kWh',
          icon: Icons.bolt,
          color: Colors.blue,
          trend: 0.0,
          onTap: () {
            tapped = true;
          },
        ),
      ),
    );

    await tester.tap(find.byType(StatCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
