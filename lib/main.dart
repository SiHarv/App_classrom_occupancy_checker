import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classroom Occupancy Checker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const ClassroomOccupancyPage(),
    );
  }
}

class ClassroomOccupancyPage extends StatefulWidget {
  const ClassroomOccupancyPage({super.key});

  @override
  State<ClassroomOccupancyPage> createState() => _ClassroomOccupancyPageState();
}

class _ClassroomOccupancyPageState extends State<ClassroomOccupancyPage> {
  List<Map<String, dynamic>> classrooms = [];
  bool isLoading = true;
  String? errorMessage;
  Timer? _refreshTimer;

  // Replace with your actual Supabase URL and anon key
  final String supabaseUrl = 'https://krrhltjxhcpqmssntuyk.supabase.co';
  final String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtycmhsdGp4aGNwcW1zc250dXlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg4Nzk1MTksImV4cCI6MjA2NDQ1NTUxOX0.w_ZGqSU433cGrnv8MKdzrtJmm-DX85IFDvOYEFtBAxg';

  @override
  void initState() {
    super.initState();
    fetchClassroomData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    // Poll for changes every 3 seconds (since we're using REST API)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchDataSilently();
      }
    });
  }

  Future<void> _fetchDataSilently() async {
    try {
      final url =
          '$supabaseUrl/rest/v1/rooms?select=room_number,status&order=room_number.asc&limit=3';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final newClassrooms = data.cast<Map<String, dynamic>>();

        // Only update if data actually changed
        if (!_areListsEqual(classrooms, newClassrooms)) {
          developer.log('Data changed, updating UI');
          setState(() {
            classrooms = newClassrooms;
            errorMessage = null;
          });

          // Show a subtle notification that data was updated
          if (mounted && classrooms.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Data updated automatically'),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
      }
    } catch (e) {
      developer.log('Silent fetch error: $e');
      // Don't show error for silent updates
    }
  }

  bool _areListsEqual(
    List<Map<String, dynamic>> list1,
    List<Map<String, dynamic>> list2,
  ) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['room_number'] != list2[i]['room_number'] ||
          list1[i]['status'] != list2[i]['status']) {
        return false;
      }
    }
    return true;
  }

  Future<void> fetchClassroomData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url =
          '$supabaseUrl/rest/v1/rooms?select=room_number,status&order=room_number.asc&limit=3';
      developer.log('Fetching data from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
        },
      );

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response headers: ${response.headers}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        developer.log('Parsed data: $data');
        developer.log('Data length: ${data.length}');

        setState(() {
          classrooms = data.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      } else {
        // Parse error response if it's JSON
        String errorDetail;
        try {
          final errorData = json.decode(response.body);
          errorDetail =
              'Status: ${response.statusCode}\n'
              'Error: ${errorData['message'] ?? errorData['error'] ?? response.body}';
        } catch (_) {
          errorDetail =
              'Status: ${response.statusCode}\nResponse: ${response.body}';
        }

        if (response.statusCode == 404) {
          errorDetail +=
              '\n\nTable "rooms" not found.\nPlease check if the table exists in your Supabase database.';
        } else if (response.statusCode == 401) {
          errorDetail +=
              '\n\nAuthentication failed.\nPlease check your Supabase credentials.';
        } else if (response.statusCode == 406) {
          errorDetail +=
              '\n\nRow Level Security might be blocking access.\nCheck your RLS policies.';
        }

        throw Exception(errorDetail);
      }
    } catch (e) {
      developer.log('Full error: $e');
      String friendlyError = e.toString();

      // Remove "Exception: " prefix if present
      if (friendlyError.startsWith('Exception: ')) {
        friendlyError = friendlyError.substring(11);
      }

      setState(() {
        isLoading = false;
        errorMessage = friendlyError;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $friendlyError'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String getDisplayStatus(String status) {
    return status.toLowerCase() == 'occupied' ? 'Occupied' : 'Not Occupied';
  }

  Color getStatusColor(String status) {
    return status.toLowerCase() == 'occupied' ? Colors.red : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Classroom Occupancy Checker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchClassroomData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Classroom Status',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Error Details:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchClassroomData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (classrooms.isEmpty)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 48),
                    const SizedBox(height: 16),
                    const Text('No classroom data found'),
                    const SizedBox(height: 8),
                    const Text(
                      'Make sure you have data in your Supabase table',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchClassroomData,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Table(
                      border: TableBorder.all(color: Colors.grey),
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Colors.grey),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text(
                                'Room Number',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        ...classrooms.map((classroom) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  classroom['room_number'].toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: getStatusColor(classroom['status']),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    getDisplayStatus(classroom['status']),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
