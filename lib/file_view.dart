// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:ftpconnect/src/ftp_entry.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ftp_file.dart';

class FileView extends StatefulWidget {
  final Config config;
  const FileView({super.key, required this.config});

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  late FTPConnect ftpConnect;
  List<FTPFile> files = [];
  String currentDirectory = "/";
  double progress = 0.0;
  bool inSelection = false;
  bool allSelected = false;

  Future<void> loadDirectory({bool pop = true}) async {
    await ftpConnect.listDirectoryContent().then((valueFiles) {
      ftpConnect.currentDirectory().then((value) {
        setState(() {
          currentDirectory = value;
          files = valueFiles.map((e) => FTPFile(e)).toList();
        });
        if (pop) Navigator.pop(context);
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
                                showLoaderDialog(
                                  context,
                                  message: "Suppression...",
                                );
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

  void showPercentLoaderDialog(BuildContext context,
      {String message = "Chargement..."}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        double progress = this.progress;
        return StatefulBuilder(
          builder: (context, setstate) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularPercentIndicator(
                    progressColor: Colors.blue,
                    backgroundColor: Colors.transparent,
                    radius: 20,
                    lineWidth: 2,
                    percent: progress,
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 7),
                    child: Text(message),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void uploadFile() {
    if (Platform.isAndroid) {
      Permission.manageExternalStorage.request().then((value) {
        if (value.isGranted) {
          FilePicker.platform
              .pickFiles(allowMultiple: true)
              .then((FilePickerResult? value) async {
            if (value != null) {
              showLoaderDialog(context);
              for (var i = 0; i < value.files.length; i++) {
                File chosenFile = File(value.files[i].path!);
                await ftpConnect.uploadFileWithRetry(chosenFile,
                    pRetryCount: 5);
              }
              await loadDirectory();
            }
          });
        }
      });
    } else if (Platform.isIOS) {
      FilePicker.platform
          .pickFiles(allowMultiple: true)
          .then((FilePickerResult? value) async {
        if (value != null) {
          showLoaderDialog(context);
          for (var i = 0; i < value.files.length; i++) {
            File chosenFile = File(value.files[i].path!);
            await ftpConnect.uploadFileWithRetry(chosenFile, pRetryCount: 5);
          }
          await loadDirectory();
        }
      });
    }
  }

  bool checkSelection() {
    bool tmp = true;
    for (var i = 0; i < files.length; i++) {
      if (!files[i].selected) {
        tmp = false;
        break;
      }
    }
    return tmp;
  }

  void leaveSelection() {
    setState(() {
      inSelection = false;
      allSelected = false;
      for (var i = 0; i < files.length; i++) {
        files[i].selected = false;
      }
    });
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
        leading: inSelection
            ? IconButton(
                onPressed: () => leaveSelection(),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: const Text("FTP client"),
        centerTitle: true,
        elevation: 0,
        actions: (inSelection
            ? [
                IconButton(
                  onPressed: () async {
                    showLoaderDialog(context);
                    for (var i = 0; i < files.length; i++) {
                      if (files[i].selected) {
                        if (files[i].entry.type == FTPEntryType.DIR) {
                          await ftpConnect
                              .deleteDirectory(files[i].entry.name)
                              .then((value) {});
                        } else {
                          await ftpConnect
                              .deleteFile(files[i].entry.name)
                              .then((value) {});
                        }
                      }
                    }
                    await loadDirectory();
                    leaveSelection();
                  },
                  icon: const Icon(Icons.delete_rounded),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      allSelected = !allSelected;
                      for (var i = 0; i < files.length; i++) {
                        files[i].selected = allSelected;
                      }
                    });
                  },
                  icon: allSelected
                      ? const Icon(Icons.check_box_rounded)
                      : const Icon(Icons.select_all_rounded),
                )
              ]
            : [
                IconButton(
                  onPressed: () {
                    uploadFile();
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                ),
                IconButton(
                  onPressed: () {
                    showLoaderDialog(context);
                    loadDirectory();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                )
              ]),
      ),
      body: Column(
        children: [
          (currentDirectory != "/" && !inSelection
              ? GestureDetector(
                  onTap: () {
                    showLoaderDialog(context);
                    ftpConnect.changeDirectory("..").then((value) {
                      loadDirectory();
                    });
                  },
                  child: const ListTile(
                    leading: Icon(Icons.folder_rounded, color: Colors.blue),
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
                onLongPress: () {
                  if (!inSelection) {
                    setState(() {
                      inSelection = true;
                      files[index].selected = true;
                    });
                  }
                },
                leading: files[index].entry.type == FTPEntryType.DIR
                    ? const Icon(Icons.folder_rounded, color: Colors.blue)
                    : const Icon(Icons.file_copy_rounded),
                title: Text(files[index].entry.name),
                subtitle: files[index].entry.type == FTPEntryType.DIR
                    ? null
                    : Text("${files[index].entry.size} bytes"),
                trailing: !inSelection
                    ? IconButton(
                        icon: const Icon(Icons.info_rounded),
                        onPressed: () => infoDialog(files[index].entry),
                      )
                    : (files[index].selected
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                files[index].selected = false;
                                allSelected = false;
                              });
                            },
                            icon: const Icon(Icons.check_box_rounded),
                          )
                        : IconButton(
                            onPressed: () {
                              setState(() {
                                files[index].selected = true;
                                allSelected = checkSelection();
                              });
                            },
                            icon: const Icon(
                                Icons.check_box_outline_blank_rounded),
                          )),
                onTap: () {
                  if (files[index].entry.type == FTPEntryType.DIR &&
                      !inSelection) {
                    showLoaderDialog(context);
                    ftpConnect
                        .changeDirectory(files[index].entry.name)
                        .then((value) {
                      loadDirectory();
                    });
                  } else if (inSelection) {
                    setState(() {
                      files[index].selected = !files[index].selected;
                      allSelected = checkSelection();
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
