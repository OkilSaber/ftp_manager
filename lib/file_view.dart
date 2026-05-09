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
import 'theme/app_colors.dart';
import 'widgets/animated_list_item.dart';
import 'widgets/glass_card.dart';
import 'widgets/gradient_scaffold.dart';

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
  final Map<String, List<FTPFile>> _dirCache = {};
  Future<void>? _pendingNavigation;

  // View options
  SortOption _sortOption = SortOption.nameAsc;
  bool _hideHidden = true;

  List<FTPFile> get _visibleFiles {
    var result = files.where((f) {
      if (_hideHidden && f.entry.name.startsWith('.')) return false;
      return true;
    }).toList();

    result.sort((a, b) {
      final aIsDir = a.entry.type == FTPEntryType.dir;
      final bIsDir = b.entry.type == FTPEntryType.dir;
      if (aIsDir != bIsDir) return aIsDir ? -1 : 1;

      switch (_sortOption) {
        case SortOption.nameAsc:
          return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
        case SortOption.nameDesc:
          return b.entry.name.toLowerCase().compareTo(a.entry.name.toLowerCase());
        case SortOption.sizeAsc:
          return (a.entry.size ?? 0).compareTo(b.entry.size ?? 0);
        case SortOption.sizeDesc:
          return (b.entry.size ?? 0).compareTo(a.entry.size ?? 0);
        case SortOption.dateDesc:
          final at = a.entry.modifyTime;
          final bt = b.entry.modifyTime;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        case SortOption.dateAsc:
          final at = a.entry.modifyTime;
          final bt = b.entry.modifyTime;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return at.compareTo(bt);
      }
    });
    return result;
  }

  Future<void> loadDirectory({bool pop = true, bool forceRefresh = false}) async {
    await ftpConnect.listDirectoryContent().then((valueFiles) {
      ftpConnect.currentDirectory().then((value) {
        final loaded = valueFiles.map((e) => FTPFile(e)).toList();
        _dirCache[value] = loaded;
        setState(() {
          currentDirectory = value;
          files = loaded;
        });
        if (pop) Navigator.pop(context);
      });
    });
  }

  String _resolvePath(String dir) {
    if (dir == "..") {
      if (currentDirectory == "/") return "/";
      final parts = currentDirectory.split("/")..removeLast();
      return parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)
          ? "/"
          : parts.join("/");
    }
    return currentDirectory == "/" ? "/$dir" : "$currentDirectory/$dir";
  }

  Future<void> changeDirectory(String dir) async {
    final newPath = _resolvePath(dir);
    if (_dirCache.containsKey(newPath)) {
      // Instant UI update from cache
      setState(() {
        currentDirectory = newPath;
        files = _dirCache[newPath]!;
      });
      // Navigate on FTP in background; tracked so file ops can await it
      _pendingNavigation = ftpConnect.changeDirectory(dir);
    } else {
      showLoaderDialog(context);
      await ftpConnect.changeDirectory(dir);
      await loadDirectory();
    }
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
              _infoRow(Icons.category_outlined,
                  "Type", entry.type == FTPEntryType.dir ? "Directory" : "File"),
              _infoRow(Icons.data_usage_rounded, "Size",
                  formatBytes(entry.size ?? 0)),
              _infoRow(Icons.person_outline_rounded, "Owner", entry.owner ?? "-"),
              _infoRow(Icons.group_outlined, "Group", entry.group ?? "-"),
              _infoRow(
                  Icons.lock_outline_rounded, "Permissions", entry.permission ?? "-"),
              _infoRow(Icons.schedule_rounded, "Modified",
                  entry.modifyTime?.toString() ?? "-"),
            ],
          ),
          actionsOverflowAlignment: OverflowBarAlignment.start,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text("Download"),
              onPressed: () async {
                await _pendingNavigation;
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
                    name: entry.name,
                    file: file,
                  ).then((res) => Navigator.pop(context));
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text("Delete"),
              style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text("Delete ${entry.name}?"),
                      content: const Text("This action cannot be undone."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.errorRed),
                          onPressed: () async {
                            await _pendingNavigation;
                            showLoaderDialog(context, message: "Deleting...");
                            _dirCache.remove(currentDirectory);
                            if (entry.type == FTPEntryType.dir) {
                              ftpConnect.deleteDirectory(entry.name).then((value) {
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
                          child: const Text("Delete"),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text("Copy path"),
              onPressed: () {
                String path = "$currentDirectory/${entry.name}";
                Clipboard.setData(ClipboardData(text: path));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Path copied to clipboard")),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16,
              color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text("$label: ",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  void showLoaderDialog(BuildContext context,
      {String message = "Loading..."}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator.adaptive(),
              Container(
                margin: const EdgeInsets.only(left: 12),
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
    String message = "Downloading...",
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
    String title = "Are you sure?",
    String message = "This action cannot be undone.",
    String confirm = "Delete",
    String cancel = "Cancel",
  }) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> showErrorDialog({
    required FTPConnectException error,
    String title = "Connection Error",
    String confirm = "Ok",
  }) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.errorRed),
              const SizedBox(height: 12),
              Text("Code: ${error.response} - ${error.message}"),
            ],
          ),
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

  Future<void> uploadFile() async {
    await _pendingNavigation;
    if (Platform.isAndroid) {
      Permission.manageExternalStorage.request().then((value) {
        if (value.isGranted) {
          FilePicker.platform.pickFiles(allowMultiple: true).then(
            (FilePickerResult? value) async {
              if (value != null) {
                showLoaderDialog(context, message: "Uploading...");
                for (var i = 0; i < value.files.length; i++) {
                  File chosenFile = File(value.files[i].path!);
                  await ftpConnect.uploadFileWithRetry(
                    chosenFile,
                    pRetryCount: 5,
                  );
                }
                _dirCache.remove(currentDirectory);
                await loadDirectory();
              }
            },
          );
        }
      });
    } else if (Platform.isIOS) {
      FilePicker.platform.pickFiles(allowMultiple: true).then(
        (FilePickerResult? value) async {
          if (value != null) {
            showLoaderDialog(context, message: "Uploading...");
            for (var i = 0; i < value.files.length; i++) {
              File chosenFile = File(value.files[i].path!);
              await ftpConnect.uploadFileWithRetry(chosenFile, pRetryCount: 5);
            }
            _dirCache.remove(currentDirectory);
            await loadDirectory();
          }
        },
      );
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
    Directory newLocalDirectory =
        Directory("${localDirectory.path}/$remoteDirectory");
    newLocalDirectory.createSync();
    bool allowed = await ftpConnect.changeDirectory(remoteDirectory);
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
            name: dirFiles[j].name,
            file: file,
          );
        }
      }
      await ftpConnect.changeDirectory("..");
    }
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(ext)) {
      return Icons.video_file_outlined;
    }
    if (['mp3', 'wav', 'flac', 'aac', 'm4a'].contains(ext)) {
      return Icons.audio_file_outlined;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['zip', 'tar', 'gz', 'rar', '7z'].contains(ext)) {
      return Icons.folder_zip_outlined;
    }
    if (['dart', 'js', 'ts', 'py', 'json', 'yaml', 'yml', 'xml', 'html',
        'css', 'sh', 'md'].contains(ext)) {
      return Icons.code_outlined;
    }
    return Icons.insert_drive_file_outlined;
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
            setState(() => connected = true);
          })
          .catchError((error) {
            Navigator.pop(context);
            showErrorDialog(error: error)
                .then((value) => Navigator.pop(context));
          });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => lastState = state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (!connected) {
          ftpConnect
              .connect()
              .then((value) => setState(() => connected = false));
        } else {
          ftpConnect
              .disconnect()
              .then((res) => setState(() => connected = false))
              .then((value) {
            ftpConnect
                .connect()
                .then((value) => setState(() => connected = false));
          });
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (connected) {
          ftpConnect
              .disconnect()
              .then((res) => setState(() => connected = false));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.mintAccent : AppColors.forestGreen;
    final secondaryColor = isDark ? AppColors.iceBlue : AppColors.forestGreenLight;

    return GradientScaffold(
      appBar: AppBar(
        leading: inSelection
            ? IconButton(
                onPressed: () => leaveSelection(),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(widget.config.name),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
              ),
            ),
          ),
        ),
        actions: inSelection
            ? [
                IconButton(
                  onPressed: () async {
                    await _pendingNavigation;
                    late Directory localDirectory;
                    if (Platform.isIOS) {
                      localDirectory = await getApplicationDocumentsDirectory();
                    } else {
                      String? path =
                          await FilePicker.platform.getDirectoryPath();
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
                              "${localDirectory.path}/${files[i].entry.name}");
                          await showDownloaderDialog(
                            context,
                            name: files[i].entry.name,
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
                    await _pendingNavigation;
                    bool delete = await showConfirmationDialog();
                    if (delete) {
                      showLoaderDialog(context, message: "Deleting...");
                      _dirCache.remove(currentDirectory);
                      for (var i = 0; i < files.length; i++) {
                        if (files[i].selected) {
                          if (files[i].entry.type == FTPEntryType.dir) {
                            await ftpConnect
                                .deleteDirectory(files[i].entry.name);
                          } else {
                            await ftpConnect.deleteFile(files[i].entry.name);
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
                  onPressed: () => uploadFile(),
                  icon: const Icon(Icons.upload_file_rounded),
                ),
                IconButton(
                  onPressed: () {
                    _dirCache.remove(currentDirectory);
                    showLoaderDialog(context);
                    loadDirectory();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
                PopupMenuButton<Object>(
                  icon: const Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('Sort by', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    ...[
                      (SortOption.nameAsc,  Icons.sort_by_alpha_rounded,      'Name A → Z'),
                      (SortOption.nameDesc, Icons.sort_by_alpha_rounded,      'Name Z → A'),
                      (SortOption.sizeAsc,  Icons.arrow_upward_rounded,       'Size small → large'),
                      (SortOption.sizeDesc, Icons.arrow_downward_rounded,     'Size large → small'),
                      (SortOption.dateDesc, Icons.access_time_rounded,        'Newest first'),
                      (SortOption.dateAsc,  Icons.access_time_outlined,       'Oldest first'),
                    ].map((t) => PopupMenuItem<Object>(
                      value: t.$1,
                      child: Row(children: [
                        Icon(t.$2, size: 16),
                        const SizedBox(width: 10),
                        Text(t.$3),
                        if (_sortOption == t.$1) ...[
                          const Spacer(),
                          Icon(Icons.check_rounded, size: 16,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ]),
                    )),
                    const PopupMenuDivider(),
                    PopupMenuItem<Object>(
                      value: 'toggleHidden',
                      child: Row(children: [
                        Icon(
                          _hideHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        const Text('Hide dotfiles'),
                        const Spacer(),
                        if (_hideHidden)
                          Icon(Icons.check_rounded, size: 16,
                              color: Theme.of(context).colorScheme.primary),
                      ]),
                    ),
                  ],
                  onSelected: (value) {
                    setState(() {
                      if (value == 'toggleHidden') {
                        _hideHidden = !_hideHidden;
                      } else {
                        _sortOption = value as SortOption;
                      }
                    });
                  },
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: GlassCard(
                blur: 12,
                borderRadius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, color: secondaryColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentDirectory,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (currentDirectory != "/" && !inSelection)
              AnimatedListItem(
                index: 0,
                child: GlassCard(
                  blur: 0,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  padding: EdgeInsets.zero,
                  borderRadius: 14,
                  child: ListTile(
                    leading: Icon(Icons.arrow_upward_rounded,
                        color: secondaryColor),
                    title: const Text(".."),
                    onTap: () => changeDirectory(".."),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                shrinkWrap: true,
                itemCount: _visibleFiles.length,
                itemBuilder: (context, index) {
                  final file = _visibleFiles[index];
                  final isDir = file.entry.type == FTPEntryType.dir;

                  Widget leading = isDir
                      ? Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      AppColors.iceBlue.withValues(alpha: 0.7),
                                      AppColors.mintAccent.withValues(alpha: 0.7),
                                    ]
                                  : [
                                      AppColors.forestGreen
                                          .withValues(alpha: 0.8),
                                      AppColors.forestGreenLight
                                          .withValues(alpha: 0.8),
                                    ],
                            ),
                          ),
                          child: Icon(
                            Icons.folder_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkBackground
                                : Colors.white,
                          ),
                        )
                      : Icon(_fileIcon(file.entry.name),
                          color: secondaryColor);

                  return AnimatedListItem(
                    index: index + 1,
                    child: GlassCard(
                      blur: 0,
                      isSelected: file.selected,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.zero,
                      borderRadius: 14,
                      child: ListTile(
                        onLongPress: () {
                          if (!inSelection) {
                            setState(() {
                              inSelection = true;
                              file.selected = true;
                            });
                          }
                        },
                        leading: leading,
                        title: Text(file.entry.name),
                        subtitle: isDir
                            ? null
                            : Text(formatBytes(file.entry.size ?? 0)),
                        trailing: !inSelection
                            ? IconButton(
                                icon: const Icon(
                                    Icons.info_outline_rounded),
                                onPressed: () =>
                                    infoDialog(file.entry),
                              )
                            : (file.selected
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        file.selected = false;
                                        allSelected = false;
                                      });
                                    },
                                    icon: Icon(Icons.check_box_outlined,
                                        color: primaryColor),
                                  )
                                : IconButton(
                                    onPressed: () {
                                      setState(() {
                                        file.selected = true;
                                        allSelected = checkSelection();
                                      });
                                    },
                                    icon: const Icon(
                                        Icons.check_box_outline_blank_rounded),
                                  )),
                        onTap: () {
                          if (isDir && !inSelection) {
                            changeDirectory(file.entry.name);
                          } else if (inSelection) {
                            setState(() {
                              file.selected = !file.selected;
                              allSelected = checkSelection();
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SortOption { nameAsc, nameDesc, sizeAsc, sizeDesc, dateAsc, dateDesc }
