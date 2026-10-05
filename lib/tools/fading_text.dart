import 'package:flutter/material.dart';

class FadingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const FadingText(this.text, {super.key, this.style});

  @override
  State<FadingText> createState() => _FadingTextState();
}

class _FadingTextState extends State<FadingText> {
  bool isOverflowing = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(FadingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  void _checkOverflow() {
    final RenderBox? textRenderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? parentRenderBox = context.findRenderObject() as RenderBox?;

    if (textRenderBox != null && parentRenderBox != null) {
      final textWidth = textRenderBox.size.width;
      final parentWidth = parentRenderBox.size.width;
      final newIsOverflowing = textWidth > parentWidth;

      if (isOverflowing != newIsOverflowing && mounted) {
        setState(() {
          isOverflowing = newIsOverflowing;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      widget.text,
      key: _textKey,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    if (isOverflowing) {
      return ShaderMask(
        shaderCallback: (Rect bounds) {
          final textColor = widget.style?.color ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
          return LinearGradient(
            colors: [textColor, Colors.transparent],
            stops: const [0.8, 1.0],
            tileMode: TileMode.clamp,
          ).createShader(bounds);
        },
        child: textWidget,
      );
    }

    return textWidget;
  }
}