class SubjectModel {
  final int id;
  final String name;
  final String code;
  final int credits;
  final bool isFeatured;
  final List<String> levelNames;
  final List<String> majorNames;
  final int documentCount;
  final bool isFavorite;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.credits,
    required this.isFeatured,
    required this.levelNames,
    required this.majorNames,
    required this.documentCount,
    required this.isFavorite,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      credits: json['credits'] ?? 0,
      isFeatured: json['is_featured'] == true, // Conversion sécurisée bool
      levelNames: json['level_names'] != null 
          ? List<String>.from(json['level_names']) 
          : [],
      majorNames: json['major_names'] != null 
          ? List<String>.from(json['major_names']) 
          : [],
      documentCount: json['document_count'] ?? 0,
      isFavorite: json['is_favorite'] == true, // Conversion sécurisée bool
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'credits': credits,
      'is_featured': isFeatured,
      'level_names': levelNames,
      'major_names': majorNames,
      'document_count': documentCount,
      'is_favorite': isFavorite,
    };
  }

  // Méthodes utiles pour une gestion encore plus sûre
  bool get isFavoriteState => isFavorite == true;
  bool get isFeaturedState => isFeatured == true;
  
  // Copie avec modifications
  SubjectModel copyWith({
    int? id,
    String? name,
    String? code,
    int? credits,
    bool? isFeatured,
    List<String>? levelNames,
    List<String>? majorNames,
    int? documentCount,
    bool? isFavorite,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      credits: credits ?? this.credits,
      isFeatured: isFeatured ?? this.isFeatured,
      levelNames: levelNames ?? this.levelNames,
      majorNames: majorNames ?? this.majorNames,
      documentCount: documentCount ?? this.documentCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}