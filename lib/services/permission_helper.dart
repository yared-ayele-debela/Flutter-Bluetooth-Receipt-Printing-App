import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.location,
    ].request();

    // Consider permission ok if bluetoothConnect or bluetoothScan are granted
    return statuses[Permission.bluetoothConnect]?.isGranted == true ||
        statuses[Permission.bluetoothScan]?.isGranted == true;
  }
}
