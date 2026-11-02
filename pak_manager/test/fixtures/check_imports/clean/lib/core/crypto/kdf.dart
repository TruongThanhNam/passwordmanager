import 'dart:math' as math;

import 'package:sodium/sodium_sumo.dart';
import 'package:zxcvbnm/zxcvbnm.dart';

int clamp(int value) => math.max(2, math.min(value, 10));
