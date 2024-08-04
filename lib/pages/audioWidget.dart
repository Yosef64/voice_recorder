// ignore_for_file: unnecessary_null_comparison

import 'dart:io';
import 'dart:ui';
import 'package:enefty_icons/enefty_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
// import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

class RecordingList extends StatefulWidget {
  const RecordingList({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RecordingListState createState() => _RecordingListState();
}

class _RecordingListState extends State<RecordingList>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController controller;
  List<FileSystemEntity> _recordings = [];
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  String? recordPath;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        this.duration = duration!;
      });
    });
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        this.position = position;
      });
    });
    controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          position = Duration.zero;
          duration = Duration.zero;
          isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final recordings = await directory.list().toList();
    setState(() {
      _recordings = recordings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
              decoration: BoxDecoration(
                color:
                    const Color.fromARGB(255, 189, 123, 123).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                      final recording = _recordings[index];
                      final pathName = p.basename(recording.path);
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 103, 151, 88)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),

                          height: 70,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          // specify a height for the Container
                          child: ListTile(
                            onTap: () async {
                              try {
                                if (isPlaying) {
                                  await _audioPlayer.stop();
                                  setState(() {
                                    isPlaying = false;
                                  });
                                } else {
                                  await _audioPlayer
                                      .setFilePath(recording.path);
                                  _audioPlayer.play();
                                  controller.repeat();
                                  setState(() {
                                    recordPath = pathName;
                                    isPlaying = true;
                                  });
                                }
                              } catch (e) {
                                print("The path is ${recording.path} : $e");
                              }
                            },
                            trailing: recordPath == pathName && isPlaying
                                ? Lottie.asset("assets/music_wave.json",
                                    width:
                                        40, // Ensure Lottie has fixed dimensions
                                    height: 30,
                                    controller: controller)
                                : const SizedBox(
                                    width: 20,
                                    height: 20,
                                  ),
                            leading: const Icon(EneftyIcons.music_play_bold),
                            title: Text(
                              p.basename(recording.path),
                              style: GoogleFonts.sora(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      );
                    }, childCount: _recordings.length),
                  )
                ],
              )),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                child: CircleAvatar(
                  child: IconButton(
                    onPressed: () async {
                      try {
                        if (isPlaying) {
                        await _audioPlayer.pause();
                        setState(() {
                          isPlaying = false;
                        });
                      } else {
                        if (recordPath != null) {
                          _audioPlayer.play();
                          setState(() {
                            isPlaying = true;
                          });
                        }
                      }
                      } catch (e) {
                        print(e);
                      }
                      
                    },
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(formatTime(position)),
                    Expanded(
                        child: Slider(
                      overlayColor: WidgetStateProperty.all(Colors.blue
                          .withOpacity(0.2)), // Change the overlay color
                      thumbColor: Colors.blue, // Change the thumb color
                      activeColor: Colors.teal,
                      min: 0,
                      max: (duration.inSeconds > 0)
                          ? duration.inSeconds.toDouble()
                          : 1, // Set a fallback max value
                      value: (position != null &&
                              duration != null &&
                              duration.inSeconds > 0)
                          ? position.inSeconds.toDouble()
                          : 0, // Prevent out-of-bounds error
                      onChanged: (value) async {
                        if (duration != null && duration.inSeconds > 0) {
                          final newPosition = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(newPosition);
                          setState(() {
                            position = newPosition;
                          });
                        }
                      },
                    )),
                    Text(formatTime(duration - position)),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  String formatTime(Duration duration) {
    final seconds = duration.inSeconds % 60;
    final minutes = (duration.inSeconds - seconds) ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
