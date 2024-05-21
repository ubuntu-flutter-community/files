import 'dart:async';
import 'dart:convert';

import 'package:files/backend/providers.dart';
import 'package:files/widgets/separated_flex.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:udisks/udisks.dart';
import 'package:yaru_icons/yaru_icons.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

class DriveList extends StatelessWidget {
  final ValueChanged<String>? onDriveTap;

  const DriveList({this.onDriveTap, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: driveProvider,
      builder: (context, _) {
        return SeparatedFlex.vertical(
          separator: SizedBox(
            height: YaruMasterDetailTheme.of(context).tileSpacing ?? 0,
          ),
          children: driveProvider.blockDevices
              .where(
                (e) =>
                    !e.userspaceMountOptions.contains("x-gdu.hide") &&
                    !e.userspaceMountOptions.contains("x-gvfs-hide"),
              )
              .where((e) => !e.hintIgnore && e.filesystem != null)
              .map(
                (e) => _DriveTile(
                  blockDevice: e,
                  onTap: onDriveTap,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DriveTile extends StatefulWidget {
  final UDisksBlockDevice blockDevice;
  final ValueChanged<String>? onTap;

  const _DriveTile({
    required this.blockDevice,
    this.onTap,
  });

  @override
  State<_DriveTile> createState() => _DriveTileState();
}

class _DriveTileState extends State<_DriveTile> {
  late Timer _pollingTimer;

  late String? mountPoint;

  @override
  void initState() {
    super.initState();
    mountPoint = getMountPoint();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 100), _onPoll);
  }

  @override
  void dispose() {
    _pollingTimer.cancel();
    super.dispose();
  }

  void _onPoll(Timer ref) {
    final String? currentMountPoint = getMountPoint();

    if (mountPoint != currentMountPoint) {
      mountPoint = currentMountPoint;
      setState(() {});
    }
  }

  String? getMountPoint() {
    return widget.blockDevice.filesystem!.mountPoints.isNotEmpty
        ? widget.blockDevice.filesystem!.mountPoints.first.decode()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    String? mountPoint = widget.blockDevice.filesystem!.mountPoints.isNotEmpty
        ? widget.blockDevice.filesystem!.mountPoints.first.decode()
        : null;

    final String? idLabel = widget.blockDevice.idLabel.isNotEmpty
        ? widget.blockDevice.idLabel
        : null;
    final String? hintName = widget.blockDevice.hintName.isNotEmpty
        ? widget.blockDevice.hintName
        : null;

    return ListTileTheme.merge(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      child: YaruMasterTile(
        leading: Icon(
          widget.blockDevice.drive?.ejectable == true
              ? YaruIcons.usb_stick
              : YaruIcons.drive_harddisk,
        ),
        title: Text(
          idLabel ??
              hintName ??
              "${filesize(widget.blockDevice.size, 1)} drive",
        ),
        subtitle: mountPoint != null ? Text(mountPoint) : null,
        trailing: mountPoint != null
            ? YaruOptionButton(
                onPressed: () async {
                  await widget.blockDevice.filesystem!.unmount();
                  setState(() {});
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
                child: const Icon(YaruIcons.eject),
              )
            : null,
        onTap: () async {
          if (mountPoint == null) {
            mountPoint = await widget.blockDevice.filesystem!.mount();
            setState(() {});
          }

          widget.onTap?.call(mountPoint!);
        },
      ),
    );
  }
}

extension on List<int> {
  String decode() {
    return utf8.decode(sublist(0, length - 1));
  }
}
