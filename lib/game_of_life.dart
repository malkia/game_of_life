import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/painting.dart';

var random = Random();

/*
   0 1 2 3 4 5 6 7 . 1 2 3 4 5 6 7
0  x x x
1   x x x
2     x x x
3       x x x
4         x x x
5           x x x

    var topBits = inputCells[byte-width/8];
    var midBits = inputCells[byte];
    var botBits = inputCells[byte+width/8];
    var mask = 0x80 | 0x40 | 0x20;

*/

void updateGameOfLifeBits(
    int width, int height, Uint8List inputCells, Uint8List outputCells) {
  assert(width & 7 == 0);
  final size = width * height;
  assert(size == (inputCells.length << 3));
  assert(size == (outputCells.length << 3));
  outputCells.fillRange(0, (size >> 3) - 1, 0);
  for (var y = width; y < (width - 1) * height; y += width) {
    var bits = 0;
    for (var x = 1; x < width - 1; x++) {
      var aliveCells = 0;
      final index = x + y;
      for (var ny = -width; ny <= width; ny += width) {
        for (var nx = -1; nx <= 1; nx++) {
          final nIndex = index + nx + ny;
          if ((inputCells[nIndex >> 3] & (1 << (7 - (nIndex & 7)))) == 0)
            continue;
          if (++aliveCells > 4) {
            ny = width;
            break;
          }
        }
      }
      if (aliveCells != 3 && aliveCells != 4) continue;
      final bitMask = 1 << (7 - (index & 7));
      final byteIndex = index >> 3;

      // From https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life#Algorithms
      //
      // To avoid decisions and branches in the counting loop, the rules can be
      // rearranged from an egocentric approach of the inner field regarding its
      // neighbours to a scientific observer's viewpoint:
      //
      // 1. if the sum of all nine fields in a given neighbourhood is 3, the
      // inner field state for the next generation will be life
      // 2. if the all-field sum is 4, the inner field retains its current state
      // 3. every other sum sets the inner field to death.
      //
      if (aliveCells == 3 ||
          (aliveCells == 4 && (inputCells[byteIndex] & bitMask) != 0))
        outputCells[byteIndex] |= bitMask;
    }
  }
}

// Bitmap image in the wbmp format (wapforum) redable by skia.
class BitmapImage {
  final int width;
  final int height;
  final int widthAligned;
  late Uint8List _image;
  late Uint8List _bitmap;
  get bitmap => _bitmap;
  get image => _image;

  static int _outVarSize(int v) {
    assert(v >= 0);
    return (v.bitLength + 6) ~/ 7;
  }

  static int _outVar(int v, Uint8List out, int outIndex) {
    var parts = _outVarSize(v);
    for (var p = parts - 1; p > 0; p--)
      out[outIndex++] = 0x80 | ((v >> (7 * p)) & 0x7F);
    out[outIndex] = v & 0x7F;
    return parts;
  }

  BitmapImage({required this.width, required this.height})
      : widthAligned = ((width + 7) ~/ 8) * 8 {
    // TODO: Eventually let this one go,
    // but currently only aligned to 8 width allowed
    assert(width & 7 == 0);
    assert(width > 0 && width < 65536);
    assert(height > 0 && height < 65536);
    var rawImage = Uint8List(2 +
        _outVarSize(width) +
        _outVarSize(height) +
        ((width + 7) ~/ 8) * height);
    var bitmapOffset = 0;
    rawImage[bitmapOffset++] = 0;
    rawImage[bitmapOffset++] = 0;
    bitmapOffset += _outVar(width, rawImage, bitmapOffset);
    bitmapOffset += _outVar(height, rawImage, bitmapOffset);
    _bitmap = Uint8List.sublistView(rawImage, bitmapOffset);
    _image = rawImage;
  }
}

Future<ui.Image> _createImage(BitmapImage image) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(
      image.image, (ui.Image image) => completer.complete(image));
  return await completer.future;
}

class GameOfLifePainter extends CustomPainter {
  final _GameOfLifeWidgetState state;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint());
  }

  @override
  bool shouldRepaint(GameOfLifePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.image != image;

  GameOfLifePainter({required this.state, required this.image});
}

