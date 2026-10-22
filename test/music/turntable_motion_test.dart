import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/turntable_motion.dart';

void main() {
  late List<String> cued;
  late TurntableMotion motion;

  setUp(() {
    cued = [];
    motion = TurntableMotion(onNeedlePlaced: cued.add);
  });
  tearDown(() => motion.dispose());

  test('spins indefinitely at standard speed while audio is not ready', () {
    motion.update(itemId: 'one', ready: false, paused: false);
    motion.advance(const Duration(seconds: 4));
    expect(motion.phase, TurntablePhase.waiting);
    expect(motion.recordPlacement, 1);
    expect(motion.rpm, closeTo(100 / 3, 0.001));
    final rotation = motion.rotation;
    motion.advance(const Duration(seconds: 20));
    expect(motion.rotation, isNot(closeTo(rotation, 0.01)));
    expect(motion.arm, 0);
    expect(cued, isEmpty);

    motion.update(itemId: 'one', ready: true, paused: false);
    motion.advance(const Duration(milliseconds: 700));
    expect(motion.phase, TurntablePhase.cueing);
    expect(motion.arm, inExclusiveRange(0, 1));
    expect(cued, isEmpty);
    motion.advance(const Duration(milliseconds: 600));
    expect(motion.phase, TurntablePhase.playing);
    expect(motion.needleLift, 0);
    expect(cued, ['one']);
    motion.advance(const Duration(seconds: 5));
    expect(cued, ['one']);
  });

  test('a cached track still waits for placement and full spin-up', () {
    motion.update(itemId: 'cached', ready: true, paused: false);
    motion.advance(const Duration(milliseconds: 2900));
    expect(motion.phase, TurntablePhase.spinningUp);
    expect(motion.rpm, inExclusiveRange(0, TurntableMotion.standardRpm));
    expect(motion.arm, 0);
    expect(cued, isEmpty);
    motion.advance(const Duration(seconds: 2));
    expect(cued, ['cached']);
  });

  test('pause during cueing prevents audio start until resumed', () {
    motion.update(itemId: 'one', ready: true, paused: false);
    motion.advance(const Duration(seconds: 4));
    expect(motion.phase, TurntablePhase.cueing);
    motion.update(itemId: 'one', ready: true, paused: true);
    final arm = motion.arm;
    motion.advance(const Duration(seconds: 10));
    expect(motion.arm, arm);
    expect(cued, isEmpty);
    motion.update(itemId: 'one', ready: true, paused: false);
    motion.advance(const Duration(seconds: 1));
    expect(cued, ['one']);
    motion.update(itemId: 'one', ready: true, paused: true);
    motion.advance(const Duration(seconds: 3));
    expect(motion.rpm, lessThan(0.01));
    motion.update(itemId: 'one', ready: true, paused: false);
    motion.advance(const Duration(seconds: 3));
    expect(motion.rpm, closeTo(TurntableMotion.standardRpm, 0.01));
    expect(cued, ['one']);
  });

  test('a skip during cueing returns the arm before changing records', () {
    motion.update(itemId: 'one', ready: true, paused: false);
    motion.advance(const Duration(seconds: 4));
    motion.update(itemId: 'two', ready: false, paused: false);
    motion.advance(const Duration(milliseconds: 400));
    expect(motion.phase, TurntablePhase.lifting);
    expect(motion.itemId, 'one');
    expect(cued, isEmpty);
    motion.advance(const Duration(milliseconds: 1200));
    expect(motion.itemId, 'two');
    expect(motion.arm, 0);
    motion.advance(const Duration(seconds: 4));
    expect(motion.phase, TurntablePhase.waiting);
    expect(cued, isEmpty);
    motion.update(itemId: 'two', ready: true, paused: false);
    motion.advance(const Duration(seconds: 2));
    expect(cued, ['two']);
    motion.update(itemId: null, ready: false, paused: false);
    motion.advance(const Duration(seconds: 3));
    expect(motion.phase, TurntablePhase.hidden);
    expect(motion.visibility, 0);
    expect(motion.itemId, isNull);
  });
}
