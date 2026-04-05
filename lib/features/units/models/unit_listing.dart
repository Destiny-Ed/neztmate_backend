enum ListingStatus { listed, unlisted }

class UnitListingRequest {
  final bool isListed; // true = list for rent, false = unlist

  UnitListingRequest({required this.isListed});

  factory UnitListingRequest.fromJson(Map<String, dynamic> json) =>
      UnitListingRequest(isListed: json['isListed'] as bool);

  Map<String, dynamic> toJson() => {'isListed': isListed};
}
