import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ftp_manager/types/config.dart';
import 'package:hive_flutter/adapters.dart';

import 'new_config.dart';
import 'theme/app_colors.dart';
import 'widgets/animated_list_item.dart';
import 'widgets/glass_card.dart';
import 'widgets/gradient_scaffold.dart';

class ConfigsList extends StatefulWidget {
  const ConfigsList({super.key});

  @override
  State<ConfigsList> createState() => _ConfigsListState();
}

class _ConfigsListState extends State<ConfigsList> {
  final Box box = Hive.box<Config>('FTPConfigs');
  late List<Config> configs = [];

  void updateConfigs() {
    setState(() => configs = box.values.toList().cast<Config>());
  }

  void _showDeleteDialog(Config config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete '${config.name}'?"),
        content: const Text("This connection will be permanently removed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorRed,
            ),
            onPressed: () {
              box.deleteAt(box.values.toList().indexOf(config));
              updateConfigs();
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      updateConfigs();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.iceBlue : AppColors.forestGreenLight;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text("Configurations"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
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
            ).then((_) => updateConfigs()),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: configs.isEmpty
          ? SafeArea(
              child: Center(
                child: AnimatedListItem(
                  index: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_rounded,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text("No configurations",
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text("Tap + to add a new connection",
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: configs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Saved Connections",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${configs.length} server${configs.length != 1 ? 's' : ''}",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final config = configs[index - 1];
                return AnimatedListItem(
                  index: index,
                  child: GlassCard(
                    blur: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => NewConfig(edit: true, config: config),
                        ),
                      ).then((_) => updateConfigs()),
                      onLongPress: () => _showDeleteDialog(config),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [AppColors.mintAccent, AppColors.iceBlue]
                                    : [AppColors.forestGreen, AppColors.forestGreenLight],
                              ),
                            ),
                            child: Icon(
                              Icons.dns_rounded,
                              size: 20,
                              color: isDark
                                  ? AppColors.darkBackground
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  config.host,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceVariant
                                      : AppColors.lightSurfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ":${config.port}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: accentColor),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(Icons.more_vert_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurface),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
