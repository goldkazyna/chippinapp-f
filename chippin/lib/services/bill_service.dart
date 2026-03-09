import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/bill.dart';
import '../models/bill_adjustment.dart';
import '../models/participant.dart';
import '../models/bill_item.dart';
import 'api_client.dart';

class BillService {
  final ApiClient _apiClient;

  BillService(this._apiClient);

  // ── Bills ──────────────────────────────────────────────────────────────

  /// GET /api/bills
  Future<List<Bill>> getBills() async {
    final response = await _apiClient.dio.get('/bills');
    final List<dynamic> data = response.data['data'];
    return data
        .map((json) => Bill.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/bills/{id}
  Future<Bill> getBill(int id) async {
    final response = await _apiClient.dio.get('/bills/$id');
    return Bill.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// POST /api/bills
  Future<Bill> createBill({
    required String name,
    required String date,
    required String currency,
  }) async {
    final response = await _apiClient.dio.post('/bills', data: {
      'name': name,
      'date': date,
      'currency': currency,
    });
    return Bill.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// DELETE /api/bills/{id}
  Future<void> deleteBill(int id) async {
    await _apiClient.dio.delete('/bills/$id');
  }

  // ── Participants ───────────────────────────────────────────────────────

  /// POST /api/bills/{billId}/participants
  Future<Participant> addParticipant(int billId, String name) async {
    final response = await _apiClient.dio.post(
      '/bills/$billId/participants',
      data: {'name': name},
    );
    return Participant.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  /// DELETE /api/bills/{billId}/participants/{participantId}
  Future<void> removeParticipant(int billId, int participantId) async {
    await _apiClient.dio.delete(
      '/bills/$billId/participants/$participantId',
    );
  }

  // ── Items ──────────────────────────────────────────────────────────────

  /// POST /api/bills/{billId}/items
  Future<BillItem> addItem(
    int billId, {
    required String name,
    required int quantity,
    required double pricePerUnit,
  }) async {
    final response = await _apiClient.dio.post(
      '/bills/$billId/items',
      data: {
        'name': name,
        'quantity': quantity,
        'price_per_unit': pricePerUnit,
      },
    );
    return BillItem.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// PUT /api/bills/{billId}/items/{itemId}
  Future<BillItem> updateItem(
    int billId,
    int itemId, {
    String? name,
    int? quantity,
    double? pricePerUnit,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (quantity != null) body['quantity'] = quantity;
    if (pricePerUnit != null) body['price_per_unit'] = pricePerUnit;
    final response = await _apiClient.dio.put(
      '/bills/$billId/items/$itemId',
      data: body,
    );
    return BillItem.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// DELETE /api/bills/{billId}/items/{itemId}
  Future<void> deleteItem(int billId, int itemId) async {
    await _apiClient.dio.delete('/bills/$billId/items/$itemId');
  }

  /// POST /api/bills/{billId}/items/bulk
  Future<List<BillItem>> addItemsBulk(
    int billId,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _apiClient.dio.post(
      '/bills/$billId/items/bulk',
      data: {'items': items},
    );
    final List<dynamic> data = response.data['data'];
    return data
        .map((json) => BillItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ── Scan Receipt ───────────────────────────────────────────────────────

  /// POST /api/bills/{billId}/scan-receipt (multipart)
  Future<List<Map<String, dynamic>>> scanReceipt(
    int billId,
    String filePath, {
    String lang = 'en',
  }) async {
    final fileName = filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath, filename: fileName,
          contentType: MediaType.parse(mimeType)),
      'lang': lang,
    });
    final response = await _apiClient.dio.post(
      '/bills/$billId/scan-receipt',
      data: formData,
    );
    final List<dynamic> items = response.data['data']['items'];
    return items.cast<Map<String, dynamic>>();
  }

  // ── Parse Voice ──────────────────────────────────────────────────────

  /// POST /api/bills/{billId}/parse-voice (multipart)
  Future<List<Map<String, dynamic>>> parseVoice(
    int billId,
    String filePath, {
    String lang = 'en',
  }) async {
    final fileName = filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'webm' => 'audio/webm',
      _ => 'audio/mp4',
    };
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(filePath, filename: fileName,
          contentType: MediaType.parse(mimeType)),
      'lang': lang,
    });
    final response = await _apiClient.dio.post(
      '/bills/$billId/parse-voice',
      data: formData,
    );
    final List<dynamic> items = response.data['data']['items'];
    return items.cast<Map<String, dynamic>>();
  }

  // ── Adjustments ──────────────────────────────────────────────────────

  /// POST /api/bills/{billId}/adjustments
  Future<void> syncAdjustments(int billId, List<BillAdjustment> adjustments) async {
    await _apiClient.dio.post('/bills/$billId/adjustments', data: {
      'adjustments': adjustments.map((a) => a.toJson()).toList(),
    });
  }

  // ── Splitting ──────────────────────────────────────────────────────────

  /// POST /api/bills/{billId}/items/{itemId}/split — equal
  Future<Map<String, dynamic>> splitEqual(int billId, int itemId) async {
    final response = await _apiClient.dio.post(
      '/bills/$billId/items/$itemId/split',
      data: {'type': 'equal'},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// POST /api/bills/{billId}/items/{itemId}/split — custom
  Future<Map<String, dynamic>> splitCustom(
    int billId,
    int itemId,
    List<Map<String, dynamic>> splits,
  ) async {
    final response = await _apiClient.dio.post(
      '/bills/$billId/items/$itemId/split',
      data: {
        'type': 'custom',
        'splits': splits,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  // ── Payment ────────────────────────────────────────────────────────────

  /// PUT /api/bills/{billId}/paid-by
  Future<void> setPaidBy(int billId, int participantId) async {
    await _apiClient.dio.put(
      '/bills/$billId/paid-by',
      data: {'participant_id': participantId},
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────

  /// GET /api/bills/{billId}/summary
  Future<Map<String, dynamic>> getSummary(int billId) async {
    final response = await _apiClient.dio.get('/bills/$billId/summary');
    return response.data['data'] as Map<String, dynamic>;
  }

  // ── PDF ────────────────────────────────────────────────────────────────

  /// GET /api/bills/{billId}/pdf → binary
  Future<Uint8List> getPdf(int billId) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/bills/$billId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }
}
