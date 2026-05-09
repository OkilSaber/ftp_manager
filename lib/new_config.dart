import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'widgets/glass_card.dart';
import 'widgets/gradient_scaffold.dart';

class NewConfig extends StatefulWidget {
  final Config config;
  final bool edit;
  const NewConfig({super.key, required this.config, this.edit = false});

  @override
  State<NewConfig> createState() => NewConfigState();
}

class NewConfigState extends State<NewConfig> {
  bool showPassword = false;
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
    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.edit ? "Edit Connection" : "New Connection"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.label_outline_rounded),
                        labelText: 'Connection Name',
                      ),
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        labelText: 'Username',
                      ),
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.dns_outlined),
                        labelText: 'Host / IP Address',
                      ),
                      controller: hostController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => showPassword = !showPassword),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      obscureText: !showPassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      controller: passwordController,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.router_outlined),
                        labelText: 'Port',
                      ),
                      controller: portController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text("Save Connection"),
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
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut),
        ),
      ),
    );
  }
}
