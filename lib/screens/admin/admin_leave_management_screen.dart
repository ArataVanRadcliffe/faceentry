// lib/screens/admin/admin_leave_management_screen.dart
// (Asumsi lokasi file ini adalah di folder lib/screens/admin/)

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:shared_preferences/shared_preferences.dart'; // Untuk mendapatkan UID admin

// Pastikan path ke ApiService Anda sudah benar.
// Jika ApiService ada di lib/services/api_service.dart, dan file ini di lib/screens/admin/,
// maka pathnya: '../../services/api_service.dart'
import '../../services/api_service.dart';

class AdminLeaveManagementScreen extends StatefulWidget {
  const AdminLeaveManagementScreen({super.key});

  @override
  State<AdminLeaveManagementScreen> createState() => _AdminLeaveManagementScreenState();
}

class _AdminLeaveManagementScreenState extends State<AdminLeaveManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allLeaveRequests = [];
  List<Map<String, dynamic>> _filteredLeaveRequests = [];
  String _selectedFilterStatus = 'All'; // Filter default

  String? _adminUid; // Untuk menyimpan UID admin yang melakukan persetujuan/penolakan

  @override
  void initState() {
    super.initState();
    _loadAdminUidAndLeaveRequests();
  }

  Future<void> _loadAdminUidAndLeaveRequests() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _adminUid = prefs.getString('uid'); // Ambil UID admin dari SharedPreferences
      print('DEBUG (AdminLeave): Admin UID from SharedPreferences: $_adminUid');

      if (_adminUid == null) {
        Fluttertoast.showToast(msg: 'UID Admin tidak ditemukan. Silakan login ulang.');
        if (mounted) Navigator.pop(context); // Kembali jika UID admin tidak ada
        return;
      }

      await _fetchLeaveRequests();
    } catch (e) {
      print('DEBUG ERROR (AdminLeave): Error loading admin UID or leave requests: $e');
      Fluttertoast.showToast(msg: 'Gagal memuat data cuti admin: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchLeaveRequests() async {
    try {
      // Ambil semua permohonan cuti (karena ini untuk admin)
      final fetchedRequests = await ApiService.getLeaveHistory();
      setState(() {
        _allLeaveRequests = fetchedRequests;
        _applyFilter(); // Terapkan filter setelah mendapatkan semua data
      });
      print('DEBUG (AdminLeave): All leave requests fetched: ${_allLeaveRequests.length} entries.');
    } catch (e) {
      print('DEBUG ERROR (AdminLeave): Error fetching all leave requests: $e');
      Fluttertoast.showToast(msg: 'Gagal mengambil daftar permohonan cuti: $e');
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilterStatus == 'All') {
        _filteredLeaveRequests = List.from(_allLeaveRequests);
      } else {
        _filteredLeaveRequests = _allLeaveRequests
            .where((leave) => leave['status'] == _selectedFilterStatus)
            .toList();
      }
    });
  }

  Future<void> _updateLeaveStatus(int leaveId, String newStatus) async {
    if (_adminUid == null) {
      Fluttertoast.showToast(msg: 'Gagal. UID Admin tidak tersedia.');
      return;
    }

    setState(() {
      _isLoading = true; // Tampilkan loading saat update
    });

    try {
      await ApiService.updateLeaveStatus(
        leaveId: leaveId,
        status: newStatus,
        approvedByUid: _adminUid!, // Gunakan UID admin yang login
      );

      Fluttertoast.showToast(
        msg: 'Status cuti berhasil diperbarui menjadi $newStatus!',
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );
      await _fetchLeaveRequests(); // Muat ulang data setelah update
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Gagal memperbarui status cuti: ${e.toString().split(':')[1].trim()}',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      print('DEBUG ERROR (AdminLeave): Error updating leave status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MANAJEMEN CUTI (ADMIN)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchLeaveRequests,
        child: Column(
          children: [
            // Filter Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedFilterStatus,
                decoration: InputDecoration(
                  labelText: 'Filter Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.filter_list),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('Semua')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Approved', child: Text('Disetujui')),
                  DropdownMenuItem(value: 'Rejected', child: Text('Ditolak')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFilterStatus = value!;
                    _applyFilter();
                  });
                },
              ),
            ),
            Expanded(
              child: _filteredLeaveRequests.isEmpty
                  ? Center(
                child: Text(
                  'Tidak ada permohonan cuti dengan status "${_selectedFilterStatus}".',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _filteredLeaveRequests.length,
                itemBuilder: (context, index) {
                  final leave = _filteredLeaveRequests[index];
                  final String startDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(leave['start_date']));
                  final String endDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(leave['end_date']));
                  final String requestDate = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(leave['request_date']));

                  Color statusColor;
                  switch (leave['status']) {
                    case 'Approved':
                      statusColor = Colors.green;
                      break;
                    case 'Rejected':
                      statusColor = Colors.red;
                      break;
                    case 'Pending':
                    default:
                      statusColor = Colors.orange;
                      break;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pegawai UID: ${leave['uid']}', // Menampilkan UID pegawai pengaju cuti
                            style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jenis Cuti: ${leave['leave_type']}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Periode: $startDate s/d $endDate',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alasan: ${leave['reason']}',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Diajukan Pada: $requestDate',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const Divider(height: 20, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Status:',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  leave['status'],
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (leave['status'] == 'Pending') // Hanya tampilkan tombol jika status Pending
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _updateLeaveStatus(leave['id'], 'Approved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[600],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Setujui'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _updateLeaveStatus(leave['id'], 'Rejected'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[600],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Tolak'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (leave['status'] != 'Pending' && leave['approved_by'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Dikonfirmasi oleh Admin UID: ${leave['approved_by']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Pada: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(leave['approval_date']))}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}