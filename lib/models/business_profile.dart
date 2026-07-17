/// Business profile that trains the AI on the user's specific business context.
/// This is the core "training" data the app uses to write skillful replies.
class BusinessProfile {
  final String id;
  final String businessName;
  final String industry;
  final String description;
  final String tone; // calm | professional | friendly
  final String apologyStyle; // soft | corporate | warm
  final List<String> dos;
  final List<String> donts;
  final String refundPolicy;
  final String shippingPolicy;
  final String contactInfo;
  final String brandVoiceSample;
  final String escalationContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessProfile({
    required this.id,
    required this.businessName,
    required this.industry,
    required this.description,
    required this.tone,
    required this.apologyStyle,
    required this.dos,
    required this.donts,
    required this.refundPolicy,
    required this.shippingPolicy,
    required this.contactInfo,
    required this.brandVoiceSample,
    required this.escalationContact,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessProfile.empty() => BusinessProfile(
        id: 'default',
        businessName: '',
        industry: '',
        description: '',
        tone: 'calm',
        apologyStyle: 'soft',
        dos: [],
        donts: [],
        refundPolicy: '',
        shippingPolicy: '',
        contactInfo: '',
        brandVoiceSample: '',
        escalationContact: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  bool get isConfigured =>
      businessName.isNotEmpty && description.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessName': businessName,
        'industry': industry,
        'description': description,
        'tone': tone,
        'apologyStyle': apologyStyle,
        'dos': dos,
        'donts': donts,
        'refundPolicy': refundPolicy,
        'shippingPolicy': shippingPolicy,
        'contactInfo': contactInfo,
        'brandVoiceSample': brandVoiceSample,
        'escalationContact': escalationContact,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) =>
      BusinessProfile(
        id: json['id'] as String? ?? 'default',
        businessName: json['businessName'] as String? ?? '',
        industry: json['industry'] as String? ?? '',
        description: json['description'] as String? ?? '',
        tone: json['tone'] as String? ?? 'calm',
        apologyStyle: json['apologyStyle'] as String? ?? 'soft',
        dos: List<String>.from(json['dos'] as List? ?? []),
        donts: List<String>.from(json['donts'] as List? ?? []),
        refundPolicy: json['refundPolicy'] as String? ?? '',
        shippingPolicy: json['shippingPolicy'] as String? ?? '',
        contactInfo: json['contactInfo'] as String? ?? '',
        brandVoiceSample: json['brandVoiceSample'] as String? ?? '',
        escalationContact: json['escalationContact'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  BusinessProfile copyWith({
    String? businessName,
    String? industry,
    String? description,
    String? tone,
    String? apologyStyle,
    List<String>? dos,
    List<String>? donts,
    String? refundPolicy,
    String? shippingPolicy,
    String? contactInfo,
    String? brandVoiceSample,
    String? escalationContact,
  }) =>
      BusinessProfile(
        id: id,
        businessName: businessName ?? this.businessName,
        industry: industry ?? this.industry,
        description: description ?? this.description,
        tone: tone ?? this.tone,
        apologyStyle: apologyStyle ?? this.apologyStyle,
        dos: dos ?? this.dos,
        donts: donts ?? this.donts,
        refundPolicy: refundPolicy ?? this.refundPolicy,
        shippingPolicy: shippingPolicy ?? this.shippingPolicy,
        contactInfo: contactInfo ?? this.contactInfo,
        brandVoiceSample: brandVoiceSample ?? this.brandVoiceSample,
        escalationContact: escalationContact ?? this.escalationContact,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
