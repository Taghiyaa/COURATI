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
  final int order;
  final DateTime? uploadedAt; // AJOUT NÉCESSAIRE

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
    required this.order,
    this.uploadedAt, // AJOUT NÉCESSAIRE
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
      order: json['order'] ?? 0,
      uploadedAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null, // AJOUT NÉCESSAIRE
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

  // Nouvelle méthode pour formater la taille du fichier
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
          order == other.order &&
          uploadedAt == other.uploadedAt; // AJOUT NÉCESSAIRE

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
      order.hashCode ^
      (uploadedAt?.hashCode ?? 0); // AJOUT NÉCESSAIRE

  @override
  String toString() {
    return 'DocumentModel{id: $id, title: $title, documentType: $documentType, isFavorite: $isFavorite, uploadedAt: $uploadedAt}';
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
    int? order,
    DateTime? uploadedAt, // AJOUT NÉCESSAIRE
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
      order: order ?? this.order,
      uploadedAt: uploadedAt ?? this.uploadedAt, // AJOUT NÉCESSAIRE
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
      'order': order,
      'created_at': uploadedAt?.toIso8601String(), // AJOUT NÉCESSAIRE
    };
  }
}