import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'video_analysis.dart';

class VideoPlayerWidget extends StatefulWidget {
  final File file;
  final String uuid;

  VideoPlayerWidget({this.file, this.uuid});

  @override
  State<StatefulWidget> createState() {
    return VideoPlayerWidgetState();
  }
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  TargetPlatform _platform;
  VideoPlayerController _videoPlayerController;
  ChewieController _chewieController;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();

    _videoPlayerController = VideoPlayerController.file(widget.file);

    _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: 1,
        // aspectRatio: _video.aspectRatio,
        autoPlay: true,
        looping: true,
        allowedScreenSleep: true,
        allowFullScreen: true);
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  Future<VideoAnalysis> getURLAndDownloadFile() async {
    final StorageReference ref = _storage.ref().child("${widget.uuid}.json");
    final String url = await ref.getDownloadURL();
    final http.Response response = await http.get(url);

    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      final analysis = VideoAnalysis.fromJson(json.decode(response.body));
      return analysis;
    } else {
      throw Exception('Failed to load post');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Video Analysis Result'),
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                child: Container(
                    height: 214,
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: Firestore.instance
                          .collection('results')
                          .document(widget.uuid)
                          .snapshots(),
                      builder: (BuildContext context,
                          AsyncSnapshot<DocumentSnapshot> snapshotDoc) {
                        if (snapshotDoc.hasError)
                          return Center(
                              child: Text('Error: ${snapshotDoc.error}'));

                        switch (snapshotDoc.connectionState) {
                          case ConnectionState.waiting:
                            return Center(child: Text('Loading...'));

                          default:
                            if (snapshotDoc.hasData &&
                                snapshotDoc.data.data != null) {
                              final data = snapshotDoc.data.data;
                              final status = data['status'];
                              if (status == 'finished') {
                                return FutureBuilder<VideoAnalysis>(
                                  future: getURLAndDownloadFile(),
                                  builder: (build, snapshot) {
                                    if (snapshot.hasData) {
                                      final widgets = snapshot.data.annotations
                                          .map((f) => CategoryBadgeItem(
                                                text: f.title,
                                              ))
                                          .toList();

                                      return Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: ListView(
                                            children: <Widget>[
                                              Wrap(
                                                children: widgets,
                                              )
                                            ],
                                          ));
                                    } else if (snapshot.hasError) {
                                      return Center(
                                        child: Text(snapshot.error.toString()),
                                      );
                                    }
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );
                              } else {
                                return Center(
                                  child: Text('Analyzing Video Context...'),
                                );
                              }
                            } else {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                        }
                      },
                    ))),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 214,
              child: Container(
                color: Colors.black,
                child: Chewie(
                  controller: _chewieController,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CategoryBadgeItem extends StatelessWidget {
  final String text;

  CategoryBadgeItem({this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(right: 4, bottom: 4),
        child: Container(
          child: Text(
            this.text,
            style: Theme.of(context).textTheme.body1.apply(color: Colors.white),
          ),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.blue, borderRadius: BorderRadius.circular(4.0)),
        ));
  }
}
