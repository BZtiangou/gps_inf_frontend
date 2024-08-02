import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data_observation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Polygon> polygonsss = [];
Future<String> getAccessToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    throw Exception('Access token not found in SharedPreferences');
  }
  return accessToken;
}

Future<void> fetchGPSData(Map<String, Marker> initMarkerMap) async {
  String accessToken = await getAccessToken();

  var url = Uri.parse('http://gps.primedigitaltech.com:8000/api/getGPSdata/');
  var response = await http.get(url, headers: {
    'Authorization': 'Bearer $accessToken',
  });

  if (response.statusCode == 200) {
    var jsonData = jsonDecode(response.body);
    initMarkerMap.clear();

    List<dynamic> locations = jsonData['Locations'];
    for (var location in locations) {
      var lat = location['latitude'] as double;
      var lng = location['longitude'] as double;
      var position = LatLng(lat, lng);
      var marker = Marker(
        position: position,
      );
      initMarkerMap[marker.id] = marker;
    }
  }
}

Future<void> fetchClusterData(BuildContext context) async {
  String accessToken = await getAccessToken();
  var url = Uri.parse('http://gps.primedigitaltech.com:8000/api/get_gpscluster/');
  var response = await http.get(url, headers: {
    'Authorization': 'Bearer $accessToken',
  });

  if (response.statusCode == 200) {
    List<dynamic> clusters = jsonDecode(response.body);
    List<LatLng> pendingGpsList = [];

    for (var cluster in clusters) {
      var lat = cluster['latitude'] as double;
      var lng = cluster['longitude'] as double;
      var position = LatLng(lat, lng);

      if (cluster['cluster_name'].isEmpty) {
        // cluster_name 为空时，存储到本地
        pendingGpsList.add(position);
      } else {
        // cluster_name 不为空时，绘制四边形
        var polygon = Polygon(
          points: _createPolygonPoints(position),
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue.withOpacity(0.5),
          strokeWidth: 1,
        );
        polygonsss.add(polygon);
        print("绘制四边形：$position");
      }
    }
    // 保存 pendingGpsList 到 SharedPreferences
    if (pendingGpsList.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<Map<String, double>> pendingGpsJson = pendingGpsList
          .map((item) => {'latitude': item.latitude, 'longitude': item.longitude})
          .toList();
      await prefs.setString('pending_gps', jsonEncode(pendingGpsJson));
    }
  }
}


List<LatLng> _createPolygonPoints(LatLng center) {
  const double distance = 0.001; // 约100米，具体数值根据实际情况调整
  return [
    LatLng(center.latitude + distance, center.longitude + distance),
    LatLng(center.latitude + distance, center.longitude - distance),
    LatLng(center.latitude - distance, center.longitude - distance),
    LatLng(center.latitude - distance, center.longitude + distance),
  ];
}

Future<void> saveLabel(LatLng position, String label) async {
  String accessToken = await getAccessToken();

  var url = Uri.parse('http://gps.primedigitaltech.com:8000/api/updateLabel/');
  var response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'longitude': position.longitude,
      'latitude': position.latitude,
      'label': label,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to save label');
  }
}

class GpsObservationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Map Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapPage(),
    );
  }
}

class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map"),
      ),
      body: MapView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DataObservationPage()),
          );
        },
        tooltip: '返回',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}

