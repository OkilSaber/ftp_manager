// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:ftpconnect/src/ftp_entry.dart';

class FileView extends StatefulWidget {
  final Config config;
  const FileView({super.key, required this.config});

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
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

  void infoDialog(FTPEntry entry) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entry.name),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  "Type: ${entry.type == FTPEntryType.DIR ? "Directory" : "File"}"),
              Text("Size: ${entry.size}"),
              Text("Owner: ${entry.owner}"),
              Text("Group: ${entry.group}"),
              Text("Permissions: ${entry.permission}"),
              Text("Last modified: ${entry.modifyTime}"),
            ],
          ),
          actionsOverflowAlignment: OverflowBarAlignment.start,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Supprimer ${entry.name} ?"),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Annuler")),
                          TextButton(
                              onPressed: () {
                                showLoaderDialog(context,
                                    message: "Suppression...");
                                if (entry.type == FTPEntryType.DIR) {
                                  ftpConnect
                                      .deleteDirectory(entry.name)
                                      .then((value) {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    showLoaderDialog(context);
                                    loadDirectory();
                                  });
                                } else {
                                  ftpConnect
                                      .deleteFile(entry.name)
                                      .then((value) {
                                    loadDirectory();
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  });
                                }
                              },
                              child: const Text("Supprimer")),
                        ],
                      );
                    });
              },
              child: const Text("Supprimer"),
            ),
            TextButton(
              onPressed: () {
                String path = "$currentDirectory/${entry.name}";
                Clipboard.setData(ClipboardData(text: path));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Copié dans le presse-papier"),
                ));
              },
              child: const Text("Copier le chemin"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  void showLoaderDialog(BuildContext context,
      {String message = "Chargement..."}) {
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
                child: Text(message),
              ),
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
            onPressed: () {
              showLoaderDialog(context);
              loadDirectory();
            },
            icon: const Icon(Icons.refresh_rounded),
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
                trailing: IconButton(
                  icon: const Icon(Icons.info_rounded),
                  onPressed: () => infoDialog(files[index]),
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