class GameOfLifeWidget extends StatefulWidget {
  final int width;
  final int height;
  @override
  _GameOfLifeWidgetState createState() => _GameOfLifeWidgetState();
  GameOfLifeWidget({required this.width, required this.height});
}

class _GameOfLifeWidgetState extends State<GameOfLifeWidget>
    with SingleTickerProviderStateMixin {
  late BitmapImage _imageA;
  late BitmapImage _imageB;
  late BitmapImage _image;

  get cells => _image.bitmap;
  get cellsByX => widget.width;
  get cellsByY => widget.height;

  Future<ui.Image>? futureImage;
  late Ticker _ticker;

  void _init() {
    _image = _imageA;
    for (var y = 1; y < widget.height - 1; y++)
      for (var x = 1; x < widget.width - 1; x++) {
        var v = random.nextInt(5) == 0 ? 1 : 0;
        var bitMask = 1 << (7 - (x & 7));
        var byteIndex = (y * widget.width + x) >> 3;
        if (x == 0 || y == 0 || x == widget.width - 1 || y == widget.height - 1)
          v = 0;
        if (v == 1)
          _image.bitmap[byteIndex] |= bitMask;
        else
          _image.bitmap[byteIndex] &= ~bitMask;
      }
  }

  void _waitForFutureImage() async {
    if (futureImage != null) await futureImage;
  }

  void updateImage() {
    futureImage = _createImage(_image);
  }

  void update() {
    _waitForFutureImage();
    updateGameOfLifeBits(
        widget.width,
        widget.height,
        _image == _imageA ? _imageA.bitmap : _imageB.bitmap,
        _image == _imageA ? _imageB.bitmap : _imageA.bitmap);
    _image = (_image == _imageA) ? _imageB : _imageA;
    updateImage();
  }

  @override
  void initState() {
    super.initState();
    _imageA = BitmapImage(width: widget.width, height: widget.height);
    _imageB = BitmapImage(width: widget.width, height: widget.height);
    _init();
    update();
    _ticker = Ticker((Duration duration) => setState(() => update()));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            if (futureImage != null)
              Flexible(
                child: Container(
                    width: min(constraints.maxHeight, constraints.maxWidth),
                    height: min(constraints.maxHeight, constraints.maxWidth),
                    child: GestureDetector(
                      onPanUpdate: (DragUpdateDetails d) {
                        var size =
                            min(constraints.maxHeight, constraints.maxWidth);
                        var x =
                            (d.localPosition.dx * widget.width / size).round();
                        var y =
                            (d.localPosition.dy * widget.height / size).round();
                        var delta = 3;
                        if (x >= 0 &&
                            x < widget.width &&
                            y >= 0 &&
                            y < widget.height) {
                          setState(() {
                            for (var dy = -delta; dy <= delta; dy++)
                              for (var dx = -delta; dx <= delta; dx++) {
                                var rx = x + dx;
                                var ry = y + dy;
                                if (x >= 0 &&
                                    x < widget.width &&
                                    y >= 0 &&
                                    y < widget.height) {
                                  var byteIndex = (ry * widget.width + rx) >> 3;
                                  var bitMask = 1 << (7 - (rx & 7));
                                  var v = random.nextInt(5) == 0 ? 1 : 0;
                                  if (v != 0)
                                    _image.bitmap[byteIndex] ^= bitMask;
                                }
                              }
                            updateImage();
                          });
                        }
                      },
                      child: FutureBuilder<ui.Image>(
                          future: futureImage,
                          builder: (context, snapshot) {
                            return snapshot.hasData && snapshot.data != null
                                ? CustomPaint(
                                    painter: GameOfLifePainter(
                                        state: this, image: snapshot.data!))
                                : CircularProgressIndicator();
                          }),
                    )),
              ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: Text('Play'),
                    onPressed: _ticker.isActive ? null : () => _ticker.start(),
                  ),
                  TextButton(
                      child: Text('Stop'),
                      onPressed: _ticker.isActive
                          ? () => setState(() => _ticker.stop())
                          : null),
                  TextButton(
                      child: Text('Step'),
                      onPressed: _ticker.isActive
                          ? null
                          : () => setState(() => update())),
                  TextButton(
                    child: Text('Random'),
                    onPressed: () => setState(() {
                      _init();
                      update();
                    }),
                  ),
                ])
          ]));
}