class ConstConfig {
  static const AMapApiKey amapApiKeys = AMapApiKey(
    androidKey: 'd33074d34e5524ed087ce820363a1779',
  );
  static const AMapPrivacyStatement amapPrivacyStatement =
      AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true);
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  List<Widget> _approvalNumberWidget = [];
  AMapWidget? map;
  final Map<String, Marker> _initMarkerMap = <String, Marker>{};
  List<LatLng> _pendingGpsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGPSDataAndSetMarkers();
      _loadPendingGPSData();
      _fetchClusterDataAndSetPolygons();
    });
  }

  Future<void> _fetchGPSDataAndSetMarkers() async {
    await fetchGPSData(_initMarkerMap);
    setState(() {
      map = AMapWidget(
        apiKey: ConstConfig.amapApiKeys,
        onMapCreated: onMapCreated,
        privacyStatement: ConstConfig.amapPrivacyStatement,
        markers: Set<Marker>.of(_initMarkerMap.values),
        polygons: Set<Polygon>.of(polygonsss),
        onTap: (LatLng position) {
          _handleFinishMapTap(position);
        },
      );
    });
  }

  Future<void> _fetchClusterDataAndSetPolygons() async {
    await fetchClusterData(context); 
    setState(() {
      map = AMapWidget(
        apiKey: ConstConfig.amapApiKeys,
        onMapCreated: onMapCreated,
        privacyStatement: ConstConfig.amapPrivacyStatement,
        markers: Set<Marker>.of(_initMarkerMap.values),
        polygons: Set<Polygon>.of(polygonsss),
        onTap: (LatLng position) {
          _handleFinishMapTap(position);
        },
      );
    });
  }

  Future<void> _loadPendingGPSData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pendingGpsJson = prefs.getString('pending_gps');
    if (pendingGpsJson != null) {
      List<dynamic> pendingGpsList = jsonDecode(pendingGpsJson);
      _pendingGpsList = pendingGpsList
          .map((item) => LatLng(item['latitude'], item['longitude']))
          .toList();
      _createPolygons();
    }
  }

void _createPolygons() {
  List<Polygon> newPolygons = [];
  // 循环待标注的 GPS 列表，创建红色多边形
  for (LatLng position in _pendingGpsList) {
    Polygon polygon = Polygon(
      points: _createPolygonPoints(position),
      fillColor: Colors.red.withOpacity(0.2),
      strokeColor: Colors.red.withOpacity(0.5),
      strokeWidth: 1,
    );
    newPolygons.add(polygon);
  }
  // 加载已经标注的多边形
  for (Polygon polygon in polygonsss) {
    
    print("polygon.fillColor: ${polygon.points}");
    if (polygon.fillColor == Colors.blue.withOpacity(0.2)) {
      newPolygons.add(polygon);
    }
  }

  setState(() {
    polygonsss = newPolygons;
    map = AMapWidget(
      apiKey: ConstConfig.amapApiKeys,
      onMapCreated: onMapCreated,
      privacyStatement: ConstConfig.amapPrivacyStatement,
      markers: Set<Marker>.of(_initMarkerMap.values),
      polygons: Set<Polygon>.of(polygonsss),
      onTap: (LatLng position) {
        _handleSaveLabelMapTap(position);
      },
    );
  });
}


  
void _handleSaveLabelMapTap(LatLng position) async {
  Polygon? targetPolygon;
  LatLng? targetPosition;

  // 查找被点击的红色多边形
  for (int i = 0; i < polygonsss.length; i++) {
    Polygon polygon = polygonsss[i];
    if (_isPointInPolygon(position, polygon.points) &&
        polygon.fillColor == Colors.red.withOpacity(0.2)) {
      targetPolygon = polygon;
      targetPosition = _pendingGpsList[i]; // 保存待删除的点
      break;
    }
  }

  if (targetPolygon == null) return;

  // 弹出输入标注信息的对话框
  String? label = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      TextEditingController _textFieldController = TextEditingController();
      return AlertDialog(
        title: Text('输入标注信息'),
        content: TextField(
          controller: _textFieldController,
          decoration: InputDecoration(hintText: "输入标签"),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('取消'),
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
            },
          ),
          TextButton(
            child: Text('确定'),
            onPressed: () {
              Navigator.of(context).pop(_textFieldController.text); // 返回输入的标签
            },
          ),
        ],
      );
    },
  );

  if (label != null && label.isNotEmpty) {
    try {
      // 上传标注信息
      await saveLabel(position, label);

      // 标注成功后，更新多边形颜色和待标注列表
      setState(() {
        // 从待标注列表中移除该点
        _pendingGpsList.remove(targetPosition);
        polygonsss.remove(targetPolygon);
        polygonsss.add(
          Polygon(
            points: targetPolygon!.points,
            fillColor: Colors.blue.withOpacity(0.2),
            strokeColor: Colors.blue.withOpacity(0.5),
            strokeWidth: 1,
          ),
        );

        // 更新 SharedPreferences 中的 pending_gps
        _updatePendingGpsInPreferences();

        // 更新地图视图
        map = AMapWidget(
          apiKey: ConstConfig.amapApiKeys,
          onMapCreated: onMapCreated,
          privacyStatement: ConstConfig.amapPrivacyStatement,
          markers: Set<Marker>.of(_initMarkerMap.values),
          polygons: Set<Polygon>.of(polygonsss),
          onTap: (LatLng position) {
            _handleSaveLabelMapTap(position);
          },
        );
      });

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标注信息保存成功')),
      );
    } catch (e) {
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标注信息保存失败: $e')),
      );
    }
  }
}


