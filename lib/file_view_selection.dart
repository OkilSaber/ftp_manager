// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:ftpconnect/src/ftp_entry.dart';

class FileViewSelection extends StatefulWidget {
  final Config config;
  const FileViewSelection({super.key, required this.config});

  @override
  State<FileViewSelection> createState() => _FileViewSelectionState();
}

class _FileViewSelectionState extends State<FileViewSelection> {
  late FTPConnect ftpConnect;
  List<FTPEntry> files = [];
  String currentDirectory = "/";

  void loadDirectory() {
    ftpConnect.listDirectoryContent().then((valueFiles) {
      ftpConnect.currentDirectory().then((value) {
        setState(() {
          currentDirectory = value;
          files = valueFiles;
        });
        Navigator.pop(context);
      });
    });
  }

  void showLoaderDialog(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              Container(
                  margin: const EdgeInsets.only(left: 7),
                  child: const Text("Chargement...")),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      showLoaderDialog(context);
      ftpConnect = FTPConnect(
        widget.config.host,
        user: widget.config.username,
        pass: widget.config.password,
        port: widget.config.port,
      );

      ftpConnect.connect().then((value) => loadDirectory());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FTP client"),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => {Navigator.pop(context, currentDirectory)},
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          (currentDirectory != "/"
              ? GestureDetector(
                  onTap: () {
                    showLoaderDialog(context);
                    ftpConnect.changeDirectory("..").then((value) {
                      loadDirectory();
                    });
                  },
                  child: const ListTile(
                    leading: Icon(Icons.folder_rounded),
                    title: Text(".."),
                  ),
                )
              : Container()),
          Expanded(
              child: ListView.builder(
            shrinkWrap: true,
            itemCount: files.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: files[index].type == FTPEntryType.DIR
                    ? const Icon(Icons.folder_rounded)
                    : const Icon(Icons.file_copy_rounded),
                title: Text(files[index].name),
                subtitle: Text(
                  "${files[index].size} bytes",
                ),
                onTap: () {
                  if (files[index].type == FTPEntryType.DIR) {
                    showLoaderDialog(context);
                    ftpConnect.changeDirectory(files[index].name).then((value) {
                      loadDirectory();
                    });
                  }
                },
              );
            },
          )),
        ],
      ),
    );
  }
}
