import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data_observation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> fetchClusterData(BuildContext context, List<Polygon> polygons) async {
  String accessToken = await getAccessToken();
  var url = Uri.parse('http://gps.primedigitaltech.com:8000/api/get_gpscluster/');
  var response = await http.get(url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
  );

  if (response.statusCode == 200) {
    List<dynamic> clusters = jsonDecode(response.body);
    for (var cluster in clusters) {
      var lat = cluster['latitude'] as double;
      var lng = cluster['longitude'] as double;
      var position = LatLng(lat, lng);
      var polygon = Polygon(
        points: _createPolygonPoints(position),
        fillColor: Colors.red.withOpacity(0.2),
        strokeColor: Colors.red.withOpacity(0.5),
        strokeWidth: 1,
      );
      polygons.add(polygon);
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
  List<Polygon> _polygons = [];
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
        polygons: Set<Polygon>.of(_polygons),
        onTap: (LatLng position) {
          _handleMapTap(position);
        },
      );
    });
  }

  Future<void> _fetchClusterDataAndSetPolygons() async {
    await fetchClusterData(context, _polygons);
    setState(() {
      map = AMapWidget(
        apiKey: ConstConfig.amapApiKeys,
        onMapCreated: onMapCreated,
        privacyStatement: ConstConfig.amapPrivacyStatement,
        markers: Set<Marker>.of(_initMarkerMap.values),
        polygons: Set<Polygon>.of(_polygons),
        onTap: (LatLng position) {
          _handleMapTap(position);
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
    for (LatLng position in _pendingGpsList) {
      Polygon polygon = Polygon(
        points: _createPolygonPoints(position),
        fillColor: Colors.blue.withOpacity(0.2),
        strokeColor: Colors.blue.withOpacity(0.5),
        strokeWidth: 1,
      );
      newPolygons.add(polygon);
    }

    setState(() {
      _polygons = newPolygons;
      map = AMapWidget(
        apiKey: ConstConfig.amapApiKeys,
        onMapCreated: onMapCreated,
        privacyStatement: ConstConfig.amapPrivacyStatement,
        markers: Set<Marker>.of(_initMarkerMap.values),
        polygons: Set<Polygon>.of(_polygons),
        onTap: (LatLng position) {
          _handleMapTap(position);
        },
      );
    });
  }

  void _handleMapTap(LatLng position) {
    for (Polygon polygon in _polygons) {
      if (_isPointInPolygon(position, polygon.points)) {
        _showClusterNameDialog(context, "此地已完成标注");
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
      Future.delayed(Duration(milliseconds: 300), () {
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
