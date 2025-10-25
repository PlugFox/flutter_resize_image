import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

base class _BindingBase = BindingBase
    with
        GestureBinding,
        SchedulerBinding,
        ServicesBinding,
        // PaintingBinding,
        PaintingBinding,
        CustomBinding;

mixin CustomBinding on BindingBase, ServicesBinding, PaintingBinding {}

final class Binding extends _BindingBase {
  Binding._() : super();

  static final Binding instance = Binding._();

  /// Минимальная инициализация
  void ensureInitialized() {
    instance
      //..ensureVisualUpdate()
      ..scheduleWarmUpFrame()
      ..handleBeginFrame(Duration.zero)
      ..handleDrawFrame();
  }
}