// 更新 SharedPreferences 中的 pending_gps 数据
Future<void> _updatePendingGpsInPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<Map<String, double>> pendingGpsJson = _pendingGpsList
      .map((item) => {'latitude': item.latitude, 'longitude': item.longitude})
      .toList();
  await prefs.setString('pending_gps', jsonEncode(pendingGpsJson));
}



void _handleFinishMapTap(LatLng position) {
  for (Polygon polygon in polygonsss) {
    if (_isPointInPolygon(position, polygon.points)) {
      // 检查多边形颜色是否为红色
      if (polygon.fillColor == Colors.red.withOpacity(0.2)) {
        // 红色未标注多边形，触发标注流程
        _handleSaveLabelMapTap(position);
      } else {
        // 非红色多边形，显示已完成标注的对话框
        _showClusterNameDialog(context, "此地已完成标注");
      }
      break;
    }
  }
}


  bool _isPointInPolygon(LatLng point, List<LatLng> polygonPoints) {
    int i, j = polygonPoints.length - 1;
    bool oddNodes = false;

    for (i = 0; i < polygonPoints.length; i++) {
      if (polygonPoints[i].latitude < point.latitude &&
              polygonPoints[j].latitude >= point.latitude ||
          polygonPoints[j].latitude < point.latitude &&
              polygonPoints[i].latitude >= point.latitude) {
        if (polygonPoints[i].longitude +
                (point.latitude - polygonPoints[i].latitude) /
                    (polygonPoints[j].latitude - polygonPoints[i].latitude) *
                    (polygonPoints[j].longitude - polygonPoints[i].longitude) <
            point.longitude) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }

    return oddNodes;
  }

  Future<void> _showClusterNameDialog(BuildContext context, String clusterName) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cluster Name'),
          content: Text(clusterName),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return Container(
      child: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: map,
            ),
          ],
        ),
      ),
    );
  }

  AMapController? _mapController;
  void onMapCreated(AMapController controller) {
    setState(() {
      _mapController = controller;

      // 延迟调用以确保地图控件加载完成
      Future.delayed(Duration(milliseconds: 700), () {
        _moveCamera();
      });
    });
  }

  void _moveCamera() {
    if (_initMarkerMap.isNotEmpty) {
      _mapController?.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
          _initMarkerMap.values.first.position.latitude,
          _initMarkerMap.values.first.position.longitude,
        ),
        zoom: 18,
        tilt: 30,
        bearing: 30,
      )));
    }
  }

  void getApprovalNumber() async {
    String? mapContentApprovalNumber =
        await _mapController?.getMapContentApprovalNumber();
    String? satelliteImageApprovalNumber =
        await _mapController?.getSatelliteImageApprovalNumber();
    setState(() {
      if (null != mapContentApprovalNumber) {
        _approvalNumberWidget.add(Text(mapContentApprovalNumber));
      }
      if (null != satelliteImageApprovalNumber) {
        _approvalNumberWidget.add(Text(satelliteImageApprovalNumber));
      }
    });
    print('地图审图号（普通地图）: $mapContentApprovalNumber');
    print('地图审图号（卫星地图): $satelliteImageApprovalNumber');
  }

  @override
  void dispose() {
    super.dispose();
  }
}