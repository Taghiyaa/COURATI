import 'package:flutter/material.dart';

class DocumentModel {
  final int id;
  final String title;
  final String description;
  final String documentType;
  final String fileUrl;
  final double fileSizeMb;
  final bool isActive;
  final bool isPremium;
  final int downloadCount;
  final bool isFavorite;
  final bool isViewed;  // ✅ AJOUTÉ
  final int order;
  final DateTime? uploadedAt;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.documentType,
    required this.fileUrl,
    required this.fileSizeMb,
    required this.isActive,
    required this.isPremium,
    required this.downloadCount,
    required this.isFavorite,
    required this.isViewed,  // ✅ AJOUTÉ
    required this.order,
    this.uploadedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      documentType: json['document_type'] ?? '',
      fileUrl: json['file'] ?? '',
      fileSizeMb: (json['file_size_mb'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? false,
      isPremium: json['is_premium'] ?? false,
      downloadCount: json['download_count'] ?? 0,
      isFavorite: json['is_favorite'] ?? false,
      isViewed: json['is_viewed'] ?? false,  // ✅ AJOUTÉ
      order: json['order'] ?? 0,
      uploadedAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
    );
  }

  String get typeDisplayName {
    switch (documentType) {
      case 'COURS':
        return 'Cours';
      case 'TD':
        return 'TD';
      case 'TP':
        return 'TP';
      case 'ARCHIVE':
        return 'Archive';
      default:
        return documentType;
    }
  }

  // Méthode pour formater la taille du fichier
  String get fileSizeFormatted {
    if (fileSizeMb < 1) {
      return '${(fileSizeMb * 1024).toStringAsFixed(0)} KB';
    }
    return '${fileSizeMb.toStringAsFixed(1)} MB';
  }

  // Méthodes essentielles pour éviter les rebuilds
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          documentType == other.documentType &&
          fileUrl == other.fileUrl &&
          fileSizeMb == other.fileSizeMb &&
          isActive == other.isActive &&
          isPremium == other.isPremium &&
          downloadCount == other.downloadCount &&
          isFavorite == other.isFavorite &&
          isViewed == other.isViewed &&  // ✅ AJOUTÉ
          order == other.order &&
          uploadedAt == other.uploadedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      documentType.hashCode ^
      fileUrl.hashCode ^
      fileSizeMb.hashCode ^
      isActive.hashCode ^
      isPremium.hashCode ^
      downloadCount.hashCode ^
      isFavorite.hashCode ^
      isViewed.hashCode ^  // ✅ AJOUTÉ
      order.hashCode ^
      (uploadedAt?.hashCode ?? 0);

  @override
  String toString() {
    return 'DocumentModel{id: $id, title: $title, documentType: $documentType, isFavorite: $isFavorite, isViewed: $isViewed, uploadedAt: $uploadedAt}';  // ✅ MODIFIÉ
  }

  // Méthode pour copier avec modifications
  DocumentModel copyWith({
    int? id,
    String? title,
    String? description,
    String? documentType,
    String? fileUrl,
    double? fileSizeMb,
    bool? isActive,
    bool? isPremium,
    int? downloadCount,
    bool? isFavorite,
    bool? isViewed,  // ✅ AJOUTÉ
    int? order,
    DateTime? uploadedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      documentType: documentType ?? this.documentType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      downloadCount: downloadCount ?? this.downloadCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isViewed: isViewed ?? this.isViewed,  // ✅ AJOUTÉ
      order: order ?? this.order,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'document_type': documentType,
      'file': fileUrl,
      'file_size_mb': fileSizeMb,
      'is_active': isActive,
      'is_premium': isPremium,
      'download_count': downloadCount,
      'is_favorite': isFavorite,
      'is_viewed': isViewed,  // ✅ AJOUTÉ
      'order': order,
      'created_at': uploadedAt?.toIso8601String(),
    };
  }
}