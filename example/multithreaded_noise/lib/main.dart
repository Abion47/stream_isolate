import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';

import 'noise_simulation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  static const minThreads = 1;
  static const maxThreads = 16;
  static const minScale = 0.1;
  static const maxScale = 20.0;
  static const minVelocity = 0.0;
  static const maxVelocity = 100.0;
  static const simulationWidth = 200;
  static const simulationHeight = 200;

  int _threadCount = 1;
  double _scale = 4;
  double _velocity = 10;

  late NoiseSimulation simulation;
  ui.Image? image;

  @override
  void initState() {
    super.initState();

    simulation = NoiseSimulation(
      width: simulationWidth,
      height: simulationHeight,
      threads: _threadCount,
      scale: _scale,
      velocity: _velocity,
      onData: receivedSimulationData,
    );
  }

  void setThreadCount(double value) {
    setState(() {
      _threadCount = max(min(value.toInt(), maxThreads), minThreads);
    });
  }

  void setScale(double value) {
    setState(() {
      _scale = max(min(value, maxScale), minScale);
      simulation.scale = _scale;
    });
  }

  void setVelocity(double value) {
    setState(() {
      _velocity = max(min(value, maxVelocity), minVelocity);
      simulation.velocity = _velocity;
    });
  }

  void stopSimulation() async {
    await simulation.stop();
  }

  void restartSimulation() async {
    await simulation.stop();

    simulation.threads = _threadCount;
    simulation.start();
  }

  void receivedSimulationData(Uint8List bytes) async {
    decodeImageFromPixels(
        bytes, simulationWidth, simulationHeight, PixelFormat.rgba8888,
        (ui.Image result) {
      setState(() {
        image = result;
      });

      simulation.requestNextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Threads: $_threadCount (Restart to see changes)',
            ),
            Slider(
              value: _threadCount.toDouble(),
              min: minThreads.toDouble(),
              max: maxThreads.toDouble(),
              divisions: maxThreads,
              onChanged: setThreadCount,
            ),
            Text(
              'Scale: $_scale',
            ),
            Slider(
              value: _scale,
              min: minScale,
              max: maxScale,
              onChanged: setScale,
            ),
            Text(
              'Velocity: $_velocity',
            ),
            Slider(
              value: _velocity,
              min: minVelocity,
              max: maxVelocity,
              onChanged: setVelocity,
            ),
            Text(
              'Average frame time: ${simulation.averageFrameTime.toStringAsFixed(1)}ms',
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: image == null
                    ? AspectRatio(
                        aspectRatio: 1,
                        child: Container(color: Colors.red),
                      )
                    : LayoutBuilder(builder: (context, constraints) {
                        return RawImage(
                          image: image,
                          width: constraints.biggest.width,
                          height: constraints.biggest.height,
                          alignment: Alignment.topCenter,
                          fit: BoxFit.contain,
                        );
                      }),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(
          onPressed: stopSimulation,
          tooltip: 'Stop',
          child: const Icon(Icons.stop),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          onPressed: restartSimulation,
          tooltip: '(Re)Start',
          child: const Icon(Icons.refresh),
        ),
      ]),
    );
  }
}
