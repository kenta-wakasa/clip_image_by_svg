import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:svg_path_parser/svg_path_parser.dart';
import 'package:xml/xml.dart';

Future<Path> svgToPath(String assetPath) async {
  final rawSVG = await rootBundle.loadString(assetPath);

  final xmlDocument = XmlDocument.parse(rawSVG);

  final path = xmlDocument.findAllElements('path').first;

  final d = path.attributes.firstWhere((p0) => p0.name.local == 'd');

  return parseSvgPath(d.value);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(title: 'Clip image by svg data'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var scale = 0.5;

  var initScale = 1.0;

  var offset = const Offset(0, 0);

  final key = GlobalKey();

  Uint8List? pngBytes;

  Future<void> capturePng() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    pngBytes = byteData!.buffer.asUint8List();
    setState(() {});
  }

  Path? path;

  @override
  void initState() {
    super.initState();

    svgToPath('assets/iphone-12-glitter.svg').then((value) async {
      setState(() {
        path = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: path == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onScaleStart: (details) {
                      initScale = scale;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        scale = initScale * details.scale;
                      });
                      setState(() {
                        offset = offset + details.focalPointDelta;
                      });
                    },
                    child: SizedBox(
                      height: 240,
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          Container(
                            color: Colors.blue[100],
                          ),
                          GestureDetector(
                            child: RepaintBoundary(
                              key: key,
                              child: ClipPath(
                                clipper: IPhoneClipper(
                                  scale: scale,
                                  offset: offset,
                                  path: path!,
                                ),
                                child: SizedBox(
                                  child: Image.asset('assets/image.png'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pngBytes != null)
                    Column(
                      children: [
                        const Text('書き出した画像'),
                        const SizedBox(height: 8),
                        Image.memory(pngBytes!),
                      ],
                    )
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          capturePng();
        },
      ),
    );
  }
}

class IPhoneClipper extends CustomClipper<Path> {
  IPhoneClipper({
    required this.scale,
    required this.offset,
    required this.path,
  });
  final double scale;
  final Offset offset;
  final Path path;

  @override
  Path getClip(Size size) {
    final matrix4 = Matrix4.identity();
    matrix4.scale(scale);
    return path.transform(matrix4.storage).shift(offset);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
