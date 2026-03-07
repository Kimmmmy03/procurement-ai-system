// models/procurement_models.dart

enum RiskLevel {
  critical,
  warning,
  lowRisk;

  String get displayName {
    switch (this) {
      case RiskLevel.critical:
        return 'CRITICAL';
      case RiskLevel.warning:
        return 'WARNING';
      case RiskLevel.lowRisk:
        return 'LOW_RISK';
    }
  }
}

enum PRStatus {
  draft,
  pendingApproval,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case PRStatus.draft:
        return 'DRAFT';
      case PRStatus.pendingApproval:
        return 'PENDING_APPROVAL';
      case PRStatus.approved:
        return 'APPROVED';
      case PRStatus.rejected:
        return 'REJECTED';
    }
  }
}

class UploadedItem {
  final String customerSku;
  final String matchedInternalSku;
  final int orderedQty;
  final int currentStock;
  final String status;

  UploadedItem({
    required this.customerSku,
    required this.matchedInternalSku,
    required this.orderedQty,
    required this.currentStock,
    required this.status,
  });

  factory UploadedItem.fromJson(Map<String, dynamic> json) {
    return UploadedItem(
      customerSku: json['customer_sku'],
      matchedInternalSku: json['matched_internal_sku'],
      orderedQty: json['ordered_qty'],
      currentStock: json['current_stock'],
      status: json['status'],
    );
  }
}

class ForecastResult {
  final String totalValue;
  final int prsGenerated;
  final String moqRounded;
  final String estDelivery;
  final bool seasonalityDetected;
  final Map<String, dynamic> seasonalityChartData;
  final String insight;

  ForecastResult({
    required this.totalValue,
    required this.prsGenerated,
    required this.moqRounded,
    required this.estDelivery,
    required this.seasonalityDetected,
    required this.seasonalityChartData,
    required this.insight,
  });

  factory ForecastResult.fromJson(Map<String, dynamic> json) {
    return ForecastResult(
      totalValue: json['total_value'],
      prsGenerated: json['prs_generated'],
      moqRounded: json['moq_rounded'],
      estDelivery: json['est_delivery'],
      seasonalityDetected: json['seasonality_detected'],
      seasonalityChartData: json['seasonality_chart_data'],
      insight: json['insight'],
    );
  }
}

class HistoricalSales {
  final int last30Days;
  final int last60Days;
  final int last90Days;
  final double avgDailySales;
  final String trend;

  HistoricalSales({
    required this.last30Days,
    required this.last60Days,
    required this.last90Days,
    required this.avgDailySales,
    required this.trend,
  });

  factory HistoricalSales.fromJson(Map<String, dynamic> json) {
    return HistoricalSales(
      last30Days: json['last_30_days'],
      last60Days: json['last_60_days'],
      last90Days: json['last_90_days'],
      avgDailySales: json['avg_daily_sales'].toDouble(),
      trend: json['trend'],
    );
  }
}

class CurrentInventory {
  final int currentStock;
  final String supplierLeadTime;
  final String stockCoverage;
  final int reorderPoint;
  final int safetyStock;

  CurrentInventory({
    required this.currentStock,
    required this.supplierLeadTime,
    required this.stockCoverage,
    required this.reorderPoint,
    required this.safetyStock,
  });

  factory CurrentInventory.fromJson(Map<String, dynamic> json) {
    return CurrentInventory(
      currentStock: json['current_stock'],
      supplierLeadTime: json['supplier_lead_time'],
      stockCoverage: json['stock_coverage'],
      reorderPoint: json['reorder_point'],
      safetyStock: json['safety_stock'],
    );
  }
}

class AIRiskAnalysis {
  final RiskLevel riskLevel;
  final String confidenceRate;
  final String reasoning;
  final String aiRecommendation;
  final String coverageAfterOrder;
  final String unitPrice;
  final String totalValue;

  AIRiskAnalysis({
    required this.riskLevel,
    required this.confidenceRate,
    required this.reasoning,
    required this.aiRecommendation,
    required this.coverageAfterOrder,
    required this.unitPrice,
    required this.totalValue,
  });

