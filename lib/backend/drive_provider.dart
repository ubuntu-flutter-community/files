import 'dart:async';

import 'package:flutter/material.dart';
import 'package:udisks/udisks.dart';

class DriveProvider with ChangeNotifier {
  final UDisksClient _client = UDisksClient();
  late final StreamSubscription _blockDeviceAddSub;
  late final StreamSubscription _blockDeviceRemoveSub;
  late final StreamSubscription _driveAddSub;
  late final StreamSubscription _driveRemoveSub;

  final List<UDisksBlockDevice> _blockDevices = [];
  final List<UDisksDrive> _drives = [];

  List<UDisksBlockDevice> get blockDevices => List.of(_blockDevices);
  List<UDisksDrive> get drives => List.of(_drives);

  Future<void> init() async {
    await _client.connect();

    _blockDevices.addAll(_client.blockDevices);
    _drives.addAll(_client.drives);

    _blockDeviceAddSub = _client.blockDeviceAdded.listen(_onBlockDeviceAdded);
    _blockDeviceRemoveSub =
        _client.blockDeviceRemoved.listen(_onBlockDeviceRemoved);

    _driveAddSub = _client.driveAdded.listen(_onDriveAdded);
    _driveRemoveSub = _client.driveRemoved.listen(_onDriveRemoved);
  }

  @override
  Future<void> dispose() async {
    await _blockDeviceAddSub.cancel();
    await _blockDeviceRemoveSub.cancel();
    await _driveAddSub.cancel();
    await _driveRemoveSub.cancel();

    await _client.close();

    super.dispose();
  }

  void _onBlockDeviceAdded(UDisksBlockDevice event) {
    _blockDevices.add(event);
    notifyListeners();
  }

  void _onBlockDeviceRemoved(UDisksBlockDevice event) {
    _blockDevices.removeWhere((e) => event.id == e.id);
    notifyListeners();
  }

  void _onDriveAdded(UDisksDrive event) {
    _drives.add(event);
    notifyListeners();
  }

  void _onDriveRemoved(UDisksDrive event) {
    _drives.removeWhere((e) => event.id == e.id);
    notifyListeners();
  }
}
