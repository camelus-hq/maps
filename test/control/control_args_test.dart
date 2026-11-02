import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/control/control_args.dart';

void main() {
  group('ControlArgs.parse', () {
    test('reads --control <port> and --control=<port>', () {
      expect(ControlArgs.parse(<String>['--control', '7981']).port, 7981);
      expect(ControlArgs.parse(<String>['--control=7981']).port, 7981);
    });

    test('ignores missing, non-numeric and out-of-range values', () {
      expect(ControlArgs.parse(<String>[]).port, isNull);
      expect(ControlArgs.parse(<String>['--control']).port, isNull);
      expect(ControlArgs.parse(<String>['--control', 'abc']).port, isNull);
      expect(ControlArgs.parse(<String>['--control', '0']).port, isNull);
      expect(ControlArgs.parse(<String>['--control', '70000']).port, isNull);
    });
  });
}
