Future<void> collectAndSendBluetoothData([String? deviceInfo]) async {
  deviceInfo ??= _deviceInfo; // 使用默认设备信息

  List<String> bluetoothDataList = [];
  Set<String> deviceSet = {}; // 用于去重
    final permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
// 开始扫描
  await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

  // 监听扫描结果
  FlutterBluePlus.scanResults.listen((results) {
    for (var result in results) {
      String deviceName = result.device.name.isNotEmpty ? result.device.name : 'undefined';
      String deviceId = result.device.id.toString();
      String deviceInfo = '$deviceName:$deviceId';

      if (!deviceSet.contains(deviceInfo)) {
        deviceSet.add(deviceInfo);
        bluetoothDataList.add(deviceInfo); // 组合名称和 MAC 地址
      }
    }
  });

  // 等待扫描完成
  await Future.delayed(Duration(seconds: 5));

  // 停止扫描
  await FlutterBluePlus.stopScan();

  String bluetoothData = bluetoothDataList.join(';'); // 使用分号分隔
  String accessToken = await _getAccessToken();

  var response = await http.post(
    Uri.parse('http://gps.primedigitaltech.com:8000/sensor/updateBT/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({'connection_device': bluetoothData, 'device': deviceInfo}),
  );

  print("BTdatabodyis");
  print(bluetoothData);
  if (response.statusCode == 200) {
    print('Bluetooth data sent successfully');
  } else {
    print('Failed to send Bluetooth data: ${response.statusCode}');
}
