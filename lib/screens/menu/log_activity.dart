import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class LogActivityPage extends StatefulWidget {
  const LogActivityPage({super.key});

  @override
  State<LogActivityPage> createState() => _LogActivityPageState();
}

class _LogActivityPageState extends State<LogActivityPage> {
  List<Map<String, dynamic>> _logHistory = [];
  bool _isLoading = true;
  String? _currentUserId;

  Map<String, List<Map<String, dynamic>>> _groupedLogs = {};

  @override
  void initState() {
    super.initState();
    _loadLogHistory();
  }

  Future<void> _loadLogHistory() async {
    setState(() {
      _isLoading = true;
    });
    print('DEBUG (LogActivity): _loadLogHistory called.');

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('uid');
      print('DEBUG (LogActivity): UID retrieved from SharedPreferences: $_currentUserId');

      List<Map<String, dynamic>> fetchedLogs;
      if (_currentUserId != null) {
        fetchedLogs = await ApiService.getCheckInOutHistory(uid: _currentUserId);
        print('DEBUG (LogActivity): Fetched logs for UID $_currentUserId: ${fetchedLogs.length} entries');
        print('DEBUG (LogActivity): Raw fetchedLogs data: $fetchedLogs');
      } else {
        fetchedLogs = [];
        print('DEBUG (LogActivity): No UID found in SharedPreferences, cannot fetch specific user logs.');
      }

      _groupedLogs = {};
      for (var log in fetchedLogs) {
        try {
          final DateTime dateTime = DateTime.parse(log['timestamp']);
          final String dateOnly = DateFormat('yyyy-MM-dd').format(dateTime.toLocal());

          if (!_groupedLogs.containsKey(dateOnly)) {
            _groupedLogs[dateOnly] = [];
          }
          _groupedLogs[dateOnly]!.add(log);
        } catch (e) {
          print('DEBUG ERROR (LogActivity): Error parsing timestamp for log: $log - $e');
        }
      }

      final sortedDates = _groupedLogs.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      _logHistory = []; // Ini tidak lagi digunakan untuk membangun tampilan langsung
      for (var date in sortedDates) {
        _groupedLogs[date]!.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
        // _logHistory.addAll(_groupedLogs[date]!); // Tidak perlu ditambahkan ke _logHistory lagi
      }
      print('DEBUG (LogActivity): Grouped and sorted logs. Total groups: ${_groupedLogs.length}');


      setState(() {
        _isLoading = false;
      });
      print('DEBUG (LogActivity): Loading finished. _isLoading set to false.');

    } catch (e) {
      print('DEBUG ERROR (LogActivity): Failed to load log history: $e');
      setState(() {
        _isLoading = false;
        _logHistory = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat riwayat log: $e')),
      );
    }
  }

  String _formatTimestampToDate(String timestampString) {
    try {
      final DateTime dateTime = DateTime.parse(timestampString);
      return DateFormat('dd MMMM yyyy').format(dateTime.toLocal());
    } catch (e) {
      return 'Tanggal Tidak Valid';
    }
  }

  String _formatTimestampToTime(String timestampString) {
    try {
      final DateTime dateTime = DateTime.parse(timestampString);
      return DateFormat('HH:mm').format(dateTime.toLocal());
    } catch (e) {
      return 'Jam Tidak Valid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOG STATUS'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedLogs.isEmpty
          ? Center(
        child: Text(
          _currentUserId != null
              ? 'Belum ada riwayat check-in/out untuk Anda.'
              : 'Silakan login untuk melihat riwayat log.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Riwayat Presensi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _groupedLogs.keys.length,
              itemBuilder: (context, dateIndex) {
                final String date = _groupedLogs.keys.toList().elementAt(dateIndex);
                final List<Map<String, dynamic>> logsForDate = _groupedLogs[date]!;

                // --- PERBAIKAN DI SINI: Sertakan 'success_scan' untuk check_out ---
                final checkInLogs = logsForDate.where(
                        (log) => log['event_type'].toLowerCase() == 'check_in' && log['status']?.toLowerCase() == 'success'
                ).toList();
                final checkOutLogs = logsForDate.where(
                        (log) => log['event_type'].toLowerCase() == 'check_out' && (log['status']?.toLowerCase() == 'success' || log['status']?.toLowerCase() == 'success_scan') // <<< MODIFIKASI INI
                ).toList();
                // --- AKHIR PERBAIKAN ---

                if (checkInLogs.isEmpty && checkOutLogs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final checkInLog = checkInLogs.isNotEmpty ? checkInLogs.first : null;
                final checkOutLog = checkOutLogs.isNotEmpty ? checkOutLogs.first : null;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (checkInLog != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BERHASIL CHECK-IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'tanggal ${_formatTimestampToDate(checkInLog['timestamp'])} - ${_formatTimestampToTime(checkInLog['timestamp'])}',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),

                        if (checkInLog != null && checkOutLog != null)
                          const SizedBox(height: 10),

                        if (checkOutLog != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BERHASIL CHECK-OUT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'tanggal ${_formatTimestampToDate(checkOutLog['timestamp'])} - ${_formatTimestampToTime(checkOutLog['timestamp'])}',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
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
        ],
      ),
    );
  }
}