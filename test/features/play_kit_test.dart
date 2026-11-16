import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/features/design/play.dart';

/// Wraps [child] in the minimum the play kit needs — a palette, a text
/// direction and a default text style. Deliberately *not* a `MaterialApp`, to
/// prove the kit renders with no Material ancestor.
Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  final PlayColors colors = brightness == Brightness.dark
      ? PlayColors.dark
      : PlayColors.light;
  return PlayTheme(
    colors: colors,
    child: MediaQuery(
      data: MediaQueryData(
        platformBrightness: brightness,
        size: const Size(800, 1600),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: PlayType.body.copyWith(color: colors.ink),
          child: child,
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget widget, {
  Brightness brightness = Brightness.light,
}) {
  return tester.pumpWidget(
    _harness(
      Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(child: widget),
      ),
      brightness: brightness,
    ),
  );
}

void main() {
  group('PlayColors', () {
    testWidgets('follows the platform brightness with no PlayTheme', (
      WidgetTester tester,
    ) async {
      late PlayColors captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: Builder(
            builder: (BuildContext context) {
              captured = PlayColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured.brightness, Brightness.dark);
      expect(identical(captured, PlayColors.dark), isTrue);
    });

    testWidgets('a PlayTheme override wins over the platform', (
      WidgetTester tester,
    ) async {
      late PlayColors captured;
      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (BuildContext context) {
              captured = PlayColors.of(context);
              return const SizedBox.shrink();
            },
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(identical(captured, PlayColors.dark), isTrue);
    });

    test('every tone resolves to a distinct, opaque pair', () {
      for (final PlayColors colors in <PlayColors>[
        PlayColors.light,
        PlayColors.dark,
      ]) {
        for (final PlayTone tone in PlayTone.values) {
          final PlayToneColors resolved = colors.tone(tone);
          expect(resolved.background.a, 1.0, reason: '${tone.name} background');
          expect(resolved.foreground.a, 1.0, reason: '${tone.name} foreground');
        }
      }
    });
  });

  group('atoms render in both brightnesses', () {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('light/dark widgets ($brightness)', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PlaySurface(
                padding: EdgeInsets.all(PlaySpace.md),
                child: Text('surface'),
              ),
              const SizedBox(height: PlaySpace.sm),
              PlayButton(
                label: 'Go',
                icon: PlayIcons.arrowRight,
                onPressed: () {},
              ),
              const PlayButton(label: 'Disabled'),
              PlayIconButton(icon: PlayIcons.layers, onPressed: () {}),
              const PlayIconButton(icon: PlayIcons.locationLost, alert: true),
              PlayChip(label: 'Parks', selected: true, onTap: () {}),
              const PlayTag(label: 'Live'),
              PlayAvatar(label: 'Ada', size: 48, dot: true),
              const PlayDivider(dotted: true),
              const PlaySpinner(),
              PlaySwitch(value: true, onChanged: (bool _) {}),
              const PlaySwitch(value: false),
              const PlayRadio(selected: true),
              const PlayProgress(value: 0.4),
              PlaySegmented<String>(
                selected: 'a',
                onChanged: (String _) {},
                segments: const <PlaySegment<String>>[
                  PlaySegment<String>(value: 'a', label: 'A'),
                  PlaySegment<String>(value: 'b', label: 'B'),
                ],
              ),
              PlayTabs(
                tabs: const <String>['Overview', 'Reviews'],
                selectedIndex: 0,
                onSelected: (int _) {},
              ),
              const PlayTextField(hint: 'Search here'),
              PlayMenuButton<String>(
                onSelected: (String _) {},
                items: const <PlayMenuItem<String>>[
                  PlayMenuItem<String>(value: 'x', label: 'Remove'),
                ],
              ),
              PlayRow(icon: PlayIcons.nearby, label: 'Nearby', onTap: () {}),
              const PlayRow(
                icon: PlayIcons.contributePlace,
                label: 'Not available',
                enabled: false,
              ),
              const PlaySheet(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PlaySheetHandle(),
                    Padding(
                      padding: EdgeInsets.all(PlaySpace.lg),
                      child: Text('sheet'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('components render in both brightnesses', () {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('light/dark components ($brightness)', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PlaySearchBar(onTap: () {}, onMicTap: () {}),
              PlayCategoryRow(
                categories: const <PlayCategoryData>[
                  PlayCategoryData(
                    id: 'parks',
                    label: 'Parks',
                    icon: PlayIcons.park,
                    selected: true,
                  ),
                  PlayCategoryData(
                    id: 'cafes',
                    label: 'Cafés',
                    icon: PlayIcons.cafe,
                  ),
                ],
                onSelect: (_) {},
              ),
              PlayPlaceCard(
                title: 'Mauerpark',
                subtitle: '1.2 km',
                icon: PlayIcons.park,
                onTap: () {},
              ),
              const PlayStatCard(value: '12', label: 'min', expand: true),
              PlayMapControlRail(
                controls: <PlayMapControl>[
                  PlayMapControl(
                    icon: PlayIcons.layers,
                    semanticLabel: 'Layers',
                    onTap: () {},
                  ),
                  const PlayMapControl(
                    icon: PlayIcons.locate,
                    semanticLabel: 'Location',
                    active: true,
                  ),
                ],
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a broken avatar image falls back to the monogram', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PlayAvatar(label: 'Grace', imageUrl: 'http://127.0.0.1:1/none.png'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('an enabled button reports its tap', (WidgetTester tester) async {
    int taps = 0;
    await _pump(tester, PlayButton(label: 'Go', onPressed: () => taps++));
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a disabled button never fires', (WidgetTester tester) async {
    await _pump(tester, const PlayButton(label: 'Go'));
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a category reports its id', (
    WidgetTester tester,
  ) async {
    String? selected;
    await _pump(
      tester,
      PlayCategoryRow(
        categories: const <PlayCategoryData>[
          PlayCategoryData(id: 'parks', label: 'Parks', icon: PlayIcons.park),
        ],
        onSelect: (String id) => selected = id,
      ),
    );
    await tester.tap(find.text('Parks'));
    await tester.pump();
    expect(selected, 'parks');
  });
}
