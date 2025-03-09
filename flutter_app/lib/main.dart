import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(SmartDustbinApp());
}

class SmartDustbinApp extends StatefulWidget {
  const SmartDustbinApp({Key? key}) : super(key: key);

  @override
  _SmartDustbinAppState createState() => _SmartDustbinAppState();
}

class _SmartDustbinAppState extends State<SmartDustbinApp> {
  List<dynamic> reports = [];
  Timer? _timer;
  IO.Socket? socket;
  String? alertMessage;

  @override
  void initState() {
    super.initState();
    connectSocket();
    fetchReports();
    _timer =
        Timer.periodic(const Duration(seconds: 5), (timer) => fetchReports());
  }

  void connectSocket() {
    // Connect to your Flask-SocketIO backend
    socket = IO.io('http://10.18.0.105:5050', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();
    socket!.onConnect((_) {
      print('Connected to WebSocket server');
    });
    socket!.on('dustbin_alert', (data) {
      print('Alert received: $data');
      setState(() {
        alertMessage = data['message'] + " at " + data['dustbin']['location'];
      });
      // Optionally, show a dialog alert:
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Dustbin Alert"),
            content: Text(alertMessage ?? "Alert received"),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Close"))
            ],
          );
        },
      );
    });
    socket!.onConnectError((error) => print('Connection Error: $error'));
    socket!.onDisconnect((_) => print('Disconnected from WebSocket'));
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket?.disconnect();
    super.dispose();
  }

  Future<void> fetchReports() async {
    final response =
        await http.get(Uri.parse('http://10.18.0.105:5050/api/dustbins'));
    if (response.statusCode == 200) {
      setState(() {
        reports = json.decode(response.body);
      });
    } else {
      print('Failed to load reports');
    }
  }

  Future<void> completeReport(int id) async {
    final response = await http.post(
      Uri.parse('http://10.18.0.105:5050/api/reset-dustbin'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"id": id, "bValue": 0, "nbValue": 0}),
    );
    if (response.statusCode == 200) {
      setState(() {
        reports.removeWhere((report) => report['id'] == id);
      });
    } else {
      print('Failed to complete report');
    }
  }

  Future<void> fetchReportById(int id) async {
    final response = await http.get(
      Uri.parse('http://10.18.0.105:5050/api/report/$id'),
    );
    if (response.statusCode == 200) {
      var report = json.decode(response.body);
      showReportDialog(report);
    } else {
      print('Failed to fetch report');
    }
  }

  void showReportDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Report Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Location: ${report['location']}"),
              Text("B Value: ${report['bValue']}"),
              Text("NB Value: ${report['nbValue']}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Dustbin Reports',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Smart Dustbin Reports'),
        ),
        body: RefreshIndicator(
          onRefresh: fetchReports,
          child: reports.isEmpty
              ? Center(child: Text('No reports available'))
              : ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    var report = reports[index];
                    bool isFull =
                        (report['bValue'] > 85 || report['nbValue'] > 85);
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report['location'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isFull)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Full",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  TextSpan(
                                    text: "B: ${report['bValue']}  ",
                                    style: TextStyle(color: Colors.green),
                                  ),
                                  TextSpan(
                                    text: "| NB: ${report['nbValue']}",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue),
                                  onPressed: () =>
                                      fetchReportById(report['id']),
                                  child: Text('View Details'),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  onPressed: () => completeReport(report['id']),
                                  child: Text('Completed'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
