class PayoutAccountModel {
  final String id;
  final String userId;
  final String? propertyId; // Optional: Link to specific property
  final String accountName;
  final String accountNumber;
  final String? paystackSubaccountId; // Paystack subaccount
  final String bankName;
  final String bankCode;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PayoutAccountModel({
    required this.id,
    required this.userId,
    this.propertyId,
    required this.accountName,
    required this.accountNumber,
    this.paystackSubaccountId,
    required this.bankName,
    required this.bankCode,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory PayoutAccountModel.fromMap(Map<String, dynamic> map) {
    return PayoutAccountModel(
      id: map['id'],
      userId: map['userId'] as String,
      propertyId: map['propertyId'] as String?,
      accountName: map['accountName'] as String,
      accountNumber: map['accountNumber'] as String,
      bankName: map['bankName'] as String,
      paystackSubaccountId: map['paystackSubaccountId'],
      bankCode: map['bankCode'] as String,
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'propertyId': propertyId,
    'accountName': accountName,
    'accountNumber': accountNumber,
    'bankName': bankName,
    'paystackSubaccountId': paystackSubaccountId,
    'bankCode': bankCode,
    'isDefault': isDefault,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  PayoutAccountModel copyWith({
    String? id,
    String? userId,
    String? propertyId,
    String? accountName,
    String? accountNumber,
    String? bankName,
    String? bankCode,
    String? paystackSubaccountId,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayoutAccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      propertyId: propertyId ?? this.propertyId,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      paystackSubaccountId: paystackSubaccountId ?? this.paystackSubaccountId,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
