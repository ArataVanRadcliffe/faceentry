// screens/pages/leave_screen.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Import for date formatting

import '../../services/api_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  String? _currentUserId;
  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaveHistory = [];

  final List<String> _leaveTypes = [
    'Cuti Tahunan',
    'Cuti Sakit',
    'Cuti Pribadi',
    'Cuti Melahirkan/Paternity',
    'Cuti Tanpa Bayaran',
    'Cuti Khusus (Mis. Pernikahan, Kematian)',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserIdAndLeaveHistory();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndLeaveHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('uid');
      print('DEBUG (LeaveScreen): UID retrieved from SharedPreferences: $_currentUserId');

      if (_currentUserId == null) {
        Fluttertoast.showToast(msg: 'Gagal mendapatkan UID pengguna. Silakan login ulang.');
        if (mounted) Navigator.pop(context); // Kembali ke halaman sebelumnya jika UID tidak ada
        return;
      }

      await _fetchLeaveHistory();
    } catch (e) {
      print('DEBUG ERROR (LeaveScreen): Error loading user ID or initial history: $e');
      Fluttertoast.showToast(msg: 'Gagal memuat data cuti: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchLeaveHistory() async {
    try {
      if (_currentUserId == null) return;
      final history = await ApiService.getLeaveHistory(uid: _currentUserId);
      setState(() {
        _leaveHistory = history;
      });
      print('DEBUG (LeaveScreen): Leave history fetched: ${_leaveHistory.length} entries.');
    } catch (e) {
      print('DEBUG ERROR (LeaveScreen): Error fetching leave history: $e');
      Fluttertoast.showToast(msg: 'Gagal mengambil riwayat cuti: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Bisa diajukan 1 tahun ke belakang
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // Bisa diajukan 2 tahun ke depan
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _startDate!.isAfter(_endDate!)) {
            _endDate = _startDate; // Sesuaikan end date jika start date lebih maju
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _endDate!.isBefore(_startDate!)) {
            _startDate = _endDate; // Sesuaikan start date jika end date lebih mundur
          }
        }
      });
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLeaveType == null) {
      Fluttertoast.showToast(msg: 'Silakan pilih jenis cuti.');
      return;
    }
    if (_startDate == null) {
      Fluttertoast.showToast(msg: 'Silakan pilih tanggal mulai cuti.');
      return;
    }
    if (_endDate == null) {
      Fluttertoast.showToast(msg: 'Silakan pilih tanggal akhir cuti.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.applyLeave(
        uid: _currentUserId!,
        leaveType: _selectedLeaveType!,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        reason: _reasonController.text.trim(),
      );

      Fluttertoast.showToast(
        msg: 'Permohonan cuti berhasil diajukan!',
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );

      // Reset form dan muat ulang riwayat
      _formKey.currentState!.reset();
      setState(() {
        _reasonController.clear();
        _selectedLeaveType = null;
        _startDate = null;
        _endDate = null;
      });
      await _fetchLeaveHistory();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Gagal mengajukan cuti: ${e.toString().split(':')[1].trim()}',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      print('DEBUG ERROR (LeaveScreen): Error submitting leave: $e');
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
          'AJUKAN CUTI',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUserIdAndLeaveHistory,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(), // Untuk memastikan RefreshIndicator bekerja
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Formulir Pengajuan Cuti',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedLeaveType,
                          decoration: InputDecoration(
                            labelText: 'Jenis Cuti',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.category),
                          ),
                          items: _leaveTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLeaveType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Jenis cuti wajib dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, true),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Tanggal Mulai',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.calendar_today),
                                  ),
                                  child: Text(
                                    _startDate == null
                                        ? 'Pilih Tanggal'
                                        : DateFormat('dd-MM-yyyy').format(_startDate!),
                                    style: TextStyle(
                                      color: _startDate == null ? Colors.grey[700] : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, false),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Tanggal Akhir',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.calendar_today),
                                  ),
                                  child: Text(
                                    _endDate == null
                                        ? 'Pilih Tanggal'
                                        : DateFormat('dd-MM-yyyy').format(_endDate!),
                                    style: TextStyle(
                                      color: _endDate == null ? Colors.grey[700] : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _reasonController,
                          decoration: InputDecoration(
                            labelText: 'Alasan Cuti',
                            hintText: 'Misalnya: Keperluan keluarga, sakit, dll.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.description),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Alasan cuti wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitLeaveApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.send),
                            label: Text(
                              _isLoading ? 'MENGIRIM...' : 'AJUKAN CUTI',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Riwayat Pengajuan Cuti',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
              const SizedBox(height: 10),
              _leaveHistory.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    'Belum ada riwayat pengajuan cuti.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _leaveHistory.length,
                itemBuilder: (context, index) {
                  final leave = _leaveHistory[index];
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Jenis Cuti: ',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Text(
                                  '${leave['leave_type']}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Periode: $startDate s/d $endDate',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alasan: ',
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                              Expanded(
                                child: Text(
                                  '${leave['reason']}',
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  softWrap: true,
                                ),
                              ),
                            ],
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
                          if (leave['status'] != 'Pending' && leave['approved_by'] != null) ...[
                            const SizedBox(height: 4),
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
            ],
          ),
        ),
      ),
    );
  }
}