  factory AIRiskAnalysis.fromJson(Map<String, dynamic> json) {
    return AIRiskAnalysis(
      riskLevel: _parseRiskLevel(json['risk_level']),
      confidenceRate: json['confidence_rate'],
      reasoning: json['reasoning'],
      aiRecommendation: json['ai_recommendation'].toString(),
      coverageAfterOrder: json['coverage_after_order'],
      unitPrice: json['unit_price'],
      totalValue: json['total_value'],
    );
  }

  static RiskLevel _parseRiskLevel(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return RiskLevel.critical;
      case 'WARNING':
        return RiskLevel.warning;
      default:
        return RiskLevel.lowRisk;
    }
  }
}

class SupplierInfo {
  final String supplier;
  final String paymentTerms;
  final int minOrderQty;
  final String lastOrder;

  SupplierInfo({
    required this.supplier,
    required this.paymentTerms,
    required this.minOrderQty,
    required this.lastOrder,
  });

  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      supplier: json['supplier'],
      paymentTerms: json['payment_terms'],
      minOrderQty: json['min_order_qty'],
      lastOrder: json['last_order'],
    );
  }
}

class PurchaseRequestItem {
  final String sku;
  final String product;
  final int aiQty;
  final RiskLevel risk;
  final String aiInsight;
  final String value;
  final HistoricalSales? historicalSales;
  final CurrentInventory? currentInventory;
  final AIRiskAnalysis? aiRiskAnalysis;
  final SupplierInfo? supplierInformation;

  PurchaseRequestItem({
    required this.sku,
    required this.product,
    required this.aiQty,
    required this.risk,
    required this.aiInsight,
    required this.value,
    this.historicalSales,
    this.currentInventory,
    this.aiRiskAnalysis,
    this.supplierInformation,
  });

  factory PurchaseRequestItem.fromJson(Map<String, dynamic> json) {
    return PurchaseRequestItem(
      sku: json['sku'],
      product: json['product'],
      aiQty: json['ai_qty'],
      risk: AIRiskAnalysis._parseRiskLevel(json['risk']),
      aiInsight: json['ai_insight'],
      value: json['value'],
      historicalSales: json['historical_sales'] != null
          ? HistoricalSales.fromJson(json['historical_sales'])
          : null,
      currentInventory: json['current_inventory'] != null
          ? CurrentInventory.fromJson(json['current_inventory'])
          : null,
      aiRiskAnalysis: json['ai_risk_analysis'] != null
          ? AIRiskAnalysis.fromJson(json['ai_risk_analysis'])
          : null,
      supplierInformation: json['supplier_information'] != null
          ? SupplierInfo.fromJson(json['supplier_information'])
          : null,
    );
  }
}

class BatchStatus {
  final String batchId;
  final String submittedDate;
  final int items;
  final String totalValue;
  final String approver;
  final PRStatus status;
  final String lastUpdated;

  BatchStatus({
    required this.batchId,
    required this.submittedDate,
    required this.items,
    required this.totalValue,
    required this.approver,
    required this.status,
    required this.lastUpdated,
  });

  factory BatchStatus.fromJson(Map<String, dynamic> json) {
    return BatchStatus(
      batchId: json['batch_id'],
      submittedDate: json['submitted_date'],
      items: json['items'],
      totalValue: json['total_value'],
      approver: json['approver'],
      status: _parseStatus(json['status']),
      lastUpdated: json['last_updated'],
    );
  }

  static PRStatus _parseStatus(String status) {
    switch (status) {
      case 'PENDING_APPROVAL':
        return PRStatus.pendingApproval;
      case 'APPROVED':
        return PRStatus.approved;
      case 'REJECTED':
        return PRStatus.rejected;
      default:
        return PRStatus.draft;
    }
  }
}

class PurchaseOrder {
  final String poNumber;
  final int poId;
  final String date;
  final String supplier;
  final List<String> shipTo;
  final List<PurchaseOrderItem> items;
  final List<POLineItem> lineItems;
  final double grandTotal;
  final double originalTotalValue;
  final double confirmedTotalValue;
  final String status;
  final String? etdDate;
  final String paymentTerms;
  final String deliveryDate;
  final String specialInstructions;
  final String authorizedBy;
  final List<PORevision> revisions;
  // Logistics
  final double totalCbm;
  final double totalWeightKg;
  final String logisticsVehicle;
  final String logisticsStrategy;
  final double utilizationPercentage;

