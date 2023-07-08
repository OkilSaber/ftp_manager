// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
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
  late Future<List<FTPEntry>> files = Future(() => []);
  late Future<String> currentDirectory = Future(() => "");

  void loadDirectory() {
    setState(() {
      files = ftpConnect.listDirectoryContent();
      files.then((value) {
        setState(() {
          currentDirectory = ftpConnect.currentDirectory();
        });
      });
    });
  }

  @override
  void initState() {
    ftpConnect = FTPConnect(
      widget.config.host,
      user: widget.config.username,
      pass: widget.config.password,
      port: widget.config.port,
    );
    ftpConnect.connect().then((value) => loadDirectory());
    super.initState();
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
            onPressed: () => {},
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<String>(
            future: currentDirectory,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data! != "/" && snapshot.data!.isNotEmpty) {
                  return GestureDetector(
                    onTap: () {
                      ftpConnect
                          .changeDirectory("..")
                          .then((value) => loadDirectory());
                    },
                    child: const ListTile(
                      leading: Icon(Icons.folder_rounded),
                      title: Text(".."),
                    ),
                  );
                } else {
                  return const Text("");
                }
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
          Expanded(
            child: FutureBuilder<List<FTPEntry>>(
              future: files,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (snapshot.data![index].type == FTPEntryType.DIR) {
                            ftpConnect
                                .changeDirectory(snapshot.data![index].name)
                                .then((value) => loadDirectory());
                          }
                        },
                        child: ListTile(
                          leading:
                              snapshot.data![index].type == FTPEntryType.DIR
                                  ? const Icon(Icons.folder_rounded)
                                  : const Icon(Icons.file_copy_rounded),
                          title: Text(snapshot.data![index].name),
                          subtitle: Text(
                            "${snapshot.data![index].size} bytes",
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
