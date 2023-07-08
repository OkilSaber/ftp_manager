import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:hive_flutter/adapters.dart';

import 'new_config.dart';

class ConfigsList extends StatefulWidget {
  const ConfigsList({super.key});

  @override
  State<ConfigsList> createState() => _ConfigsListState();
}

class _ConfigsListState extends State<ConfigsList> {
  final Box box = Hive.box<Config>('FTPConfigs');
  late List<Config> configs;
  late List<Widget> configTiles;

  void updateConfigs() {
    setState(() => configs = box.values.toList().cast<Config>());
  }

  void updateConfigsTiles() {
    setState(() => configTiles = configs.map((config) {
          return GestureDetector(
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text("Delete config?"),
                  content: const Text(
                      "Are you sure you want to delete this config?"),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoDialogAction(
                      child: const Text("Delete"),
                      onPressed: () {
                        box.deleteAt(box.values.toList().indexOf(config));
                        updateConfigs();
                        updateConfigsTiles();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
            child: CupertinoListTile(
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => NewConfig(
                    edit: true,
                    config: config,
                  ),
                ),
              ).then((value) {
                updateConfigs();
                updateConfigsTiles();
              }),
              title: Text(
                config.name,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(config.host),
              trailing: Text(config.port.toString()),
            ),
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
        title: const Text("Configurations"),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => NewConfig(
                    config: Config(
                      name: "",
                      username: "",
                      host: "",
                      password: "",
                      port: 21,
                    ),
                  ),
                ),
              ).then((value) {
                updateConfigs();
                updateConfigsTiles();
              })
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: CupertinoListSection(
        children: configTiles,
      ),
    );
  }
}
