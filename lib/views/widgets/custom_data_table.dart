import 'package:flutter/material.dart';

class CustomDataTable<T> extends StatefulWidget {
  final List<T> fixedColCells;
  final List<T> fixedRightColCells;
  final List<T> fixedRowCells;
  final List<T> fixedBottomRowCells;
  final List<List<T>> rowsCells;
  final Widget Function(T? data) cellBuilder;

  const CustomDataTable({
    super.key,
    required this.fixedColCells,
    required this.fixedRightColCells,
    required this.fixedRowCells,
    required this.fixedBottomRowCells,
    required this.rowsCells,
    required this.cellBuilder,
  });

  @override
  State<CustomDataTable<T>> createState() => CustomDataTableState<T>();
}

class CustomDataTableState<T> extends State<CustomDataTable<T>> {
  final _columnController = ScrollController();
  final _rowController = ScrollController();
  final _bottomRowController = ScrollController();
  final _subTableYController = ScrollController();
  final _subTableXController = ScrollController();

  static const double _hiddenCellWidth = 0;
  static const double _cellHeight = 30.0;
  static const double _fixedRowHeight = 60.0;
  static const double _cellMargin = 0.0;

  double _cellWidth = 40.0;
  double _fixedColWidth = 150.0;
  bool _showSums = true;

  Widget _buildChild(double width, T? data) => SizedBox(
      width: width,
      height: _cellHeight,
      child: widget.cellBuilder.call(data)
  );

  Widget _buildFixedCol() => Material(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.fixedColCells.map((cell) {
        return Container(
          width: _fixedColWidth + (_cellMargin * 2),
          height: _cellHeight,
          padding: const EdgeInsets.symmetric(horizontal: _cellMargin),
          child: _buildChild(_fixedColWidth, cell),
        );
      }).toList(),
    ),
  );

  Widget _buildFixedRightCol() => Material(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.fixedRightColCells.map((cell) {
        final cellWidth = _showSums ? _cellWidth : _hiddenCellWidth;
        return Container(
          width: cellWidth + (_cellMargin * 2),
          height: _cellHeight,
          padding: const EdgeInsets.symmetric(horizontal: _cellMargin),
          child: _buildChild(cellWidth, cell),
        );
      }).toList(),
    ),
  );

  Widget _buildFixedRow() => Material(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.fixedRowCells.map((cell) {
        return Container(
          width: _cellWidth + (_cellMargin * 2),
          height: _fixedRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: _cellMargin),
          child: _buildChild(_cellWidth, cell),
        );
      }).toList(),
    ),
  );

  Widget _buildFixedBottomRow() => Material(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.fixedBottomRowCells.map((cell) {
        return Container(
          width: _cellWidth + (_cellMargin * 2),
          height: _showSums ? _cellHeight : 0.0,
          padding: const EdgeInsets.symmetric(horizontal: _cellMargin),
          child: _buildChild(_cellWidth, cell),
        );
      }).toList(),
    ),
  );

  Widget _buildSubTable() => Material(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.rowsCells.map((row) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: row.map((cell) {
            return Container(
              width: _cellWidth + (_cellMargin * 2),
              height: _cellHeight,
              padding: const EdgeInsets.symmetric(horizontal: _cellMargin),
              child: _buildChild(_cellWidth, cell),
            );
          }).toList(),
        );
      }).toList(),
    ),
  );

  Widget _buildCornerSumCell({
    bool wide = false,
    bool high = false,
    bool showButton = false,
    required BuildContext context,
    Widget? child,
  }) {
    final innerWidth = wide
        ? _fixedColWidth
        : (_showSums ? _cellWidth : _hiddenCellWidth);
    return Material(
      child: Container(
        width: innerWidth + _cellMargin * 2,
        height: _showSums || showButton
            ? (high ? _fixedRowHeight : _cellHeight)
            : 0.0,
        padding: const EdgeInsets.symmetric(horizontal: _cellMargin),
        child: SizedBox(
          width: innerWidth,
          height: _cellHeight,
          child: Center(
            child: showButton
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        "Σ",
                        style: TextStyle(
                          fontSize: 28,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        thumbIcon: WidgetStateProperty<Icon>.fromMap(
                          <WidgetStatesConstraint, Icon>{
                            WidgetState.selected: const Icon(Icons.visibility),
                            WidgetState.any: const Icon(Icons.close),
                          },
                        ),
                        onChanged: (value) {
                          setState(() {
                            _showSums = value;
                          });
                        },
                        value: _showSums,
                      )
                    ],
                  )
                : child,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _subTableXController.addListener(() {
      _rowController.jumpTo(_subTableXController.position.pixels);
      _bottomRowController.jumpTo(_subTableXController.position.pixels);
    });
    _subTableYController.addListener(() {
      _columnController.jumpTo(_subTableYController.position.pixels);
    });
  }

  @override
  void dispose() {
    _columnController.dispose();
    _rowController.dispose();
    _bottomRowController.dispose();
    _subTableYController.dispose();
    _subTableXController.dispose();
    super.dispose();
  }

  void _setColumnsWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _fixedColWidth = screenWidth / 3.0;
    _cellWidth = (screenWidth - _fixedColWidth) / 8.0;
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      _fixedColWidth /= 2.0;
      _cellWidth /= 2.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    _setColumnsWidth(context);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _buildCornerSumCell(context: context, wide: true, showButton: true, high: true),
            Flexible(
              child: SingleChildScrollView(
                controller: _rowController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildFixedRow(),
              ),
            ),
            _buildCornerSumCell(
              context: context,
              child: const Text(
                "Σ",
                style: TextStyle(
                  fontSize: 26,
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              SingleChildScrollView(
                controller: _columnController,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildFixedCol(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  controller: _subTableXController,
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _subTableYController,
                    scrollDirection: Axis.vertical,
                    child: _buildSubTable(),
                  ),
                ),
              ),
              SingleChildScrollView(
                controller: _columnController,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildFixedRightCol(),
              )
            ],
          ),
        ),
        Row(
          children: <Widget>[
            _buildCornerSumCell(
              context: context,
              wide: true,
              child: const Text("Σ"),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: _bottomRowController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildFixedBottomRow(),
              ),
            ),
            _buildCornerSumCell(context: context),
          ],
        ),
      ],
    );
  }
}