  PurchaseOrder({
    required this.poNumber,
    this.poId = 0,
    required this.date,
    required this.supplier,
    this.shipTo = const [],
    required this.items,
    this.lineItems = const [],
    required this.grandTotal,
    this.originalTotalValue = 0,
    this.confirmedTotalValue = 0,
    this.status = 'DRAFT',
    this.etdDate,
    this.paymentTerms = '',
    this.deliveryDate = '',
    this.specialInstructions = '',
    this.authorizedBy = '',
    this.revisions = const [],
    this.totalCbm = 0,
    this.totalWeightKg = 0,
    this.logisticsVehicle = '',
    this.logisticsStrategy = 'Local Bulk',
    this.utilizationPercentage = 0,
  });

  /// Whether this PO has a price variance exceeding 5%
  bool get hasSignificantVariance {
    if (originalTotalValue <= 0) return false;
    return ((confirmedTotalValue - originalTotalValue) / originalTotalValue * 100) > 5.0;
  }

  /// Price variance percentage
  double get priceVariancePct {
    if (originalTotalValue <= 0) return 0;
    return (confirmedTotalValue - originalTotalValue) / originalTotalValue * 100;
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    // Parse items (legacy PR-based items)
    final itemsList = json['items'] as List? ?? [];
    final items = itemsList.map((item) => PurchaseOrderItem.fromJson(item)).toList();

    // Parse line items (new negotiation-aware items)
    final lineItemsList = json['line_items'] as List? ?? [];
    final lineItems = lineItemsList.map((li) => POLineItem.fromJson(li)).toList();

    // Parse revisions
    final revisionsList = json['revisions'] as List? ?? [];
    final revisions = revisionsList.map((r) => PORevision.fromJson(r)).toList();

    return PurchaseOrder(
      poNumber: json['po_number'] ?? '',
      poId: json['po_id'] ?? 0,
      date: json['date'] ?? json['created_date'] ?? '',
      supplier: json['supplier'] ?? json['vendor'] ?? '',
      shipTo: json['ship_to'] != null ? List<String>.from(json['ship_to']) : [],
      items: items,
      lineItems: lineItems,
      grandTotal: (json['grand_total'] ?? json['total_value'] ?? 0).toDouble(),
      originalTotalValue: (json['original_total_value'] ?? json['total_value'] ?? 0).toDouble(),
      confirmedTotalValue: (json['confirmed_total_value'] ?? json['total_value'] ?? 0).toDouble(),
      status: json['status'] ?? 'DRAFT',
      etdDate: json['etd_date'],
      paymentTerms: json['payment_terms'] ?? '',
      deliveryDate: json['delivery_date'] ?? '',
      specialInstructions: json['special_instructions'] ?? '',
      authorizedBy: json['authorized_by'] ?? '',
      revisions: revisions,
      totalCbm: (json['total_cbm'] ?? 0).toDouble(),
      totalWeightKg: (json['total_weight_kg'] ?? 0).toDouble(),
      logisticsVehicle: json['logistics_vehicle'] ?? '',
      logisticsStrategy: json['logistics_strategy'] ?? 'Local Bulk',
      utilizationPercentage: (json['utilization_percentage'] ?? 0).toDouble(),
    );
  }
}

class PurchaseOrderItem {
  final String item;
  final String description;
  final int qty;
  final double unitPrice;
  final double total;

  PurchaseOrderItem({
    required this.item,
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    final qty = json['qty'] ?? json['quantity'] ?? 0;
    final unitPrice = (json['unit_price'] ?? 0).toDouble();
    final total = (json['total'] ?? json['total_value'] ?? (qty * unitPrice)).toDouble();
    return PurchaseOrderItem(
      item: json['item'] ?? json['sku'] ?? '',
      description: json['description'] ?? json['product'] ?? '',
      qty: qty is int ? qty : int.tryParse(qty.toString()) ?? 0,
      unitPrice: unitPrice,
      total: total,
    );
  }
}

/// Line item with requested vs confirmed tracking for OA negotiation
class POLineItem {
  final int id;
  final int poId;
  final int requestId;
  final String sku;
  final String productName;
  final int requestedQty;
  final double requestedPrice;
  int confirmedQty;
  double confirmedPrice;

