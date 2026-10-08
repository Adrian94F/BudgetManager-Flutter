import 'package:flutter/material.dart';

/// A grid with a fixed header row, fixed leading and trailing columns and
/// fixed footer rows around cells that scroll both ways, as the iOS table
/// does. The header and footers follow the cells sideways, the two columns
/// follow them up and down. Styling is the [cellBuilder]'s; this widget only
/// lays the cells out at the given sizes.
class CustomDataTable<T> extends StatefulWidget {
  /// The leading column, one cell per row.
  final List<T> fixedColCells;

  /// The trailing column, one cell per row.
  final List<T> fixedRightColCells;

  /// The header row, one cell per column.
  final List<T> fixedRowCells;

  /// The footer rows, each with one cell per column.
  final List<List<T>> fixedBottomRowsCells;

  /// The header's corners above the leading and the trailing column.
  final T headerLeadingCell;
  final T headerTrailingCell;

  /// The footers' corners, one per footer row.
  final List<T> footerLeadingCells;
  final List<T> footerTrailingCells;

  final List<List<T>> rowsCells;
  final Widget Function(T data) cellBuilder;

  final double fixedColWidth;
  final double cellWidth;
  final double fixedRightColWidth;
  final double cellHeight;
  final double headerHeight;

  /// A column to open on: scrolled to two columns from the leading edge,
  /// as far as the content allows, so the days before it stay in sight.
  final int? initialColumn;

  const CustomDataTable({
    super.key,
    required this.fixedColCells,
    required this.fixedRightColCells,
    required this.fixedRowCells,
    required this.fixedBottomRowsCells,
    required this.headerLeadingCell,
    required this.headerTrailingCell,
    required this.footerLeadingCells,
    required this.footerTrailingCells,
    required this.rowsCells,
    required this.cellBuilder,
    this.fixedColWidth = 130,
    this.cellWidth = 50,
    this.fixedRightColWidth = 60,
    this.cellHeight = 32,
    this.headerHeight = 38,
    this.initialColumn,
  });

  @override
  State<CustomDataTable<T>> createState() => CustomDataTableState<T>();
}

class CustomDataTableState<T> extends State<CustomDataTable<T>> {
  final _columnController = ScrollController();
  final _rightColumnController = ScrollController();
  final _rowController = ScrollController();
  final _bottomRowController = ScrollController();
  final _subTableYController = ScrollController();

  /// The cells' horizontal scroll; exposed so tests can read the offset.
  final subTableXController = ScrollController();

  Widget _cell(double width, double height, T data) =>
      SizedBox(width: width, height: height, child: widget.cellBuilder(data));

  Widget _column(List<T> cells, double width) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cell in cells) _cell(width, widget.cellHeight, cell)
        ],
      );

  Widget _row(List<T> cells, double height) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cell in cells) _cell(widget.cellWidth, height, cell)
        ],
      );

  /// A strip that follows the cells: scrolled by [controller], never by hand.
  Widget _follower(ScrollController controller, Axis axis, Widget child) =>
      SingleChildScrollView(
        controller: controller,
        scrollDirection: axis,
        physics: const NeverScrollableScrollPhysics(),
        child: child,
      );

  void _follow(ScrollController controller, double pixels) {
    if (controller.hasClients) controller.jumpTo(pixels);
  }

  @override
  void initState() {
    super.initState();
    subTableXController.addListener(() {
      final x = subTableXController.position.pixels;
      _follow(_rowController, x);
      _follow(_bottomRowController, x);
    });
    _subTableYController.addListener(() {
      final y = _subTableYController.position.pixels;
      _follow(_columnController, y);
      _follow(_rightColumnController, y);
    });
    // After the first layout, when the viewport and so the extent are known.
    if (widget.initialColumn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());
    }
  }

  void _scrollToInitial() {
    if (!mounted || !subTableXController.hasClients) return;
    final position = subTableXController.position;
    final x = ((widget.initialColumn! - 2) * widget.cellWidth)
        .clamp(0.0, position.maxScrollExtent);
    subTableXController.jumpTo(x);
  }

  @override
  void dispose() {
    _columnController.dispose();
    _rightColumnController.dispose();
    _rowController.dispose();
    _bottomRowController.dispose();
    _subTableYController.dispose();
    subTableXController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _cell(w.fixedColWidth, w.headerHeight, w.headerLeadingCell),
            Expanded(
              child: _follower(_rowController, Axis.horizontal,
                  _row(w.fixedRowCells, w.headerHeight)),
            ),
            _cell(w.fixedRightColWidth, w.headerHeight, w.headerTrailingCell),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _follower(_columnController, Axis.vertical,
                  _column(w.fixedColCells, w.fixedColWidth)),
              Expanded(
                child: SingleChildScrollView(
                  controller: subTableXController,
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _subTableYController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in w.rowsCells) _row(row, w.cellHeight)
                      ],
                    ),
                  ),
                ),
              ),
              _follower(_rightColumnController, Axis.vertical,
                  _column(w.fixedRightColCells, w.fixedRightColWidth)),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            _column(w.footerLeadingCells, w.fixedColWidth),
            Expanded(
              child: _follower(
                _bottomRowController,
                Axis.horizontal,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in w.fixedBottomRowsCells)
                      _row(row, w.cellHeight)
                  ],
                ),
              ),
            ),
            _column(w.footerTrailingCells, w.fixedRightColWidth),
          ],
        ),
      ],
    );
  }
}
