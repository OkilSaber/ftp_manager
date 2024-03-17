import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class DownloadDialog extends StatefulWidget {
  final FTPConnect ftpConnect;
  final File file;
  final String name;
  final String message;

  const DownloadDialog({
    super.key,
    required this.ftpConnect,
    required this.file,
    required this.name,
    required this.message,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double progress = 0;

  @override
  void initState() {
    super.initState();
    widget.ftpConnect.downloadFile(
      widget.name,
      widget.file,
      onProgress: (progressInPercent, totalReceived, fileSize) {
        setState(() => progress = progressInPercent / 100);
      },
    ).then((value) {
      Navigator.pop(context);
    }).catchError((error) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Erreur"),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("Fermer"),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircularPercentIndicator(
          radius: 20,
          percent: progress,
          backgroundColor: Colors.grey.shade300,
          progressColor: Colors.blueAccent,
        ),
        Container(
          margin: const EdgeInsets.only(left: 7),
          child: Text(widget.message),
        ),
      ],
    );
  }
}