  POLineItem({
    this.id = 0,
    required this.poId,
    required this.requestId,
    required this.sku,
    this.productName = '',
    required this.requestedQty,
    required this.requestedPrice,
    required this.confirmedQty,
    required this.confirmedPrice,
  });

  double get requestedTotal => requestedQty * requestedPrice;
  double get confirmedTotal => confirmedQty * confirmedPrice;
  bool get hasChanged => confirmedQty != requestedQty || confirmedPrice != requestedPrice;

  factory POLineItem.fromJson(Map<String, dynamic> json) {
    final reqQty = json['requested_qty'] ?? 0;
    final reqPrice = (json['requested_price'] ?? 0).toDouble();
    return POLineItem(
      id: json['id'] ?? 0,
      poId: json['po_id'] ?? 0,
      requestId: json['request_id'] ?? 0,
      sku: json['sku'] ?? '',
      productName: json['product_name'] ?? '',
      requestedQty: reqQty,
      requestedPrice: reqPrice,
      confirmedQty: json['confirmed_qty'] ?? reqQty,
      confirmedPrice: (json['confirmed_price'] ?? reqPrice).toDouble(),
    );
  }

  Map<String, dynamic> toAmendJson() => {
    'request_id': requestId,
    'confirmed_qty': confirmedQty,
    'confirmed_price': confirmedPrice,
  };
}

/// PO revision history entry
class PORevision {
  final int id;
  final int poId;
  final String changedBy;
  final String timestamp;
  final String fieldName;
  final String previousValue;
  final String newValue;
  final String? reason;

  PORevision({
    this.id = 0,
    required this.poId,
    required this.changedBy,
    required this.timestamp,
    required this.fieldName,
    this.previousValue = '',
    this.newValue = '',
    this.reason,
  });

  factory PORevision.fromJson(Map<String, dynamic> json) {
    return PORevision(
      id: json['id'] ?? 0,
      poId: json['po_id'] ?? 0,
      changedBy: json['changed_by'] ?? '',
      timestamp: json['timestamp'] ?? '',
      fieldName: json['field_name'] ?? '',
      previousValue: json['previous_value']?.toString() ?? '',
      newValue: json['new_value']?.toString() ?? '',
      reason: json['reason'],
    );
  }
}

class DashboardStats {
  final int myPendingPrs;
  final int awaitingApproval;
  final int criticalItems;
  final int posGenerated;

  DashboardStats({
    required this.myPendingPrs,
    required this.awaitingApproval,
    required this.criticalItems,
    required this.posGenerated,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      myPendingPrs: json['my_pending_prs'],
      awaitingApproval: json['awaiting_approval'],
      criticalItems: json['critical_items'],
      posGenerated: json['pos_generated'],
    );
  }
}

/// Purchase Request — maps to [dbo].[purchase_requests] table
class PurchaseRequest {
  final int requestId;
  final String sku;
  final String productName;
  final int aiRecommendedQty;
  final int? userOverriddenQty;
  final String riskLevel;
  final String? aiInsightText;
  final double totalValue;
  final int last30DaysSales;
  final int last60DaysSales;
  final int currentStock;
  final int supplierLeadTime;
  final int stockCoverageDays;
  final String? supplierName;
  final int minOrderQty;
  final String? overrideReason;
  final String? overrideDetails;
  final String status;
  final String? rejectionReason;
  final String? approvalDate;
  final int? approverId;
  // Manufacturing logistics fields
  final double totalCbm;
  final double totalWeightKg;
  final String logisticsVehicle;
  final String containerStrategy;
  final int containerFillRate;
  final int estimatedTransitDays;
  final String? aiReasoning;
  // Enhanced logistics fields
  final String containerSize;
  final int containerCount;
  final String recommendedLorry;
  final int lorryCount;
  final String fillUpSuggestion;
  final int weightUtilizationPct;
  final double spareCbm;

