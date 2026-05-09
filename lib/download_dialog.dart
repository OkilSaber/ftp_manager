// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import 'theme/app_colors.dart';
import 'widgets/glass_card.dart';

class DownloadDialog extends StatefulWidget {
  final FTPConnect ftpConnect;
  final File file;
  final String name;
  final String message;

  const DownloadDialog({
    super.key,
    required this.ftpConnect,
    required this.file,
    required this.name,
    required this.message,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double progress = 0;

  @override
  void initState() {
    super.initState();
    widget.ftpConnect.downloadFile(
      widget.name,
      widget.file,
      onProgress: (progressInPercent, totalReceived, fileSize) {
        setState(() => progress = progressInPercent / 100);
      },
    ).then((value) {
      Navigator.pop(context);
    }).catchError((error) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Download Error"),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.mintAccent : AppColors.forestGreen;
    final secondaryColor = isDark ? AppColors.iceBlue : AppColors.forestGreenLight;
    final trackColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final barBgColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      blur: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularPercentIndicator(
            radius: 40,
            lineWidth: 6,
            percent: progress,
            backgroundColor: trackColor,
            progressColor: primaryColor,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animateFromLastPercent: true,
            center: Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => LinearPercentIndicator(
              width: constraints.maxWidth,
              percent: progress,
              progressColor: secondaryColor,
              backgroundColor: barBgColor,
              barRadius: const Radius.circular(4),
              padding: EdgeInsets.zero,
              animation: true,
              animateFromLastPercent: true,
            ),
          ),
        ],
      ),
    );
  }
}
