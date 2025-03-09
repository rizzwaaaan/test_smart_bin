import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const SmartDustbinApp());
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
  final String apiUrl =
      'http://10.18.0.105:3030'; // Update with your Flask API IP

  @override
  void initState() {
    super.initState();
    connectSocket();
    fetchReports();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchReports());
  }

  /// Connect WebSocket for real-time updates
  void connectSocket() {
    socket = IO.io(apiUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) => print('Connected to WebSocket'));

    socket!.on('dustbin_alert', (data) {
      setState(() {
        alertMessage = "${data['message']} at ${data['dustbin']['location']}";
      });
      showAlert(alertMessage ?? "Alert received");
    });

    socket!.onConnectError((error) => print('Connection Error: $error'));
    socket!.onDisconnect((_) => print('Disconnected from WebSocket'));
  }

  /// Show Alert Dialog
  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Dustbin Alert"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket?.disconnect();
    super.dispose();
  }

  /// Fetch Reports from Flask API
  Future<void> fetchReports() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/api/dustbins'));

      if (response.statusCode == 200) {
        setState(() {
          reports = json.decode(response.body);
        });
      } else {
        print('Failed to load reports. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
  }

  /// Reset Dustbin Report (Mark as Completed)
  Future<void> completeReport(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/reset-dustbin'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id, "bValue": 0, "nbValue": 0}),
      );

      if (response.statusCode == 200) {
        setState(() {
          reports.removeWhere((report) => report['id'] == id);
        });
      } else {
        print('Failed to complete report. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error completing report: $e');
    }
  }

  /// Fetch Detailed Report by ID
  Future<void> fetchReportById(int id) async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/api/report/$id'));

      if (response.statusCode == 200) {
        var report = json.decode(response.body);
        showReportDialog(report);
      } else {
        print('Failed to fetch report. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching report: $e');
    }
  }

  /// Show Report Details Dialog
  void showReportDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Report Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📍 Location: ${report['location']}"),
              Text("🟢 B Value: ${report['bValue']}"),
              Text("🔴 NB Value: ${report['nbValue']}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  /// Build UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Dustbin Reports',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Smart Dustbin Reports'),
          backgroundColor: Colors.blue,
        ),
        body: RefreshIndicator(
          onRefresh: fetchReports,
          child: reports.isEmpty
              ? const Center(child: Text('No reports available'))
              : ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    var report = reports[index];

                    int bValue = (report['bValue'] is num)
                        ? (report['bValue'] as num).toInt()
                        : 0;
                    int nbValue = (report['nbValue'] is num)
                        ? (report['nbValue'] as num).toInt()
                        : 0;

                    bool isFull = (bValue > 85 || nbValue > 85);

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report['location'] ?? "Unknown Location",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isFull)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "Full",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "B: $bValue  | NB: $nbValue",
                              style: const TextStyle(color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () =>
                                      fetchReportById(report['id']),
                                  child: const Text('View Details'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => completeReport(report['id']),
                                  child: const Text('Completed'),
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
