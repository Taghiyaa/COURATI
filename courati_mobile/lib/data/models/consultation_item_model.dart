class ConsultationItemModel {
  final int id;
  final DocumentInfo document;
  final SubjectInfo? subject;
  final String action;
  final String actionDisplay;
  final DateTime consultedAt;
  final String? ipAddress;

  ConsultationItemModel({
    required this.id,
    required this.document,
    this.subject,
    required this.action,
    required this.actionDisplay,
    required this.consultedAt,
    this.ipAddress,
  });

  factory ConsultationItemModel.fromJson(Map<String, dynamic> json) {
    return ConsultationItemModel(
      id: json['id'] ?? 0,
      document: DocumentInfo.fromJson(json['document'] ?? {}),
      subject: json['subject'] != null ? SubjectInfo.fromJson(json['subject']) : null,
      action: json['action'] ?? '',
      actionDisplay: json['action_display'] ?? '',
      consultedAt: DateTime.parse(json['consulted_at'] ?? DateTime.now().toIso8601String()),
      ipAddress: json['ip_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document': document.toJson(),
      'subject': subject?.toJson(),
      'action': action,
      'action_display': actionDisplay,
      'consulted_at': consultedAt.toIso8601String(),
      'ip_address': ipAddress,
    };
  }
}

class DocumentInfo {
  final int id;
  final String title;
  final String documentType;
  final String documentTypeDisplay;
  final double? fileSizeMb;
  final bool isFavorite;

  DocumentInfo({
    required this.id,
    required this.title,
    required this.documentType,
    required this.documentTypeDisplay,
    this.fileSizeMb,
    required this.isFavorite,
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      documentType: json['document_type'] ?? '',
      documentTypeDisplay: json['document_type_display'] ?? '',
      fileSizeMb: json['file_size_mb']?.toDouble(),
      isFavorite: json['is_favorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'document_type': documentType,
      'document_type_display': documentTypeDisplay,
      'file_size_mb': fileSizeMb,
      'is_favorite': isFavorite,
    };
  }
}

class SubjectInfo {
  final int id;
  final String name;
  final String code;

  SubjectInfo({
    required this.id,
    required this.name,
    required this.code,
  });

  factory SubjectInfo.fromJson(Map<String, dynamic> json) {
    return SubjectInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }
}

class ConsultationHistoryResponse {
  final bool success;
  final List<ConsultationItemModel> consultations;
  final ConsultationStats stats;
  final Map<String, dynamic> filters;

  ConsultationHistoryResponse({
    required this.success,
    required this.consultations,
    required this.stats,
    required this.filters,
  });

  factory ConsultationHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ConsultationHistoryResponse(
      success: json['success'] ?? false,
      consultations: (json['consultations'] as List<dynamic>? ?? [])
          .map((item) => ConsultationItemModel.fromJson(item))
          .toList(),
      stats: ConsultationStats.fromJson(json['stats'] ?? {}),
      filters: json['filters'] ?? {},
    );
  }
}

class ConsultationStats {
  final int totalConsultations;
  final int totalViews;
  final int totalDownloads;
  final int uniqueDocuments;

  ConsultationStats({
    required this.totalConsultations,
    required this.totalViews,
    required this.totalDownloads,
    required this.uniqueDocuments,
  });

  factory ConsultationStats.fromJson(Map<String, dynamic> json) {
    return ConsultationStats(
      totalConsultations: json['total_consultations'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      totalDownloads: json['total_downloads'] ?? 0,
      uniqueDocuments: json['unique_documents'] ?? 0,
    );
  }
}