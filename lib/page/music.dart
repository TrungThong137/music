import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:test_music/model/lyric_model.dart';
import 'package:xml/xml.dart' as xml;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  String? duration;
  String? position;
  bool isPlay = false;
  double value = 0;
  double max = 0;

  List<LyricModel?> lyricMusic = [];
  List<LyricModel?> lyricCharacterMusic = [];
  String? lyricCurrent = '';
  double? lyricCurrentTime = 0.0;
  final scrollController = ScrollController();
  int currentIndex = 0;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    initAudioPlayer();
    loadLyrics();
  }

  Future<void> loadLyrics() async {
    String lyricsXml = await rootBundle.loadString('assets/lyric.xml');
    var document = xml.XmlDocument.parse(lyricsXml);
    var lyricList = document.findAllElements('param').map((node) {
      String lyricText = node.children.map((e) => e.text).join(' ');
      for (var item in node.findElements('i')) {
        return LyricModel(words: lyricText,time: double.parse(item.getAttribute('va') ?? '0'));
      }
    }).toList();
    // var lyricMusicList = document.findAllElements('data').expand((dataNode) {
    //   return dataNode.findElements('param').expand((paramNode) {
    //     var paramList = paramNode.findElements('i').map((iNode) {
    //       return LyricModel(
    //         words: iNode.text.trim(),
    //         time: double.parse(iNode.getAttribute('va') ?? '0'),
    //       );
    //     }).toList();
    //     return paramList;
    //   });
    // }).toList();
    setState(() {
      lyricMusic = lyricList;
      // lyricCharacterMusic = lyricMusicList;
    });
  }

  Future<void> initAudioPlayer() async {
    await audioPlayer.setAsset('assets/beat.mp3');
    setState(() {});
  }

  void updatePosition() {
    audioPlayer.durationStream.listen((event) {
      duration = event.toString().split(".")[0];
      max = event!.inSeconds.toDouble();
      setState(() {});
    });
    audioPlayer.positionStream.listen((event) {
      position = event.toString().split(".")[0];
      value = event.inSeconds.toDouble();
      for (int i = 0; i < lyricMusic.length; i++) {
        if ((value - double.parse(lyricMusic[i]!.time.toString().split('.')[0])).abs() < 0.5) {
          lyricCurrent = lyricMusic[i]?.words?.replaceAll('\n ', '');
          lyricCurrentTime = lyricMusic[i]!.time;
          currentIndex = i;
          if (currentIndex > 3 && currentIndex < lyricMusic.length - 2) {
            scrollToCenter(currentIndex);
          } 
          break;
        }
      }
      setState(() {});
    });
  }

  void playPause() async {
    if (audioPlayer.playing) {
      audioPlayer.pause();
    } else {
      audioPlayer.play();
    }
    updatePosition();
    isPlay = !isPlay;
    setState(() {});
  }

  void playSong(String uri) {
    try {
      audioPlayer.setAsset(uri);
      audioPlayer.play();
      isPlay = true;
      updatePosition();
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
    setState(() {});
  }

  void changeDurationToSeconds(int second) {
    var duration = Duration(seconds: second);
    audioPlayer.seek(duration);
    setState(() {});
  }

  void scrollToCenter(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              buildLyricMusic(),
              buildSlideMusic(),
              buildButtonMusic(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLyricMusic() {
    return lyricMusic.isNotEmpty
        ? Container(
            color: Colors.black,
            height: 300,
            child: ScrollablePositionedList.builder(
              itemCount: lyricMusic.length,
              itemBuilder: (context, index) {
                final lyricLine = lyricMusic[index]?.words?.replaceAll('\n ', '');
                final lyricTime = lyricMusic[index]?.time;
                return Text(
                  lyricLine ?? '',
                  style: TextStyle(
                      fontSize: 16.0,
                      color: (lyricCurrent == lyricLine && lyricCurrentTime == lyricTime)
                          ? Colors.amber
                          : Colors.white),
                  textAlign: TextAlign.center,
                );
              },
              itemScrollController: itemScrollController,
              itemPositionsListener: itemPositionsListener,
            ),
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }

  Widget buildSlideMusic() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(
            position ?? '',
          ),
          Expanded(
              child: Slider(
            thumbColor: Colors.amber,
            min: const Duration(seconds: 0).inSeconds.toDouble(),
            max: max,
            value: value,
            onChanged: (newValue) {
              changeDurationToSeconds(newValue.toInt());
              setState(() {});
            },
          )),
          Text(
            duration ?? '',
          ),
        ],
      ),
    );
  }

  Widget buildButtonMusic() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          child: IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: () => playSong('assets/beat.mp3'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: IconButton(
            icon: Icon(isPlay ? Icons.pause : Icons.play_arrow),
            onPressed: () => playPause(),
          ),
        ),
        CircleAvatar(
          child: IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: () => playSong('assets/beat.mp3'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
