// services/api_service.dart

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http_parser/http_parser.dart';
import '../models/procurement_models.dart';

class ApiService {
  static const String _prodUrl = 'https://procurement-ai-backend.azurewebsites.net/api';
  static const String _localUrl = 'http://localhost:8000/api';

  // Auto-detect: use local in debug mode, Azure in release/production
  static String get baseUrl => kDebugMode ? _localUrl : _prodUrl;

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  ApiService() {
    // Add interceptor for logging (development only)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('API: $obj'),
      ),
    );
  }

  // Helper method to handle API calls
  Future<T> _handleApiCall<T>(
    Future<Response> Function() apiCall,
    String operationName,
  ) async {
    try {
      print('Calling API: $operationName');
      final response = await apiCall();
      print('API Success: $operationName');
      return response.data as T;
    } catch (e) {
      print('API Error ($operationName): $e');
      rethrow;
    }
  }

  // ========================================
  // AI AGENTS - MICROSOFT FOUNDRY INTEGRATION
  // ========================================

  /// Run complete AI workflow (Guardian -> Forecaster -> Logistics)
  Future<Map<String, dynamic>> runAIWorkflow(Map<String, dynamic> batchData) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/run-ai-workflow', data: batchData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      ),
      'runAIWorkflow',
    );
  }

  /// Run Guardian Agent only (Quality Gatekeeper)
  Future<Map<String, dynamic>> runGuardianAgent(Map<String, dynamic> batchData) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/run-guardian', data: batchData),
      'runGuardianAgent',
    );
  }

  /// Run Forecaster Agent only (Demand Strategist)
  Future<Map<String, dynamic>> runForecasterAgent(Map<String, dynamic> guardianReport) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/run-forecaster', data: guardianReport),
      'runForecasterAgent',
    );
  }

  /// Run Logistics Agent only (Shipping Optimizer)
  Future<Map<String, dynamic>> runLogisticsAgent(Map<String, dynamic> forecasterOutput) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/run-logistics', data: forecasterOutput),
      'runLogisticsAgent',
    );
  }

  /// Run Orchestrator Agent directly
  Future<Map<String, dynamic>> runOrchestratorAgent(String userRequest) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/run-orchestrator', data: {'request': userRequest}),
      'runOrchestratorAgent',
    );
  }

  /// Check AI Agent Status
  Future<Map<String, dynamic>> checkAgentStatus() async {
    try {
      final response = await _dio.get('/agents/status');
      return response.data;
    } catch (e) {
      return {
        'status': 'unavailable',
        'error': e.toString(),
        'message': 'AI agents are currently offline'
      };
    }
  }

  /// Test AI Agents
  Future<Map<String, dynamic>> testAIAgents() async {
    return await _handleApiCall(
      () => _dio.get('/agents/test'),
      'testAIAgents',
    );
  }

  // ========================================
  // DASHBOARD DATA
  // ========================================

  /// Get Officer Dashboard Data
  Future<Map<String, dynamic>> getOfficerDashboard() async {
    return await _handleApiCall(
      () => _dio.get('/dashboard/officer'),
      'getOfficerDashboard',
    );
  }

  /// Get Approver Dashboard Data
  Future<Map<String, dynamic>> getApproverDashboard() async {
    return await _handleApiCall(
      () => _dio.get('/dashboard/approver'),
      'getApproverDashboard',
    );
  }

  // ========================================
  // UPLOAD
  // ========================================

  /// Upload Purchase Order
  Future<Map<String, dynamic>> uploadPurchaseOrder(PlatformFile file) async {
    try {
      print('Uploading file: ${file.name}');
      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await _dio.post(
        '/upload/purchase-order',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('File uploaded successfully');
      return response.data;
    } catch (e) {
      print('Upload error: $e');
      rethrow;
    }
  }

  /// Upload Xeersoft Inventory Data (Excel with multi-channel stock + sales history)
  Future<Map<String, dynamic>> uploadXeersoftInventory(PlatformFile file) async {
    try {
      print('Uploading Xeersoft inventory: ${file.name} (${file.size} bytes)');
      final ext = file.extension?.toLowerCase() ?? '';
      final contentType = (ext == 'xlsx' || ext == 'xls')
          ? MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet')
          : MediaType('text', 'csv');
      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType: contentType,
        ),
      });

      final response = await _dio.post(
        '/upload/xeersoft-inventory',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      print('Xeersoft inventory uploaded successfully');
      return response.data;
    } catch (e) {
      print('Xeersoft upload error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadSupplierMaster(PlatformFile file) async {
    try {
      print('Uploading supplier & item master: ${file.name} (${file.size} bytes)');
      final ext = file.extension?.toLowerCase() ?? '';
      final contentType = (ext == 'xlsx' || ext == 'xls')
          ? MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet')
          : MediaType('text', 'csv');
      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType: contentType,
        ),
      });

      final response = await _dio.post(
        '/upload/supplier-master',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      print('Supplier & item master uploaded successfully');
      return response.data;
    } catch (e) {
      print('Supplier & item master upload error: $e');
      rethrow;
    }
  }

  // ========================================
  // FORECAST
  // ========================================

  /// Get Seasonality Analysis for a plan period
  Future<Map<String, dynamic>> getSeasonalityAnalysis(String planStart, String planEnd) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/seasonality-analysis', data: {
        'plan_start': planStart,
        'plan_end': planEnd,
      }),
      'getSeasonalityAnalysis',
    );
  }

  /// Run AI Forecast
  Future<Map<String, dynamic>> runForecast(Map<String, dynamic> config) async {
    return await _handleApiCall(
      () => _dio.post('/forecast/run', data: config),
      'runForecast',
    );
  }

  // ========================================
  // PURCHASE REQUESTS
  // ========================================

  /// Get Purchase Requests -- returns typed List<PurchaseRequest>
  Future<List<PurchaseRequest>> getPurchaseRequestsList({
    String? riskLevel,
    String? category,
    String? status,
  }) async {
    try {
      print('Fetching purchase requests (risk: $riskLevel, category: $category, status: $status)');
      final response = await _dio.get(
        '/purchase-requests/list',
        queryParameters: {
          if (riskLevel != null && riskLevel != 'ALL') 'risk_level': riskLevel,
          if (category != null) 'category': category,
          if (status != null) 'status': status,
        },
      );

      print('Got purchase requests from API');
      List<dynamic> rawList;
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['requests'] != null) {
        rawList = response.data['requests'];
      } else {
        rawList = [];
      }
      return rawList
          .map((json) => PurchaseRequest.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('Error fetching purchase requests: $e');
      rethrow;
    }
  }

  /// Get Purchase Requests (Legacy - returns Map)
  Future<Map<String, dynamic>> getPurchaseRequests({
    String? riskLevel,
    String? category,
  }) async {
    return await _handleApiCall(
      () => _dio.get(
        '/purchase-requests/list',
        queryParameters: {
          if (riskLevel != null) 'risk_level': riskLevel,
          if (category != null) 'category': category,
        },
      ),
      'getPurchaseRequests',
    );
  }

  /// Get Purchase Request Detail by RequestID
  Future<Map<String, dynamic>> getPurchaseRequestDetail(int requestId) async {
    return await _handleApiCall(
      () => _dio.get('/purchase-requests/detail/$requestId'),
      'getPurchaseRequestDetail',
    );
  }

  /// Override AI Recommendation by RequestID
  Future<Map<String, dynamic>> overrideRecommendation({
    required int requestId,
    required int quantity,
    required String reasonCategory,
    String? additionalDetails,
  }) async {
    return await _handleApiCall(
      () => _dio.post(
        '/purchase-requests/override',
        data: {
          'request_id': requestId,
          'quantity': quantity,
          'reason_category': reasonCategory,
          'additional_details': additionalDetails,
        },
      ),
      'overrideRecommendation',
    );
  }

  /// Accept All Recommendations (Legacy - by risk level)
  Future<Map<String, dynamic>> acceptAllRecommendations(
      List<String>? riskLevels) async {
    return await _handleApiCall(
      () => _dio.post(
        '/purchase-requests/accept-all',
        data: {'risk_levels': riskLevels},
      ),
      'acceptAllRecommendations',
    );
  }

  /// Accept Selected Items by SKU
  Future<Map<String, dynamic>> acceptSelectedItems({
    required List<String> skus,
  }) async {
    return await _handleApiCall(
      () => _dio.post(
        '/purchase-requests/accept-selected',
        data: {'skus': skus},
      ),
      'acceptSelectedItems',
    );
  }

  /// Submit Selected Items for Approval
  Future<Map<String, dynamic>> submitSelectedForApproval({
    required List<String> skus,
  }) async {
    return await _handleApiCall(
      () => _dio.post(
        '/purchase-requests/submit-selected',
        data: {'skus': skus},
      ),
      'submitSelectedForApproval',
    );
  }

  // ========================================
  // NEW: Per-request workflow methods
  // ========================================

  /// Save forecast results as Draft purchase requests
  Future<Map<String, dynamic>> saveForecastResults(Map<String, dynamic> workflowResult) async {
    return await _handleApiCall(
      () => _dio.post('/purchase-requests/save-forecast', data: {'workflow_result': workflowResult}),
      'saveForecastResults',
    );
  }

  /// Submit Draft PRs for approval (Draft -> Pending)
  Future<Map<String, dynamic>> submitForApproval(List<int> requestIds) async {
    return await _handleApiCall(
      () => _dio.post('/purchase-requests/submit', data: {'request_ids': requestIds}),
      'submitForApproval',
    );
  }

  /// Get purchase requests filtered by statuses
  Future<List<PurchaseRequest>> getPurchaseRequestsByStatus(List<String> statuses) async {
    try {
      final response = await _dio.get(
        '/purchase-requests/by-status',
        queryParameters: {'statuses': statuses.join(',')},
      );
      List<dynamic> rawList;
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['requests'] != null) {
        rawList = response.data['requests'];
      } else {
        rawList = [];
      }
      return rawList
          .map((json) => PurchaseRequest.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      print('Error fetching PRs by status: $e');
      rethrow;
    }
  }

  /// Approve selected purchase requests
  Future<Map<String, dynamic>> approveRequests(List<int> requestIds, {int approverId = 2}) async {
    return await _handleApiCall(
      () => _dio.post('/approval/approve-requests', data: {
        'request_ids': requestIds,
        'approver_id': approverId,
      }),
      'approveRequests',
    );
  }

  /// Reject selected purchase requests with reason
  Future<Map<String, dynamic>> rejectRequests(List<int> requestIds, String reason, {int approverId = 2}) async {
    return await _handleApiCall(
      () => _dio.post('/approval/reject-requests', data: {
        'request_ids': requestIds,
        'approver_id': approverId,
        'reason': reason,
      }),
      'rejectRequests',
    );
  }

  /// Generate PO from an approved purchase request
  Future<Map<String, dynamic>> generatePurchaseOrderFromRequest(int requestId) async {
    return await _handleApiCall(
      () => _dio.post('/orders/generate/$requestId'),
      'generatePurchaseOrderFromRequest',
    );
  }

  /// Generate grouped POs from multiple approved requests (one PO per supplier)
  Future<Map<String, dynamic>> generateGroupedPurchaseOrders(List<int> requestIds) async {
    return await _handleApiCall(
      () => _dio.post('/orders/generate-grouped', data: {'request_ids': requestIds}),
      'generateGroupedPurchaseOrders',
    );
  }

  // ========================================
  // APPROVAL (APPROVER ACTIONS)
  // ========================================

  /// Approve Batch
  Future<Map<String, dynamic>> approveBatch(String batchId, {String? notes}) async {
    return await _handleApiCall(
      () => _dio.post(
        '/approval/approve',
        data: {'batch_id': batchId, 'notes': notes},
      ),
      'approveBatch',
    );
  }

  /// Reject Batch
  Future<Map<String, dynamic>> rejectBatch(String batchId, {required String reason}) async {
    return await _handleApiCall(
      () => _dio.post(
        '/approval/reject',
        data: {'batch_id': batchId, 'reason': reason},
      ),
      'rejectBatch',
    );
  }

  /// Get Batch Summary
  Future<Map<String, dynamic>> getBatchSummary(String batchId) async {
    return await _handleApiCall(
      () => _dio.get('/approval/batch-summary/$batchId'),
      'getBatchSummary',
    );
  }

  /// Submit Batch for Approval
  Future<Map<String, dynamic>> submitBatch({
    required String batchId,
    required bool confirmed,
  }) async {
    return await _handleApiCall(
      () => _dio.post(
        '/approval/submit-batch',
        data: {'batch_id': batchId, 'confirmed': confirmed},
      ),
      'submitBatch',
    );
  }

  /// Get Batch List
  Future<List<Map<String, dynamic>>> getBatchList() async {
    try {
      print('Fetching batch list');
      final response = await _dio.get('/approval/batch-list');

      print('Got batch list from API');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['batches'] != null) {
        return List<Map<String, dynamic>>.from(response.data['batches']);
      }
      return [];
    } catch (e) {
      print('Error fetching batch list: $e');
      rethrow;
    }
  }

  /// Get Batch Detail
  Future<Map<String, dynamic>> getBatchDetail(String batchId) async {
    return await _handleApiCall(
      () => _dio.get('/approval/batch-detail/$batchId'),
      'getBatchDetail',
    );
  }

  /// Get Batch Status
  Future<Map<String, dynamic>> getBatchStatus(String batchId) async {
    return await _handleApiCall(
      () => _dio.get('/approval/batch-status/$batchId'),
      'getBatchStatus',
    );
  }

  // ========================================
  // ORDERS
  // ========================================

  /// Generate Purchase Orders
  Future<Map<String, dynamic>> generatePurchaseOrders(String batchId) async {
    return await _handleApiCall(
      () => _dio.get('/orders/generate/$batchId'),
      'generatePurchaseOrders',
    );
  }

  /// Get Purchase Order List
  Future<List<Map<String, dynamic>>> getPurchaseOrderList() async {
    try {
      print('Fetching purchase order list');
      final response = await _dio.get('/orders/list');

      print('Got purchase order list from API');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['orders'] != null) {
        return List<Map<String, dynamic>>.from(response.data['orders']);
      }
      return [];
    } catch (e) {
      print('Error fetching purchase order list: $e');
      rethrow;
    }
  }

  /// Get Purchase Order Detail (accepts po_id int or po_number string)
  Future<Map<String, dynamic>> getPurchaseOrderDetail(dynamic poIdOrNumber) async {
    return await _handleApiCall(
      () => _dio.get('/orders/detail/$poIdOrNumber'),
      'getPurchaseOrderDetail',
    );
  }

  /// Get Email Template
  Future<Map<String, dynamic>> getEmailTemplate(
    String poNumber, {
    String templateType = 'Standard',
  }) async {
    return await _handleApiCall(
      () => _dio.get(
        '/orders/email-template/$poNumber',
        queryParameters: {'template_type': templateType},
      ),
      'getEmailTemplate',
    );
  }

  /// Send Purchase Order Email
  Future<Map<String, dynamic>> sendPurchaseOrderEmail(
    String poNumber,
    Map<String, dynamic> emailData,
  ) async {
    return await _handleApiCall(
      () => _dio.post('/orders/send-email/$poNumber', data: emailData),
      'sendPurchaseOrderEmail',
    );
  }

  // -- OA / Negotiation --

  /// Amend PO with supplier counter-offer
  Future<Map<String, dynamic>> amendPurchaseOrder({
    required int poId,
    required List<Map<String, dynamic>> lineItems,
    String? etdDate,
    String? reason,
  }) async {
    return await _handleApiCall(
      () => _dio.post('/orders/$poId/amend', data: {
        'line_items': lineItems,
        if (etdDate != null) 'etd_date': etdDate,
        if (reason != null) 'reason': reason,
      }),
      'amendPurchaseOrder',
    );
  }

  /// Confirm (lock) a PO after negotiation
  Future<Map<String, dynamic>> confirmPurchaseOrder(int poId) async {
    return await _handleApiCall(
      () => _dio.post('/orders/$poId/confirm'),
      'confirmPurchaseOrder',
    );
  }

  /// Mark a confirmed PO as completed
  Future<Map<String, dynamic>> markPOCompleted(int poId) async {
    return await _handleApiCall(
      () => _dio.post('/orders/$poId/complete'),
      'markPOCompleted',
    );
  }

  /// Executive re-approve a PO that exceeded 5% price variance
  Future<Map<String, dynamic>> reapprovePurchaseOrder(int poId) async {
    return await _handleApiCall(
      () => _dio.post('/orders/$poId/reapprove'),
      'reapprovePurchaseOrder',
    );
  }

  /// Get PO revision history
  Future<List<Map<String, dynamic>>> getPORevisions(int poId) async {
    try {
      final response = await _dio.get('/orders/$poId/revisions');
      if (response.data is Map && response.data['revisions'] != null) {
        return List<Map<String, dynamic>>.from(response.data['revisions']);
      }
      return [];
    } catch (e) {
      print('Error fetching PO revisions: $e');
      rethrow;
    }
  }

  // ========================================
  // ANALYTICS (APPROVER)
  // ========================================

  /// Get Analytics Data
  Future<Map<String, dynamic>> getAnalyticsData() async {
    return await _handleApiCall(
      () => _dio.get('/analytics/data'),
      'getAnalyticsData',
    );
  }

  /// Get Approval History
  Future<List<Map<String, dynamic>>> getApprovalHistory() async {
    try {
      print('Fetching approval history');
      final response = await _dio.get('/approval/history');

      print('Got approval history from API');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['history'] != null) {
        return List<Map<String, dynamic>>.from(response.data['history']);
      }
      return [];
    } catch (e) {
      print('Error fetching approval history: $e');
      rethrow;
    }
  }

  /// Get Role Mapping Data
  Future<Map<String, dynamic>> getRoleMappingData() async {
    return await _handleApiCall(
      () => _dio.get('/role-mapping/data'),
      'getRoleMappingData',
    );
  }

  /// Update Role Assignment (add/remove category or update approval limit)
  Future<Map<String, dynamic>> updateRoleAssignment({
    required String officerId,
    String? category,
    String? action,
    double? approvalLimit,
  }) async {
    final data = <String, dynamic>{'officer_id': officerId};
    if (category != null) data['category'] = category;
    if (action != null) data['action'] = action;
    if (approvalLimit != null) data['approval_limit'] = approvalLimit;

    return await _handleApiCall(
      () => _dio.post('/role-mapping/update', data: data),
      'updateRoleAssignment',
    );
  }

  /// Assign an officer to a supervisor (GM/MD)
  Future<Map<String, dynamic>> assignOfficerToSupervisor(String officerId, String supervisorId) async {
    return await _handleApiCall(
      () => _dio.post('/role-mapping/assign-supervisor', data: {
        'officer_id': officerId,
        'supervisor_id': supervisorId,
      }),
      'assignOfficerToSupervisor',
    );
  }

  // ========================================
  // WAREHOUSE STOCK
  // ========================================

  /// Get warehouse stock data with optional search filter
  Future<Map<String, dynamic>> getWarehouseStock({String search = ''}) async {
    return await _handleApiCall(
      () => _dio.get('/warehouse/stock', queryParameters: {
        if (search.isNotEmpty) 'search': search,
      }),
      'getWarehouseStock',
    );
  }

  Future<Map<String, dynamic>> updateWarehouseStock(String sku, Map<String, dynamic> data) async {
    return await _handleApiCall(
      () => _dio.put('/warehouse/stock/$sku', data: data),
      'updateWarehouseStock',
    );
  }

  // ========================================
  // SUPPLIERS
  // ========================================

  /// Get all suppliers list
  Future<List<Map<String, dynamic>>> getSuppliersList() async {
    try {
      final response = await _dio.get('/suppliers/list');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('Error fetching suppliers: $e');
      rethrow;
    }
  }

  /// Get supplier detail with items
  Future<Map<String, dynamic>> getSupplierDetail(int supplierId) async {
    return await _handleApiCall(
      () => _dio.get('/suppliers/detail/$supplierId'),
      'getSupplierDetail',
    );
  }

  // ========================================
  // HEALTH CHECK
  // ========================================

  /// Check backend connection
  Future<Map<String, dynamic>> checkConnection() async {
    try {
      print('Testing connection to backend...');
      // Health endpoint is at root (/health), not under /api
      final healthDio = Dio(BaseOptions(
        baseUrl: baseUrl.replaceAll('/api', ''),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await healthDio.get('/health');
      print('Backend is reachable!');
      return {
        'success': true,
        'message': 'Connected to backend',
        'data': response.data,
      };
    } catch (e) {
      print('Backend connection failed: $e');
      return {
        'success': false,
        'message': 'Cannot connect to backend',
        'error': e.toString(),
      };
    }
  }

  // ========================================
  // CUSTOM SEASONALITY EVENTS
  // ========================================

  Future<Map<String, dynamic>> getCustomSeasonalityEvents() async {
    try {
      final response = await _dio.get('/seasonality/events');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> upsertCustomSeasonalityEvent(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/seasonality/events', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> deleteCustomSeasonalityEvent(int eventId) async {
    try {
      await _dio.delete('/seasonality/events/$eventId');
      return true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ========================================
  // ERROR HANDLER
  // ========================================

  String _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection.';
        case DioExceptionType.badResponse:
          if (error.response?.data != null &&
              error.response?.data['detail'] != null) {
            return error.response!.data['detail'];
          }
          return 'Server error: ${error.response?.statusCode}';
        case DioExceptionType.cancel:
          return 'Request cancelled';
        default:
          return 'Network error. Please try again.';
      }
    }
    return 'An unexpected error occurred';
  }
}