  PurchaseRequest({
    required this.requestId,
    required this.sku,
    required this.productName,
    required this.aiRecommendedQty,
    this.userOverriddenQty,
    required this.riskLevel,
    this.aiInsightText,
    required this.totalValue,
    required this.last30DaysSales,
    required this.last60DaysSales,
    required this.currentStock,
    required this.supplierLeadTime,
    required this.stockCoverageDays,
    this.supplierName,
    required this.minOrderQty,
    this.overrideReason,
    this.overrideDetails,
    this.status = 'Draft',
    this.rejectionReason,
    this.approvalDate,
    this.approverId,
    this.totalCbm = 0.0,
    this.totalWeightKg = 0.0,
    this.logisticsVehicle = '',
    this.containerStrategy = 'Local Bulk',
    this.containerFillRate = 0,
    this.estimatedTransitDays = 0,
    this.aiReasoning,
    this.containerSize = '',
    this.containerCount = 0,
    this.recommendedLorry = '',
    this.lorryCount = 0,
    this.fillUpSuggestion = '',
    this.weightUtilizationPct = 0,
    this.spareCbm = 0.0,
  });

  /// Effective quantity: user override if set, otherwise AI recommendation
  int get effectiveQty => userOverriddenQty ?? aiRecommendedQty;

  /// Whether this request has been overridden
  bool get isOverridden => userOverriddenQty != null;

  /// Computed unit price
  double get unitPrice =>
      aiRecommendedQty > 0 ? totalValue / aiRecommendedQty : 0;

