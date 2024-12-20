import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'chat_widget.dart';

void main() {
  runApp(OhmniWelcomeYou());
}

class OhmniWelcomeYou extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ohmni',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _recognitionResult = 'No face recognized';
  bool _cameraAvailable = false;
  bool _isCameraStopped = false;
  String _errorMessage = '';
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  FlutterTts flutterTts = FlutterTts();
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    print("initState called");
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    print("_initializeCamera started");
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices != null) {
        final mediaStream = await mediaDevices.getUserMedia({
          'video': {'facingMode': 'user'}
        });
        _mediaStream = mediaStream;
        setState(() {
          _cameraAvailable = true;
          _isCameraStopped = false;
          _errorMessage = '';
        });
        _setupVideoElement(mediaStream);

        print("Video element setup complete");

        // Ensure video is playing
        await _videoElement!.play();

        // Wait for the video to be ready
        await _ensureVideoReady();

        print('Video is ready');
        print(
            'Video dimensions: ${_videoElement!.videoWidth} x ${_videoElement!.videoHeight}');

        // Start periodic capture and query
        _startPeriodicCapture();
      } else {
        setState(() {
          _cameraAvailable = false;
          _errorMessage = 'Camera not supported on this device';
        });
      }
    } catch (e) {
      print("Error in _initializeCamera: $e");
      setState(() {
        _cameraAvailable = false;
        _errorMessage = 'Camera access denied: $e';
      });
    }
  }

  Future<void> _ensureVideoReady() async {
    if (_videoElement!.videoWidth > 0 && _videoElement!.videoHeight > 0) {
      return;
    }

    await Future.any([
      _videoElement!.onLoadedMetadata.first,
      Future.delayed(Duration(seconds: 5)),
    ]);

    if (_videoElement!.videoWidth == 0 || _videoElement!.videoHeight == 0) {
      print("Video dimensions not available, using default size");
      _videoElement!.width = 640;
      _videoElement!.height = 480;
    }
  }

  void _setupVideoElement(html.MediaStream stream) {
    print("_setupVideoElement called");
    _videoElement = html.VideoElement()
      ..srcObject = stream
      ..autoplay = true
      ..style.objectFit = 'cover'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.transform = 'scaleX(-1)';

    ui.platformViewRegistry.registerViewFactory(
      'videoElement',
      (int viewId) => _videoElement!,
    );
  }

  void _startPeriodicCapture() {
    print("_startPeriodicCapture called");
    _captureTimer?.cancel();

    _captureTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      print("Timer fired");
      if (_cameraAvailable && !_isCameraStopped) {
        _captureAndQuery();
      } else {
        print("Camera not available or stopped");
      }
    });

    // Immediately trigger the first capture
    _captureAndQuery();
  }

  Future<void> _captureAndQuery() async {
    print("_captureAndQuery started");
    setState(() {
      _recognitionResult = 'Capturing image...';
    });

    if (!_cameraAvailable || _videoElement == null) {
      print("Camera not available or video element is null");
      setState(() => _recognitionResult = 'Camera not available');
      return;
    }

    try {
      final canvas = html.CanvasElement(
        width: _videoElement!.videoWidth,
        height: _videoElement!.videoHeight,
      );
      final ctx = canvas.context2D;

      ctx.drawImage(_videoElement!, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg');
      final base64Image = dataUrl.split(',')[1];

      print("Image captured, sending to backend");
      setState(() {
        _recognitionResult = 'Sending image to backend...';
      });

      final response = await http
          .post(
            Uri.parse('http://localhost:8000/detect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'image': base64Image}),
          )
          .timeout(Duration(seconds: 10));

      print("Backend response received: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        String resultText = response.body;
        setState(() {
          _recognitionResult = resultText;
        });
        _speak("Xin chào $resultText, tôi hân hạnh chào bạn");
      } else {
        setState(() =>
            _recognitionResult = 'Failed to process image: ${response.body}');
      }
    } catch (e) {
      print('Error in _captureAndQuery: $e');
      setState(() => _recognitionResult = 'Error processing image: $e');
    }
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("vi-VN");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  void _toggleCamera() {
    if (_isCameraStopped) {
      _initializeCamera();
    } else {
      _stopCamera();
    }
  }

  void _stopCamera() {
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _captureTimer?.cancel();
    setState(() {
      _cameraAvailable = false;
      _recognitionResult = 'Camera stopped';
      _isCameraStopped = true;
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenheight = MediaQuery.of(context).size.height;
    final screenwidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 20,
        backgroundColor: const ui.Color.fromARGB(255, 171, 226, 255),
        titleSpacing: screenheight * 0.02,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: screenwidth * 0.01),
              child: Image.asset(
                'assets/logo_clb.png',
                height: screenheight * 0.06,
                width: screenheight * 0.06,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: screenwidth * 0.25),
              child: const Text(
                'Ohmni welcomes you',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  shadows: [
                    Shadow(
                      offset: Offset(2.0, 2.0),
                      blurRadius: 3.0,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Padding(padding: EdgeInsets.only(left: screenwidth * 0.01)),
          Expanded(
            flex: 4,
            child: Container(
              margin: EdgeInsets.all(screenwidth * 0.01),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  Expanded(
                    flex: 9,
                    child: _cameraAvailable
                        ? const HtmlElementView(
                            viewType: 'videoElement',
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 4,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Camera not available',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FloatingActionButton(
                            onPressed: _toggleCamera,
                            child: Icon(
                              _isCameraStopped ? Icons.videocam : Icons.stop,
                            ),
                          ),
                          const SizedBox(width: 16),
                          FloatingActionButton(
                            onPressed: _captureAndQuery,
                            child: const Icon(Icons.camera),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ChatWidget(),
        ],
      ),
    );
  }
}
