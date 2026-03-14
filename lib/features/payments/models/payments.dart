class PaymentModel {
  final String id;
  final String? leaseId;
  final String? taskId; // for artisan payment
  final String payerId;
  final double amount;
  final String currency; // 'NGN'
  final String status; // 'Pending', 'Paid', 'Overdue', 'Refunded'
  final String? method; // 'Bank', 'Paystack', etc.
  final String? receiptPdfUrl;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    this.leaseId,
    this.taskId,
    required this.payerId,
    required this.amount,
    this.currency = 'NGN',
    required this.status,
    this.method,
    this.receiptPdfUrl,
    this.dueDate,
    this.paidDate,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      leaseId: map['leaseId'] as String?,
      taskId: map['taskId'] as String?,
      payerId: map['payerId'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'NGN',
      status: map['status'] as String,
      method: map['method'] as String?,
      receiptPdfUrl: map['receiptPdfUrl'] as String?,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      paidDate: map['paidDate'] != null ? DateTime.parse(map['paidDate'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'leaseId': leaseId,
    'taskId': taskId,
    'payerId': payerId,
    'amount': amount,
    'currency': currency,
    'status': status,
    'method': method,
    'receiptPdfUrl': receiptPdfUrl,
    'dueDate': dueDate?.toIso8601String(),
    'paidDate': paidDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  PaymentModel copyWith({
    String? id,
    String? leaseId,
    String? taskId,
    String? payerId,
    double? amount,
    String? currency,
    String? status,
    String? method,
    String? receiptPdfUrl,
    DateTime? dueDate,
    DateTime? paidDate,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      leaseId: leaseId ?? this.leaseId,
      taskId: taskId ?? this.taskId,
      payerId: payerId ?? this.payerId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      method: method ?? this.method,
      receiptPdfUrl: receiptPdfUrl ?? this.receiptPdfUrl,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
