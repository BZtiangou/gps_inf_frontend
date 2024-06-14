import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DataObservationPage extends StatefulWidget {
  @override
  _DataObservationPageState createState() => _DataObservationPageState();
}

class _DataObservationPageState extends State<DataObservationPage> {
  List<dynamic> accelerometers = [];
  List<dynamic> bluetooths = [];
  List<dynamic> locations = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      try {
        final response = await http.get(
          Uri.parse('http://gps.primedigitaltech.com:8000/api/getdata/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);
          setState(() {
            accelerometers = data['accelerometers'];
            bluetooths = data['bluetooths'];
            locations = data['locations'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Failed to load data: ${response.statusCode}';
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          errorMessage = 'Error: $e';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = 'No access token found';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Observation'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accelerometers',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ...accelerometers.map((item) => ListTile(
                            title: Text(item.toString()),
                          )),
                      Divider(),
                      Text(
                        'Bluetooths',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ...bluetooths.map((item) => ListTile(
                            title: Text(item.toString()),
                          )),
                      Divider(),
                      Text(
                        'Locations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ...locations.map((item) => ListTile(
                            title: Text(item.toString()),
                          )),
                    ],
                  ),
                ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: DataObservationPage(),
  ));
}
