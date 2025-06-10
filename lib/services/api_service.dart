// services/api_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:async'; // Pastikan ini ada untuk TimeoutException

class ApiService {
  static const String baseUrl = 'http://faceentry.my.id'; // Sesuaikan dengan IP publik/domain Anda!

  static Future<void> registerEmployeeData({
    required String uid,
    required String name,
    required String idUser,
    required String role,
    required String email,
    required String password,
    String? tanggalLahir,
    int? usia,
    String? alamat,
    String? jabatan,
    Uint8List? faceImageBytes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/register/profile-data');

      String? base64Image;
      if (faceImageBytes != null) {
        base64Image = base64Encode(faceImageBytes);
        if (base64Image.startsWith('data:image')) {
          base64Image = base64Image.substring(base64Image.indexOf(',') + 1);
        }
      }

      final body = jsonEncode({
        'uid': uid,
        'nama_pengguna': name,
        'id_pegawai': idUser,
        'jabatan': jabatan ?? role,
        'tanggal_lahir': tanggalLahir,
        'usia': usia,
        'alamat': alamat,
        'email': email,
        'password': password,
        'face_image': base64Image,
      });

      print('Sending full employee data for UID: $uid');
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        print('Employee data and face image registered successfully: ${response.body}');
      } else {
        print('Failed to register employee data and face image: ${response.statusCode} ${response.body}');
        throw Exception('Failed to register employee data and face image: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on registerEmployeeData: Request timed out. $e');
      throw Exception('Request to backend timed out during registration. Please check network or server response time.');
    } catch (e) {
      print('Exception on registerEmployeeData (full data): $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> detectFaceOnBackend(Uint8List imageData) async {
    try {
      final uri = Uri.parse('$baseUrl/detect-face');
      String base64Image = base64Encode(imageData);

      if (base64Image.startsWith('data:image')) {
        base64Image = base64Image.substring(base64Image.indexOf(',') + 1);
      }
      print('Sending image for backend face detection.');

      final body = jsonEncode({'image': base64Image});
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to detect face on backend: ${response.statusCode} ${response.body}');
        throw Exception('Failed to detect face on backend: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on detectFaceOnBackend: Request timed out. $e');
      throw Exception('Request to backend timed out during face detection. Please check network or server response time.');
    } catch (e) {
      print('Exception on detectFaceOnBackend: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyFace(Uint8List imageData, {String? uid}) async {
    try {
      final uri = Uri.parse('$baseUrl/verify-face');
      String base64Image = base64Encode(imageData);

      if (base64Image.startsWith('data:image')) {
        base64Image = base64Image.substring(base64Image.indexOf(',') + 1);
      }
      print('Sending image for backend face verification. UID: $uid');

      final Map<String, dynamic> bodyData = {'image': base64Image};
      if (uid != null) {
        bodyData['uid'] = uid;
      }

      final body = jsonEncode(bodyData);
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        print('DEBUG (ApiService): Raw response body for verifyFace: ${response.body}');
        return jsonDecode(response.body);
      } else {
        print('Failed to verify face on backend: ${response.statusCode} ${response.body}');
        throw Exception('Failed to verify face on backend: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on verifyFace: Request timed out. $e');
      throw Exception('Request to backend timed out during face verification. Please check network or server response time.');
    } catch (e) {
      print('Exception on verifyFace: $e');
      rethrow;
    }
  }

  static Future<void> sendDebugImage(Uint8List imageData, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/debug-image');
      String base64Image = base64Encode(imageData);

      if (base64Image.startsWith('data:image')) {
        base64Image = base64Image.substring(base64Image.indexOf(',') + 1);
      }
      print('Sending debug image: $filename');

      final body = jsonEncode({'image': base64Image, 'filename': filename});
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('Debug image saved successfully: ${response.body}');
      } else {
        print('Failed to save debug image: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('Exception on sendDebugImage: Request timed out. $e');
    } catch (e) {
      print('Exception on sendDebugImage: $e');
    }
  }

  static Future<Map<String, dynamic>?> getEmployeeData(String uid) async {
    try {
      final uri = Uri.parse('$baseUrl/employee/$uid');
      final response = await http.get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        print('Failed to fetch employee data: ${response.statusCode} ${response.body}');
        throw Exception('Failed to fetch employee data: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on getEmployeeData: Request timed out. $e');
      throw Exception('Request to backend timed out during employee data fetch. Please check network or server response time.');
    } catch (e) {
      print('Exception on getEmployeeData: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getEmployeeDetailsFromPostgres(String uid) async {
    try {
      final uri = Uri.parse('$baseUrl/employee/$uid');
      print('Fetching employee data from PostgreSQL for UID: $uid');
      final response = await http.get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        print('Employee not found in PostgreSQL for UID: $uid');
        return null;
      } else {
        print('Failed to fetch employee data from PostgreSQL: ${response.statusCode} ${response.body}');
        throw Exception('Failed to fetch employee data from PostgreSQL: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on getEmployeeDetailsFromPostgres: Request timed out. $e');
      throw Exception('Request to backend timed out during employee details fetch. Please check network or server response time.');
    } catch (e) {
      print('Exception on getEmployeeDetailsFromPostgres: $e');
      rethrow;
    }
  }

  // --- METODE BARU: Menambahkan Log Check-In/Check-Out ke PostgreSQL ---
  static Future<void> addCheckInOutLog({
    required String uid,
    required String eventType,
    required String status,
    String? employeeName,
    double? distance,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/check-in-out-log');
      final body = jsonEncode({
        'uid': uid,
        'event_type': eventType,
        'status': status,
        'employee_name': employeeName,
        'distance': distance,
      });

      print('Sending check-in/out log for UID: $uid, Event: $eventType, Status: $status');
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('Check-in/out log added successfully: ${response.body}');
      } else {
        print('Failed to add check-in/out log: ${response.statusCode} ${response.body}');
        throw Exception('Failed to add check-in/out log: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on addCheckInOutLog: Request timed out. $e');
      throw Exception('Request to backend timed out during logging. Please check network or server response time.');
    } catch (e) {
      print('Exception on addCheckInOutLog: $e');
      rethrow;
    }
  }

  // --- METODE BARU: Mengambil Riwayat Log Check-In/Check-Out dari PostgreSQL ---
  static Future<List<Map<String, dynamic>>> getCheckInOutHistory({String? uid}) async {
    try {
      final uri = uid != null
          ? Uri.parse('$baseUrl/check-in-out-history/$uid')
          : Uri.parse('$baseUrl/check-in-out-history');

      print('Fetching check-in/out history for UID: ${uid ?? "all"}');
      final response = await http.get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> responseBody = jsonDecode(response.body);
        return responseBody.cast<Map<String, dynamic>>();
      } else {
        print('Failed to fetch check-in/out history: ${response.statusCode} ${response.body}');
        throw Exception('Failed to fetch check-in/out history: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on getCheckInOutHistory: Request timed out. $e');
      throw Exception('Request to backend timed out during history fetch. Please check network or server response time.');
    } catch (e) {
      print('Exception on getCheckInOutHistory: $e');
      rethrow;
    }
  }

  // --- METODE BARU: Mengunggah Foto Profil ---
  static Future<void> uploadProfilePhoto({
    required String uid,
    required Uint8List fileBytes,
    required String filename,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/upload_profile_photo/$uid');

      // Menggunakan multipart/form-data untuk upload file
      var request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'file', // Nama field harus 'file' sesuai endpoint Flask
          fileBytes,
          filename: filename,
        ));

      print('Sending profile photo for UID: $uid, filename: $filename');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30)); // Timeout untuk upload
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('Profile photo uploaded successfully: ${response.body}');
      } else {
        print('Failed to upload profile photo: ${response.statusCode} ${response.body}');
        throw Exception('Failed to upload profile photo: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on uploadProfilePhoto: Request timed out. $e');
      throw Exception('Request to backend timed out during profile photo upload. Please check network or server response time.');
    } catch (e) {
      print('Exception on uploadProfilePhoto: $e');
      rethrow;
    }
  }

  // --- METODE BARU UNTUK FITUR CUTI ---

  static Future<void> applyLeave({
    required String uid,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/leave');
      final body = jsonEncode({
        'uid': uid,
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
      });

      print('Sending leave application for UID: $uid, Type: $leaveType');
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        print('Leave application submitted successfully: ${response.body}');
      } else {
        print('Failed to submit leave application: ${response.statusCode} ${response.body}');
        throw Exception('Failed to submit leave application: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on applyLeave: Request timed out. $e');
      throw Exception('Request to backend timed out during leave application. Please check network or server response time.');
    } catch (e) {
      print('Exception on applyLeave: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getLeaveHistory({String? uid}) async {
    try {
      final uri = uid != null
          ? Uri.parse('$baseUrl/leaves/$uid')
          : Uri.parse('$baseUrl/leaves');

      print('Fetching leave history for UID: ${uid ?? "all"}');
      final response = await http.get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> responseBody = jsonDecode(response.body);
        return responseBody.cast<Map<String, dynamic>>();
      } else {
        print('Failed to fetch leave history: ${response.statusCode} ${response.body}');
        throw Exception('Failed to fetch leave history: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on getLeaveHistory: Request timed out. $e');
      throw Exception('Request to backend timed out during leave history fetch. Please check network or server response time.');
    } catch (e) {
      print('Exception on getLeaveHistory: $e');
      rethrow;
    }
  }

  static Future<void> updateLeaveStatus({
    required int leaveId,
    required String status,
    required String approvedByUid, // UID admin yang menyetujui/menolak
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/leave/$leaveId/status');
      final body = jsonEncode({
        'status': status,
        'approved_by_uid': approvedByUid,
      });

      print('Updating leave status for ID: $leaveId to $status by $approvedByUid');
      final response = await http.put(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('Leave status updated successfully: ${response.body}');
      } else {
        print('Failed to update leave status: ${response.statusCode} ${response.body}');
        throw Exception('Failed to update leave status: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Exception on updateLeaveStatus: Request timed out. $e');
      throw Exception('Request to backend timed out during leave status update. Please check network or server response time.');
    } catch (e) {
      print('Exception on updateLeaveStatus: $e');
      rethrow;
    }
  }
}