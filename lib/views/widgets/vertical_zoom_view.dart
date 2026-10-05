import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Vertical-only zoom for a chart. A pinch stretches the child's height (it
/// is laid out taller, not scaled as a picture, so a chart can show what it
/// had no room for), and one finger scrolls what no longer fits, with the
/// platform's scroll physics. The height goes from the viewport's own (no
/// zoom) to [maxZoom] times it; the content under the fingers stays under
/// them while they pinch.
class VerticalZoomView extends StatefulWidget {
  const VerticalZoomView({super.key, this.maxZoom = 8, required this.child});

  /// How many times the viewport's height the content may be stretched to.
  final double maxZoom;
  final Widget child;

  @override
  State<VerticalZoomView> createState() => _VerticalZoomViewState();
}

class _VerticalZoomViewState extends State<VerticalZoomView> {
  final _controller = ScrollController();
  double _zoom = 1;
  double _viewport = 0;

  /// The one-finger scroll in progress. The scroll view ignores pointers
  /// itself (the scale recognizer would fight its drag recognizer), so the
  /// scroll is driven through its position, which applies the usual physics.
  Drag? _drag;
  int _pointers = 0;
  double _startZoom = 1;
  double _startOffset = 0;
  double _startFocalY = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rebase(double focalY) {
    _startZoom = _zoom;
    _startOffset = _controller.hasClients ? _controller.offset : 0;
    _startFocalY = focalY;
  }

  void _startDrag(Offset global, Offset local) {
    if (!_controller.hasClients) return;
    _drag = _controller.position.drag(
      DragStartDetails(globalPosition: global, localPosition: local),
      () => _drag = null,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pointers = details.pointerCount;
    _rebase(details.localFocalPoint.dy);
    if (_pointers == 1) {
      _startDrag(details.focalPoint, details.localFocalPoint);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != _pointers) {
      // A finger came or went: the recognizer starts its scale over, and so
      // does the zoom; a scroll in progress ends.
      _pointers = details.pointerCount;
      _drag?.cancel();
      _drag = null;
      _rebase(details.localFocalPoint.dy);
      if (_pointers == 1) {
        _startDrag(details.focalPoint, details.localFocalPoint);
      }
    }
    if (_pointers >= 2) {
      final zoom = (_startZoom * details.verticalScale).clamp(
        1.0,
        widget.maxZoom,
      );
      if (zoom == _zoom) return;
      // The point of the content that was under the fingers when they came
      // down stretches with it; scrolling there keeps it under them.
      final contentY = (_startOffset + _startFocalY) * zoom / _startZoom;
      final offset = contentY - details.localFocalPoint.dy;
      setState(() => _zoom = zoom);
      // The new extent exists once this frame has laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpTo(
          offset.clamp(0.0, _controller.position.maxScrollExtent),
        );
      });
    } else {
      _drag?.update(
        DragUpdateDetails(
          globalPosition: details.focalPoint,
          localPosition: details.localFocalPoint,
          delta: Offset(0, details.focalPointDelta.dy),
          primaryDelta: details.focalPointDelta.dy,
        ),
      );
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _drag?.end(
      DragEndDetails(
        velocity: details.velocity,
        primaryVelocity: details.velocity.pixelsPerSecond.dy,
      ),
    );
    _drag = null;
    _pointers = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.maxHeight;
        return GestureDetector(
          // Measure the pinch from where the fingers came down, not from
          // where the gesture was told apart from a tap, so the content
          // follows the fingers exactly.
          dragStartBehavior: DragStartBehavior.down,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: SingleChildScrollView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(height: _viewport * _zoom, child: widget.child),
          ),
        );
      },
    );
  }
}
