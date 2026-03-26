class PaymentModel {
  final String id;
  final String? leaseId; // For rent payments
  final String? taskId; // For repair/task payments
  final String payerId; // Tenant or Landowner
  final String? receiverId; // Usually the landowner
  final double amount;
  final String currency; // 'NGN'
  final String status; // 'Pending', 'Paid', 'Overdue', 'Refunded', 'Failed'
  final String? method; // 'Paystack', 'Bank Transfer', 'Cash', etc.
  final String? transactionRef; // External gateway reference
  final String? receiptUrl; // Proof of payment
  final DateTime? dueDate;
  final DateTime? paidDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentModel({
    required this.id,
    this.leaseId,
    this.taskId,
    required this.payerId,
    this.receiverId,
    required this.amount,
    this.currency = 'NGN',
    required this.status,
    this.method,
    this.transactionRef,
    this.receiptUrl,
    this.dueDate,
    this.paidDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      leaseId: map['leaseId'] as String?,
      taskId: map['taskId'] as String?,
      payerId: map['payerId'] as String,
      receiverId: map['receiverId'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'NGN',
      status: map['status'] as String,
      method: map['method'] as String?,
      transactionRef: map['transactionRef'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      paidDate: map['paidDate'] != null ? DateTime.parse(map['paidDate'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'leaseId': leaseId,
    'taskId': taskId,
    'payerId': payerId,
    'receiverId': receiverId,
    'amount': amount,
    'currency': currency,
    'status': status,
    'method': method,
    'transactionRef': transactionRef,
    'receiptUrl': receiptUrl,
    'dueDate': dueDate?.toIso8601String(),
    'paidDate': paidDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  PaymentModel copyWith({
    String? id,
    String? leaseId,
    String? taskId,
    String? payerId,
    String? receiverId,
    double? amount,
    String? currency,
    String? status,
    String? method,
    String? transactionRef,
    String? receiptUrl,
    DateTime? dueDate,
    DateTime? paidDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      leaseId: leaseId ?? this.leaseId,
      taskId: taskId ?? this.taskId,
      payerId: payerId ?? this.payerId,
      receiverId: receiverId ?? this.receiverId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      method: method ?? this.method,
      transactionRef: transactionRef ?? this.transactionRef,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
