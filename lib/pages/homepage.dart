import 'dart:async';
import 'dart:io';

import 'package:enefty_icons/enefty_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:ripple_wave/ripple_wave.dart';
import 'package:voice_recorder/pages/audioWidget.dart';

class Recording extends StatefulWidget {
  const Recording({super.key});

  @override
  State<Recording> createState() => _RecordingState();
}

class _RecordingState extends State<Recording> with TickerProviderStateMixin {
  final record = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();
  final PageController pageController = PageController();
  Duration? duration = Duration.zero;
  Duration? position = Duration.zero;
  bool isRecording = false;
  bool _isPaused = false;
  String? recordPath;
  late AnimationController controller;
  Timer? timer;
  Duration elapsed = Duration.zero;
  int curPage = 0;

  @override
  void initState() {
    super.initState();
    // Listening to player state changes
    audioPlayer.durationStream.listen((duration) {
      setState(() {
        this.duration = duration;
      });
    });
    audioPlayer.positionStream.listen((position) {
      setState(() {
        this.position = position;
      });
    });
    controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: curPage,
          onTap: (value) {
            pageController.jumpToPage(value);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(EneftyIcons.microphone_2_outline),
              label: 'Record',
            ),
            BottomNavigationBarItem(
              icon: Icon(EneftyIcons.music_playlist_bold),
              label: 'Playlist',
            ),
          ],
        ),
        appBar: AppBar(
          title: Text(
            "Voice Recorder",
            style: GoogleFonts.montserrat(
                fontSize: 25, fontWeight: FontWeight.w400),
          ),
          centerTitle: true,
        ),
        body: PageView(
          onPageChanged: (value) {
            setState(() {
              curPage = value;
            });
          },
          scrollDirection: Axis.horizontal,
          controller: pageController,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(150),
                  ),
                  child: RippleWave(
                    waveCount: 5,
                    color: isRecording ? Colors.teal : Colors.white,
                    childTween: Tween(begin: 1, end: 1),
                    repeat: false,
                    animationController: controller,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(200),
                        color: HexColor("#fb4559"),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Image.asset(
                          "assets/microphone.png",
                          width: 100, // Adjust the width of the image
                          height: 100, // Adjust the height of the image
                          fit: BoxFit.contain,
                          color: Colors
                              .white, // Adjust how the image fits the container
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  formatTime(elapsed),
                  style: GoogleFonts.montserrat(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                Container(
                  child: Lottie.asset("assets/animation.json",
                      controller: controller),
                ),
                CircleAvatar(
                  child: IconButton(
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    onPressed: () async {
                      if (_isPaused) {
                        await record.resume();
                        startTimer();
                        setState(() {
                          _isPaused = false;
                        });
                      } else {
                        await record.pause();
                        timer?.cancel();
                        setState(() {
                          _isPaused = true;
                        });
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (isRecording) {
                      await record.stop();
                      timer?.cancel();
                      setState(() {
                        isRecording = false;
                        recordPath = recordPath;
                      });

                      controller.stop();
                    } else {
                      if (await _requestPermission(Permission.microphone)) {
                        final Directory dir =
                            await getApplicationDocumentsDirectory();
                        final DateTime now = DateTime.now();
                        final DateFormat formatter =
                            DateFormat('yyyyMMddHHmmss');
                        final String formattedDate = formatter.format(now);
                        final String uniqueName = 'record_$formattedDate';
                        final String path = p.join(dir.path, uniqueName);
                        await record.start(
                          const RecordConfig(),
                          path: p.join(dir.path, path),
                        );
                        setState(() {
                          isRecording = true;
                          elapsed = Duration.zero;
                        });
                        controller.repeat();
                        startTimer(); // Start the timer when recording starts
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Permission denied")),
                        );
                      }
                    }
                  },
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(HexColor('#fb4559')),
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16))),
                  child: Text(
                    isRecording ? "Stop Recording" : "Start Recording",
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const RecordingList()
          ],
        ));
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      setState(() {
        elapsed += const Duration(milliseconds: 100);
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    record.dispose();
    timer?.cancel(); // Cancel the timer when disposing
    super.dispose();
  }

  Future<bool> _requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      final result = await permission.request();
      return result == PermissionStatus.granted;
    }
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
