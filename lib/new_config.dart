import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NewConfig extends StatefulWidget {
  final Config config;
  final bool edit;
  const NewConfig({super.key, required this.config, this.edit = false});

  @override
  State<NewConfig> createState() => NewConfigState();
}

class NewConfigState extends State<NewConfig> {
  late Config config;
  late TextEditingController nameController;
  late TextEditingController usernameController;
  late TextEditingController hostController;
  late TextEditingController passwordController;
  late TextEditingController portController;
  final Box<Config> box = Hive.box('FTPConfigs');

  @override
  void initState() {
    config = widget.config;
    nameController = TextEditingController(text: config.name);
    usernameController = TextEditingController(text: config.username);
    hostController = TextEditingController(text: config.host);
    passwordController = TextEditingController(text: config.password);
    portController = TextEditingController(text: config.port.toString());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New configuration"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Name',
            ),
            controller: nameController,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Username',
            ),
            controller: usernameController,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Host',
            ),
            controller: hostController,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
            ),
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            controller: passwordController,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Port',
            ),
            controller: portController,
          ),
          const SizedBox(height: 10),
          CupertinoButton.filled(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  usernameController.text.isEmpty ||
                  hostController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  portController.text.isEmpty) {
                return;
              }

              config.name = nameController.text;
              config.username = usernameController.text;
              config.host = hostController.text;
              config.password = passwordController.text;
              config.port = int.parse(portController.text);
              if (widget.edit) {
                box.putAt(box.values.toList().indexOf(config), config);
              } else {
                box.add(config);
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
