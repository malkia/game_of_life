import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/ticker.dart';
import 'package:flutter/widgets.dart';

void updateGameOfLife(
    int width, int height, Uint8List inputCells, Uint8List outputCells) {
  assert(width * height == inputCells.length);
  assert(width * height == outputCells.length);
  for (var y = width; y < (width - 1) * height; y += width) {
    for (var x = 1; x < width - 1; x++) {
      var neighbors = 0;
      var index = x + y;
      for (var ny = -width; ny <= width; ny += width) {
        for (var nx = -1; nx <= 1; nx++) {
          if (ny == 0 && nx == 0) continue;
          neighbors += inputCells[index + nx + ny];
        }
      }
      if (inputCells[index] == 0) {
        outputCells[index] = (neighbors == 3) ? 1 : 0;
      } else {
        outputCells[index] = (neighbors == 2 || neighbors == 3) ? 1 : 0;
      }
    }
  }
}

class GameOfLifePainter extends CustomPainter {
  final _GameOfLifeWidgetState state;

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint();
    p.color = Colors.red;
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), p);
    var cellWidth = size.width / state.cellsByX;
    var cellHeight = size.height / state.cellsByY;
    for (var y = 0; y < state.cellsByY; y++) {
      for (var x = 0; x < state.cellsByX; x++) {
        var ry = y * cellHeight;
        var rx = x * cellWidth;
        var r = Rect.fromLTWH(rx, ry, cellWidth, cellHeight);
        p.color = state.cells[y * state.cellsByX + x] == 0
            ? Colors.green
            : Colors.red;
        canvas.drawRect(r, p);
      }
    }
  }

  @override
  bool shouldRepaint(GameOfLifePainter oldDelegate) =>
      oldDelegate.state != state;

  GameOfLifePainter({this.state});
}

class GameOfLifeWidget extends StatefulWidget {
  final int width;
  final int height;
  @override
  _GameOfLifeWidgetState createState() => _GameOfLifeWidgetState();
  GameOfLifeWidget({@required this.width, @required this.height});
}

class _GameOfLifeWidgetState extends State<GameOfLifeWidget>
    with SingleTickerProviderStateMixin {
  Ticker _ticker;
  Uint8List _cellsA;
  Uint8List _cellsB;
  Uint8List _cells;

  get cells => _cells;
  get cellsByX => widget.width;
  get cellsByY => widget.height;

  void init() {
    _cellsA.fillRange(0, _cellsA.length - 1, 0);
    _cellsB.fillRange(0, _cellsB.length - 1, 0);
    _cells = _cellsA;
    var random = Random();
    for (var y = 1; y < widget.height - 1; y++)
      for (var x = 1; x < widget.width - 1; x++)
        _cellsA[y * widget.width + x] = random.nextInt(5) == 0 ? 1 : 0;
  }

  void update() {
    updateGameOfLife(
        widget.width,
        widget.height,
        _cells == _cellsA ? _cellsA : _cellsB,
        _cells == _cellsA ? _cellsB : _cellsA);
    _cells = (_cells == _cellsA) ? _cellsB : _cellsA;
  }

  void initState() {
    super.initState();
    _ticker = createTicker((Duration elapsed) => setState(() => update()));
    var size = widget.width * widget.height;
    _cellsA = Uint8List(size);
    _cellsB = Uint8List(size);
    _cells = _cellsA;
    init();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Flexible(
              child: Container(
                  width: min(constraints.maxHeight, constraints.maxWidth),
                  height: min(constraints.maxHeight, constraints.maxWidth),
                  child: CustomPaint(painter: GameOfLifePainter(state: this))),
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ticker != null)
                    FlatButton(
                      child: Text('Play'),
                      onPressed: _ticker.isActive
                          ? null
                          : () => setState(() => _ticker.start()),
                    ),
                  if (_ticker != null)
                    FlatButton(
                        child: Text('Stop'),
                        onPressed: _ticker.isActive
                            ? () => setState(() => _ticker.stop())
                            : null),
                  if (_ticker != null)
                    FlatButton(
                        child: Text('Step'),
                        onPressed: _ticker.isActive
                            ? null
                            : () => setState(() => update())),
                  FlatButton(
                    child: Text('Random'),
                    onPressed: () => setState(() => init()),
                  ),
                ])
          ]));
}
