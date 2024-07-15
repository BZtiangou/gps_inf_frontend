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
      // 请求成功，处理数据
      var jsonData = jsonDecode(response.body);
      // 清除旧的标记
      initMarkerMap.clear();

      // 从jsonData中获取位置数组
      List<dynamic> locations = jsonData['Locations'];
      for (var location in locations) {
        // 创建点坐标
        var lat = location['latitude'] as double;
        var lng = location['longitude'] as double;
        var position = LatLng(lat, lng);
        // 创建标记并添加到_initMarkerMap
        var marker = Marker(
          position: position,
        );
        initMarkerMap[marker.id] = marker;
      }
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
      appBar: AppBar(title: const Text("Map"),),
      body: MapView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 返回到上一级页面
          Navigator.push(context,MaterialPageRoute(builder: (context) => DataObservationPage()),);
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
  ///增设隐私相关设置
  static const AMapPrivacyStatement amapPrivacyStatement =
  AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true);
}
 
class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}
 
class _MapViewState extends State<MapView> {
  // 后面地图审批号要用
  List<Widget> _approvalNumberWidget = [];
  AMapWidget? map;
  final Map<String, Marker> _initMarkerMap = <String, Marker>{};
  @override
  void initState() {
    super.initState();
    super.initState();
    // 使用异步函数获取 GPS 数据，并等待完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGPSDataAndSetMarkers();
    });
  }
    Future<void> _fetchGPSDataAndSetMarkers() async {
    // 等待 fetchGPSData 完成，并获取更新后的标记点
    await fetchGPSData(_initMarkerMap);
    // 更新 UI
    setState(() {
      // 确保在修改了 _initMarkerMap 后设置地图
      map = AMapWidget(
        apiKey: ConstConfig.amapApiKeys,
        onMapCreated: onMapCreated,
        privacyStatement: ConstConfig.amapPrivacyStatement,
        markers: Set<Marker>.of(_initMarkerMap.values),
      );
    });
  }
 
  @override
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
 
//  地图创建后自动移动到某一个定位点
  AMapController? _mapController;
  void onMapCreated(AMapController controller) {
    setState(() {
      _mapController = controller;
      _moveCamera();
    });
  }
  // 自动移动到第一个定位点
  void _moveCamera() {
    _mapController?.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(_initMarkerMap.values.first.position.latitude,_initMarkerMap.values.first.position.longitude),
          zoom: 18,
          tilt: 30,
          bearing: 30)));
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
}