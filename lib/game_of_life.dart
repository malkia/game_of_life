import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/painting.dart';

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

var _counter = 0x7f;
var _pixels = Uint8List(1);

int outVarSize(int v) {
  assert(v >= 0);
  return (v.bitLength + 6) ~/ 7;
}

int outVar(int v, Uint8List out, int outIndex) {
  var parts = outVarSize(v);
  for (var p = parts - 1; p > 0; p--)
    out[outIndex++] = 0x80 | ((v >> (7 * p)) & 0x7F);
  out[outIndex] = v & 0x7F;
  return parts;
}

// TODO: Need to make this working for any width/height
// TODO: Might be just worth directly modifying the bitmap too!
Future<ui.Image> _createImage2(int width, int height, Uint8List cells) async {
  final completer = Completer<ui.Image>();
  // https://en.wikipedia.org/wiki/Wireless_Application_Protocol_Bitmap_Format
  var wbmapWidth = width;
  var wbmapHeight = height;
  var wbmapWidthSize = outVarSize(wbmapWidth);
  var wbmapHeightSize = outVarSize(wbmapHeight);
  var wbmapWidthAligned = ((wbmapWidth + 7) ~/ 8) * 8;
  var wbmapBits = wbmapWidthAligned * wbmapHeight;
  assert(wbmapBits % 8 == 0);
  var wbmap = Uint8List(2 + wbmapWidthSize + wbmapHeightSize + wbmapBits ~/ 8);
  var offset = 0;
  wbmap[offset++] = 0;
  wbmap[offset++] = 0;
  offset += outVar(wbmapWidth, wbmap, offset);
  offset += outVar(wbmapHeight, wbmap, offset);
  // TODO: Make it work on non-8 aligned
  for (var index = 0; index < cells.length; index += 8)
    wbmap[offset + (index >> 3)] = ((cells[index + 0] << 7) |
        (cells[index + 1] << 6) |
        (cells[index + 2] << 5) |
        (cells[index + 3] << 4) |
        (cells[index + 4] << 3) |
        (cells[index + 5] << 2) |
        (cells[index + 6] << 1) |
        (cells[index + 7] << 0));
  ui.decodeImageFromList(wbmap, (ui.Image image) => completer.complete(image));
  return await completer.future;
}

Future<ui.Image> _createImage(int width, int height, Uint8List cells) async {
  final completer = Completer<ui.Image>();
  assert(width * height == cells.length);
  if (_pixels.length != cells.length * 4) _pixels = Uint8List(cells.length * 4);
  for (var index = 0; index < cells.length; index++) {
    var alive = (cells[index] != 0);
    _pixels[index * 4 + 0] = alive ? 0xFF : 0; //counter;
    _pixels[index * 4 + 1] = alive ? 0 : 0xFF;
    _pixels[index * 4 + 2] = _counter; //alive ? 0 : 0xFF;
    _pixels[index * 4 + 3] = 0xFF; //alive ? 0 : 0xFF;
  }
  ui.decodeImageFromPixels(
    _pixels,
    width,
    height,
    ui.PixelFormat.bgra8888,
    (ui.Image image) {
      completer.complete(image);
    },
  );
  _counter++;
  print("decodeImageFromPixels FUTURE CREATED!");
  return await completer.future;
}

// Future<ui.FrameInfo> makeImageFrame() async {
//   var imageWidth = 64;
//   var imageHeight = 64;
//   var pixels = Uint8List(imageWidth * imageHeight * 4);
//   for (var y = 0; y < imageHeight; y++)
//     for (var x = 0; x < imageWidth; x++) {
//       var offset = (y * imageWidth + x) * 4;
//       pixels[offset + 0] = 0xFF;
//       pixels[offset + 0] = (x * y) % 256;
//       pixels[offset + 0] = (x + y) % 256;
//       pixels[offset + 0] = 0xFF;
//     }
//   var imageBuff = await ui.ImmutableBuffer.fromUint8List(pixels);
//   var imageDesc = ui.ImageDescriptor.raw(imageBuff,
//       width: imageWidth,
//       height: imageHeight,
//       rowBytes: imageWidth * 4,
//       pixelFormat: ui.PixelFormat.rgba8888);
//   var codec = await imageDesc.instantiateCodec(
//       targetWidth: imageWidth, targetHeight: imageHeight);
//   return codec.getNextFrame();
// }

class GameOfLifePainter extends CustomPainter {
  final _GameOfLifeWidgetState state;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint();
    // var cellWidth = size.width / state.cellsByX;
    // var cellHeight = size.height / state.cellsByY;
    // for (var y = 0; y < state.cellsByY; y++) {
    //   for (var x = 0; x < state.cellsByX; x++) {
    //     var ry = y * cellHeight;
    //     var rx = x * cellWidth;
    //     var r = Rect.fromLTWH(rx, ry, cellWidth, cellHeight);
    //     p.color = state.cells[y * state.cellsByX + x] == 0
    //         ? Colors.green
    //         : Colors.red;
    //     canvas.drawRect(r, p);
    //   }
    // }
    // canvas.drawImage(image!, Offset(5, 5), p);
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
  late Uint8List _cellsA;
  late Uint8List _cellsB;
  late Uint8List _cells;

  get cells => _cells;
  get cellsByX => widget.width;
  get cellsByY => widget.height;

  Future<ui.Image>? futureImage;
  late Ticker _ticker;

  void _init() {
    _cellsA.fillRange(0, _cellsA.length - 1, 0);
    _cellsB.fillRange(0, _cellsB.length - 1, 0);
    _cells = _cellsA;
    var random = Random();
    for (var y = 1; y < widget.height - 1; y++)
      for (var x = 1; x < widget.width - 1; x++)
        _cellsA[y * widget.width + x] = random.nextInt(5) == 0 ? 1 : 0;
  }

  void _waitForFutureImage() async {
    if (futureImage != null) await futureImage;
  }

  void update() {
    _waitForFutureImage();
    updateGameOfLife(
        widget.width,
        widget.height,
        _cells == _cellsA ? _cellsA : _cellsB,
        _cells == _cellsA ? _cellsB : _cellsA);
    _cells = (_cells == _cellsA) ? _cellsB : _cellsA;
    futureImage = _createImage2(widget.width, widget.height, _cells);
  }

  @override
  void initState() {
    super.initState();
    var size = widget.width * widget.height;
    _cellsA = Uint8List(size);
    _cellsB = Uint8List(size);
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
                    child: FutureBuilder<ui.Image>(
                        future: futureImage,
                        builder: (context, snapshot) {
                          return snapshot.hasData && snapshot.data != null
                              ? CustomPaint(
                                  painter: GameOfLifePainter(
                                      state: this, image: snapshot.data!))
                              : CircularProgressIndicator();
                        })),
              ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FlatButton(
                    child: Text('Play'),
                    onPressed: _ticker.isActive ? null : () => _ticker.start(),
                  ),
                  FlatButton(
                      child: Text('Stop'),
                      onPressed: _ticker.isActive
                          ? () => setState(() => _ticker.stop())
                          : null),
                  FlatButton(
                      child: Text('Step'),
                      onPressed: _ticker.isActive
                          ? null
                          : () => setState(() => update())),
                  FlatButton(
                    child: Text('Random'),
                    onPressed: () => setState(() => _init()),
                  ),
                ])
          ]));
}