  /// Computed average daily sales
  double get avgDailySales => last30DaysSales / 30;

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      requestId: json['RequestID'] ?? json['request_id'] ?? 0,
      sku: json['SKU'] ?? json['sku'] ?? '',
      productName: json['ProductName'] ?? json['product_name'] ?? '',
      aiRecommendedQty: json['AiRecommendedQty'] ?? json['ai_recommended_qty'] ?? 0,
      userOverriddenQty: json['UserOverriddenQty'] ?? json['user_overridden_qty'],
      riskLevel: json['RiskLevel'] ?? json['risk_level'] ?? 'Low',
      aiInsightText: json['AiInsightText'] ?? json['ai_insight_text'],
      totalValue: (json['TotalValue'] ?? json['total_value'] ?? 0).toDouble(),
      last30DaysSales: json['Last30DaysSales'] ?? json['last_30_days_sales'] ?? 0,
      last60DaysSales: json['Last60DaysSales'] ?? json['last_60_days_sales'] ?? 0,
      currentStock: json['CurrentStock'] ?? json['current_stock'] ?? 0,
      supplierLeadTime: json['SupplierLeadTime'] ?? json['supplier_lead_time'] ?? 14,
      stockCoverageDays: json['StockCoverageDays'] ?? json['stock_coverage_days'] ?? 0,
      supplierName: json['SupplierName'] ?? json['supplier_name'],
      minOrderQty: json['MinOrderQty'] ?? json['min_order_qty'] ?? 1,
      overrideReason: json['OverrideReason'] ?? json['override_reason'],
      overrideDetails: json['OverrideDetails'] ?? json['override_details'],
      status: json['Status'] ?? json['status'] ?? 'Draft',
      rejectionReason: json['RejectionReason'] ?? json['rejection_reason'],
      approvalDate: json['ApprovalDate'] ?? json['approval_date'],
      approverId: json['ApproverID'] ?? json['approver_id'],
      totalCbm: (json['TotalCBM'] ?? json['total_cbm'] ?? 0).toDouble(),
      totalWeightKg: (json['TotalWeightKg'] ?? json['total_weight_kg'] ?? 0).toDouble(),
      logisticsVehicle: json['LogisticsVehicle'] ?? json['logistics_vehicle'] ?? '',
      containerStrategy: json['ContainerStrategy'] ?? json['container_strategy'] ?? 'Local Bulk',
      containerFillRate: json['ContainerFillRate'] ?? json['container_fill_rate'] ?? json['container_fill_rate_percentage'] ?? 0,
      estimatedTransitDays: json['EstimatedTransitDays'] ?? json['estimated_transit_days'] ?? 0,
      aiReasoning: json['AiReasoning'] ?? json['ai_reasoning'],
      containerSize: json['ContainerSize'] ?? json['container_size'] ?? '',
      containerCount: json['ContainerCount'] ?? json['container_count'] ?? 0,
      recommendedLorry: json['RecommendedLorry'] ?? json['recommended_lorry'] ?? '',
      lorryCount: json['LorryCount'] ?? json['lorry_count'] ?? 0,
      fillUpSuggestion: json['FillUpSuggestion'] ?? json['fill_up_suggestion'] ?? '',
      weightUtilizationPct: json['WeightUtilizationPct'] ?? json['weight_utilization_pct'] ?? 0,
      spareCbm: (json['SpareCbm'] ?? json['spare_cbm'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'RequestID': requestId,
    'SKU': sku,
    'ProductName': productName,
    'AiRecommendedQty': aiRecommendedQty,
    'UserOverriddenQty': userOverriddenQty,
    'RiskLevel': riskLevel,
    'AiInsightText': aiInsightText,
    'TotalValue': totalValue,
    'Last30DaysSales': last30DaysSales,
    'Last60DaysSales': last60DaysSales,
    'CurrentStock': currentStock,
    'SupplierLeadTime': supplierLeadTime,
    'StockCoverageDays': stockCoverageDays,
    'SupplierName': supplierName,
    'MinOrderQty': minOrderQty,
    'Status': status,
    'TotalCBM': totalCbm,
    'TotalWeightKg': totalWeightKg,
    'LogisticsVehicle': logisticsVehicle,
    'ContainerStrategy': containerStrategy,
    'ContainerFillRate': containerFillRate,
    'EstimatedTransitDays': estimatedTransitDays,
    'AiReasoning': aiReasoning,
    'ContainerSize': containerSize,
    'ContainerCount': containerCount,
    'RecommendedLorry': recommendedLorry,
    'LorryCount': lorryCount,
    'FillUpSuggestion': fillUpSuggestion,
    'WeightUtilizationPct': weightUtilizationPct,
    'SpareCbm': spareCbm,
  };

  /// Create a copy with override applied (for local state updates)
  PurchaseRequest copyWithOverride({
    required int newQty,
    required String reason,
    String? details,
  }) {
    return PurchaseRequest(
      requestId: requestId,
      sku: sku,
      productName: productName,
      aiRecommendedQty: aiRecommendedQty,
      userOverriddenQty: newQty,
      riskLevel: riskLevel,
      aiInsightText: aiInsightText,
      totalValue: totalValue,
      last30DaysSales: last30DaysSales,
      last60DaysSales: last60DaysSales,
      currentStock: currentStock,
      supplierLeadTime: supplierLeadTime,
      stockCoverageDays: stockCoverageDays,
      supplierName: supplierName,
      minOrderQty: minOrderQty,
      overrideReason: reason,
      overrideDetails: details,
      status: status,
      rejectionReason: rejectionReason,
      approvalDate: approvalDate,
      approverId: approverId,
      totalCbm: totalCbm,
      totalWeightKg: totalWeightKg,
      logisticsVehicle: logisticsVehicle,
      containerStrategy: containerStrategy,
      containerFillRate: containerFillRate,
      estimatedTransitDays: estimatedTransitDays,
      aiReasoning: aiReasoning,
      containerSize: containerSize,
      containerCount: containerCount,
      recommendedLorry: recommendedLorry,
      lorryCount: lorryCount,
      fillUpSuggestion: fillUpSuggestion,
      weightUtilizationPct: weightUtilizationPct,
      spareCbm: spareCbm,
    );
  }
}

/// Batch summary with Decision Cockpit metrics
class BatchSummary {
  final String batchId;
  final int totalItems;
  final double totalValue;
  final int avgStockCoverageDays;
  final int highRiskItemsCount;
  final Map<String, int> containerBreakdown;

  BatchSummary({
    required this.batchId,
    required this.totalItems,
    required this.totalValue,
    required this.avgStockCoverageDays,
    required this.highRiskItemsCount,
    required this.containerBreakdown,
  });

  factory BatchSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = json['container_breakdown'] ?? {};
    final Map<String, int> parsedBreakdown = {};
    breakdown.forEach((key, value) {
      parsedBreakdown[key.toString()] = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
    });

    return BatchSummary(
      batchId: json['batch_id'] ?? '',
      totalItems: json['total_items'] ?? 0,
      totalValue: (json['total_value'] ?? 0).toDouble(),
      avgStockCoverageDays: json['avg_stock_coverage_days'] ?? 0,
      highRiskItemsCount: json['high_risk_items_count'] ?? 0,
      containerBreakdown: parsedBreakdown,
    );
  }

  String get containerBreakdownDisplay {
    if (containerBreakdown.isEmpty) return 'N/A';
    return containerBreakdown.entries
        .map((e) => '${e.value} ${e.key}')
        .join(' | ');
  }
}
