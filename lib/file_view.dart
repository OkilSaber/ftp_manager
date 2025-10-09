// ignore_for_file: implementation_imports, use_build_context_synchronously

import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:ftp_manager/download_dialog.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ftp_file.dart';

class FileView extends StatefulWidget {
  final Config config;
  const FileView({super.key, required this.config});

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> with WidgetsBindingObserver {
  late FTPConnect ftpConnect;
  bool connected = false;
  List<FTPFile> files = [];
  String currentDirectory = "/";
  bool inSelection = false;
  bool allSelected = false;
  AppLifecycleState? lastState;

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
                "Type: ${entry.type == FTPEntryType.dir ? "Directory" : "File"}",
              ),
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
              onPressed: () async {
                late Directory localDirectory;
                if (Platform.isIOS) {
                  localDirectory = await getApplicationDocumentsDirectory();
                } else {
                  String? path = await FilePicker.platform.getDirectoryPath();
                  if (path != null) {
                    localDirectory = Directory.fromUri(Uri.parse(path));
                  } else {
                    return;
                  }
                }
                if (entry.type == FTPEntryType.dir) {
                  await directoryDownloader(
                    localDirectory: localDirectory,
                    remoteDirectory: entry.name,
                  );
                } else {
                  File file = File("${localDirectory.path}/${entry.name}");
                  await showDownloaderDialog(
                    context,
                    name: "$currentDirectory/${entry.name}",
                    file: file,
                  ).then((res) => Navigator.pop(context));
                }
              },
              child: const Text("Télécharger"),
            ),
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
                          child: const Text("Annuler"),
                        ),
                        TextButton(
                          onPressed: () {
                            showLoaderDialog(
                              context,
                              message: "Suppression...",
                            );
                            if (entry.type == FTPEntryType.dir) {
                              ftpConnect.deleteDirectory(entry.name).then((
                                value,
                              ) {
                                Navigator.pop(context);
                                Navigator.pop(context);
                                showLoaderDialog(context);
                                loadDirectory();
                              });
                            } else {
                              ftpConnect.deleteFile(entry.name).then((value) {
                                loadDirectory();
                                Navigator.pop(context);
                                Navigator.pop(context);
                              });
                            }
                          },
                          child: const Text("Supprimer"),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text("Supprimer"),
            ),
            TextButton(
              onPressed: () {
                String path = "$currentDirectory/${entry.name}";
                Clipboard.setData(ClipboardData(text: path));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copié dans le presse-papier")),
                );
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

  void showLoaderDialog(
    BuildContext context, {
    String message = "Chargement...",
  }) {
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

  Future<void> showDownloaderDialog(
    BuildContext context, {
    String message = "Chargement...",
    required File file,
    required String name,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext appContext) {
        return AlertDialog(
          content: DownloadDialog(
            file: file,
            name: name,
            ftpConnect: ftpConnect,
            message: message,
          ),
        );
      },
    );
  }

  Future<bool> showConfirmationDialog({
    String title = "Êtes-vous sûr?",
    String message = "Voulez vous vraiment supprimer ce fichier?",
    String confirm = "Supprimer",
    String cancel = "Annuler",
  }) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> showErrorDialog({
    required FTPConnectException error,
    String title = "Une erreur s'est produite",
    String confirm = "Ok",
  }) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text("Code: ${error.response} - ${error.message}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(confirm),
            ),
          ],
        );
      },
    );
  }

  void uploadFile() {
    if (Platform.isAndroid) {
      Permission.manageExternalStorage.request().then((value) {
        if (value.isGranted) {
          FilePicker.platform.pickFiles(allowMultiple: true).then((
            FilePickerResult? value,
          ) async {
            if (value != null) {
              showLoaderDialog(context);
              for (var i = 0; i < value.files.length; i++) {
                File chosenFile = File(value.files[i].path!);
                await ftpConnect.uploadFileWithRetry(
                  chosenFile,
                  pRetryCount: 5,
                );
              }
              await loadDirectory();
            }
          });
        }
      });
    } else if (Platform.isIOS) {
      FilePicker.platform.pickFiles(allowMultiple: true).then((
        FilePickerResult? value,
      ) async {
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

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (bytes > 0) ? (log(bytes) / log(1024)).floor() : 0;
    double size = bytes / pow(1024, i);
    return "${size.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  Future<void> directoryDownloader({
    required Directory localDirectory,
    required String remoteDirectory,
  }) async {
    Directory newLocalDirectory = Directory(
      "${localDirectory.path}/$remoteDirectory",
    );
    newLocalDirectory.createSync();
    bool allowed = await ftpConnect.changeDirectory(remoteDirectory);
    String currentDirectory = await ftpConnect.currentDirectory();
    if (allowed) {
      List<FTPEntry> dirFiles = await ftpConnect.listDirectoryContent();
      for (var j = 0; j < dirFiles.length; j++) {
        if (dirFiles[j].type == FTPEntryType.dir) {
          await directoryDownloader(
            localDirectory: newLocalDirectory,
            remoteDirectory: dirFiles[j].name,
          );
        } else {
          File file = File("${newLocalDirectory.path}/${dirFiles[j].name}");
          file.createSync();
          await showDownloaderDialog(
            context,
            name: "$currentDirectory/${dirFiles[j].name}",
            file: file,
          );
        }
      }
      await ftpConnect.changeDirectory("..");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      showLoaderDialog(context);
      ftpConnect = FTPConnect(
        widget.config.host,
        user: widget.config.username,
        pass: widget.config.password,
        port: widget.config.port,
        timeout: 20,
      );

      ftpConnect
          .connect()
          .then((value) {
            loadDirectory();
            setState(() {
              connected = true;
            });
          })
          .catchError((error) {
            Navigator.pop(context);
            showErrorDialog(
              error: error,
            ).then((value) => Navigator.pop(context));
          });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => lastState = state);
    print("⏳⏳⏳⏳⏳⏳NEW STATE IS $state ⏳⏳⏳⏳⏳⏳");
    switch (state) {
      case AppLifecycleState.resumed:
        print("COMING BACK 🚧 $connected");
        if (!connected) {
          ftpConnect.connect().then(
            (value) => setState(() => connected = false),
          );
        } else {
          ftpConnect
              .disconnect()
              .then((res) => setState(() => connected = false))
              .then((value) {
                ftpConnect.connect().then(
                  (value) => setState(() => connected = false),
                );
              });
        }
        break;
      case AppLifecycleState.inactive:
        if (connected) {
          ftpConnect.disconnect().then((res) {
            setState(() => connected = false);
          });
        }
        break;
      case AppLifecycleState.paused:
        if (connected) {
          ftpConnect.disconnect().then((res) {
            setState(() => connected = false);
          });
        }
        break;
      case AppLifecycleState.detached:
        if (connected) {
          ftpConnect.disconnect().then((res) {
            setState(() => connected = false);
          });
        }
        break;
      case AppLifecycleState.hidden:
        if (connected) {
          ftpConnect.disconnect().then((res) {
            setState(() => connected = false);
          });
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
                    late Directory localDirectory;
                    if (Platform.isIOS) {
                      localDirectory = await getApplicationDocumentsDirectory();
                    } else {
                      String? path = await FilePicker.platform
                          .getDirectoryPath();
                      if (path != null) {
                        localDirectory = Directory.fromUri(Uri.parse(path));
                      } else {
                        return;
                      }
                    }
                    for (var i = 0; i < files.length; i++) {
                      if (files[i].selected) {
                        if (files[i].entry.type == FTPEntryType.dir) {
                          await directoryDownloader(
                            localDirectory: localDirectory,
                            remoteDirectory: files[i].entry.name,
                          );
                        } else {
                          File file = File(
                            "${localDirectory.path}/${files[i].entry.name}",
                          );
                          await showDownloaderDialog(
                            context,
                            name: "$currentDirectory/${files[i].entry.name}",
                            file: file,
                          );
                        }
                      }
                    }
                    leaveSelection();
                  },
                  icon: const Icon(Icons.download_rounded),
                ),
                IconButton(
                  onPressed: () async {
                    bool delete = await showConfirmationDialog();
                    if (delete) {
                      showLoaderDialog(context);
                      for (var i = 0; i < files.length; i++) {
                        if (files[i].selected) {
                          if (files[i].entry.type == FTPEntryType.dir) {
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
                    }
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
                ),
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
                ),
              ]),
      ),
      body: Column(
        children: [
          SizedBox(
            // color: Colors.amber,
            height: 50,
            width: double.infinity,
            child: Padding(
              padding: EdgeInsetsGeometry.all(15),
              child: Row(
                children: [
                  Icon(Icons.folder_rounded, color: Colors.blue),
                  const SizedBox(width: 15),
                  Text(currentDirectory),
                ],
              ),
            ),
          ),
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
          Container(height: 2, width: double.infinity, color: Colors.white),
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
                  leading: files[index].entry.type == FTPEntryType.dir
                      ? const Icon(Icons.folder_rounded, color: Colors.blue)
                      : const Icon(Icons.file_copy_rounded),
                  title: Text(files[index].entry.name),
                  subtitle: files[index].entry.type == FTPEntryType.dir
                      ? null
                      : Text(formatBytes(files[index].entry.size ?? 0)),
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
                                  Icons.check_box_outline_blank_rounded,
                                ),
                              )),
                  onTap: () {
                    if (files[index].entry.type == FTPEntryType.dir &&
                        !inSelection) {
                      showLoaderDialog(context);
                      ftpConnect.changeDirectory(files[index].entry.name).then((
                        value,
                      ) {
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
            ),
          ),
        ],
      ),
    );
  }
}
