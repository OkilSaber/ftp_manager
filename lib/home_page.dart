import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ftp_manager/file_view.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'configs_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Box box = Hive.box<Config>('FTPConfigs');
  late List<Config> configs;
  late List<Widget> configTiles;

  void updateConfigs() {
    setState(() => configs = box.values.toList().cast<Config>());
  }

  void updateConfigsTiles() {
    setState(() => configTiles = configs.map((config) {
          return CupertinoListTile(
            onTap: () => {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => FileView(config: config),
                ),
              )
            },
            title: Text(
              config.name,
              style: TextStyle(
                fontSize: 20,
                color:
                    MediaQuery.of(context).platformBrightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
              ),
            ),
            subtitle: Text(config.host),
            trailing: Text(config.port.toString()),
          );
        }).toList());
  }

  @override
  void initState() {
    updateConfigs();
    updateConfigsTiles();
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
            onPressed: () => {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const ConfigsList(),
                ),
              ).then((value) {
                updateConfigs();
                updateConfigsTiles();
              })
            },
            icon: const Icon(Icons.language_rounded),
          ),
        ],
      ),
      body: CupertinoListSection(
        header: const Text("Configurations"),
        children: configTiles,
      ),
    );
  }
}
