import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';

class PlanLimits {
  final String planId;
  final String planName;
  final int maxUnits; // -1 = unlimited
  final int maxListings;
  final int maxProperties;
  final bool hasAgentAssignment;
  final bool hasAdvancedScreening;
  final bool hasAnalytics;
  final bool hasPrioritySupport;
  final bool isActive;
  final int maxManagers; // -1 unlimited, 0 = feature off
  final int maxArtisans;

  const PlanLimits({
    required this.planId,
    required this.planName,
    required this.maxUnits,
    required this.maxListings,
    required this.maxProperties,
    this.hasAgentAssignment = false,
    this.hasAdvancedScreening = false,
    this.hasAnalytics = false,
    this.hasPrioritySupport = false,
    this.isActive = true,
    this.maxManagers = 0,
    this.maxArtisans = 0,
  });

  bool get unlimitedUnits => maxUnits < 0;
  bool get unlimitedListings => maxListings < 0;
  bool get unlimitedProperties => maxProperties < 0;
  bool get canInviteTeam => maxManagers != 0 || maxArtisans != 0;

  factory PlanLimits.fromPlan(SubscriptionPlanModel plan) {
    return PlanLimits(
      planId: plan.id,
      planName: plan.name,
      maxUnits: plan.maxListings < 0 ? -1 : plan.maxListings, // or separate maxUnits field if you add it
      maxListings: plan.maxListings,
      maxProperties: (plan.maxListings < 0 ? -1 : (plan.maxListings / 3).ceil().clamp(1, 9999)),
      hasAgentAssignment: plan.hasAgentAssignment,
      hasAdvancedScreening: plan.hasAdvancedScreening,
      hasAnalytics: plan.hasAnalytics,
      hasPrioritySupport: plan.hasPrioritySupport,
      isActive: plan.isActive,
      maxManagers: plan.maxManagers ?? (plan.hasAgentAssignment ? -1 : 0),
      maxArtisans: plan.maxArtisans ?? (plan.hasAgentAssignment ? -1 : 0),
    );
  }

  /// Fallback if plan missing from DB
  factory PlanLimits.defaultsFor(String planId) {
    switch (planId.toLowerCase()) {
      case 'basic':
        return const PlanLimits(
          planId: 'basic',
          planName: 'Basic',
          maxUnits: 15,
          maxListings: 15,
          maxProperties: 5,
          hasAgentAssignment: true,
          hasAdvancedScreening: true,
          maxManagers: 1,
          maxArtisans: 2,
        );
      case 'pro':
      case 'premium':
        return const PlanLimits(
          planId: 'pro',
          planName: 'Pro',
          maxUnits: 50,
          maxListings: 50,
          maxProperties: 20,
          hasAgentAssignment: true,
          hasAdvancedScreening: true,
          hasAnalytics: true,
          hasPrioritySupport: true,
          maxManagers: -1,
          maxArtisans: -1,
        );
      case 'business':
      case 'enterprise':
        return const PlanLimits(
          planId: 'business',
          planName: 'Business',
          maxUnits: -1,
          maxListings: -1,
          maxProperties: -1,
          hasAgentAssignment: true,
          hasAdvancedScreening: true,
          hasAnalytics: true,
          hasPrioritySupport: true,
          maxManagers: -1,
          maxArtisans: -1,
        );
      case 'free':
      default:
        return const PlanLimits(
          planId: 'free',
          planName: 'Free',
          maxUnits: 3,
          maxListings: 3,
          maxProperties: 1,
          maxManagers: 0,
          maxArtisans: 0,
        );
    }
  }
}

class SubscriptionLimitService {
  final SubscriptionRepository subscriptionRepository;

  SubscriptionLimitService(this.subscriptionRepository);

  /// Resolve active plan for landowner (or partner workspace owner).
  Future<PlanLimits> getLimits({required String userId, String? partnerId, String? planIdFromContext}) async {
    // 1) Prefer live subscription from DB
    try {
      final sub = await subscriptionRepository.getActiveSubscription(userId, partnerId: partnerId);
      if (sub != null) {
        final plan = await subscriptionRepository.getPlanById(sub.planId);
        if (plan != null) return PlanLimits.fromPlan(plan);
        return PlanLimits.defaultsFor(sub.planId);
      }
    } catch (_) {}

    // 2) JWT / middleware context plan id
    if (planIdFromContext != null && planIdFromContext.isNotEmpty) {
      try {
        final plan = await subscriptionRepository.getPlanById(planIdFromContext);
        if (plan != null) return PlanLimits.fromPlan(plan);
      } catch (_) {}
      return PlanLimits.defaultsFor(planIdFromContext);
    }

    return PlanLimits.defaultsFor('free');
  }

  Future<PlanLimits> limitsFromRequest(Request request) {
    final userId = request.context['userId'] as String?;
    final partnerId = request.context['partnerId'] as String?;
    final planId = request.context['subscriptionPlan'] as String? ?? request.context['planId'] as String?;
    if (userId == null) {
      return Future.value(PlanLimits.defaultsFor('free'));
    }
    return getLimits(userId: userId, partnerId: partnerId, planIdFromContext: planId);
  }

  /// Throws ValidationException or returns a ready 403 Response body map
  void assertWithinLimit({
    required PlanLimits limits,
    required int currentCount,
    required int maxAllowed,
    required String resourceLabel, // 'units' | 'listings' | 'properties'
  }) {
    if (maxAllowed < 0) return; // unlimited
    if (currentCount >= maxAllowed) {
      throw SubscriptionLimitException(
        plan: limits.planName,
        resource: resourceLabel,
        currentCount: currentCount,
        maxAllowed: maxAllowed,
      );
    }
  }

  Future<void> assertCanCreateUnit({
    required Request request,
    required Future<int> Function() countUnits,
  }) async {
    final limits = await limitsFromRequest(request);
    final count = await countUnits();
    assertWithinLimit(
      limits: limits,
      currentCount: count,
      maxAllowed: limits.maxUnits,
      resourceLabel: 'units',
    );
  }

  Future<void> assertCanListUnit({
    required Request request,
    required Future<int> Function() countListed,
  }) async {
    final limits = await limitsFromRequest(request);
    final count = await countListed();
    assertWithinLimit(
      limits: limits,
      currentCount: count,
      maxAllowed: limits.maxListings,
      resourceLabel: 'listings',
    );
  }

  Future<void> assertCanCreateProperty({
    required Request request,
    required Future<int> Function() countProperties,
  }) async {
    final limits = await limitsFromRequest(request);
    final count = await countProperties();
    assertWithinLimit(
      limits: limits,
      currentCount: count,
      maxAllowed: limits.maxProperties,
      resourceLabel: 'properties',
    );
  }

  Future<void> assertFeature({
    required Request request,
    required bool Function(PlanLimits) feature,
    required String featureName,
  }) async {
    final limits = await limitsFromRequest(request);
    if (!feature(limits)) {
      throw SubscriptionFeatureException(plan: limits.planName, feature: featureName);
    }
  }

  Future<void> assertCanInvite({
    required Request request,
    required String inviteeRole, // manager | artisan
    required Future<int> Function() countManagers,
    required Future<int> Function() countArtisans,
  }) async {
    final limits = await limitsFromRequest(request);
    final role = inviteeRole.toLowerCase();

    if (!limits.hasAgentAssignment && limits.maxManagers == 0 && limits.maxArtisans == 0) {
      throw SubscriptionFeatureException(plan: limits.planName, feature: 'inviting managers or artisans');
    }

    if (role == 'manager') {
      if (limits.maxManagers == 0) {
        throw SubscriptionFeatureException(plan: limits.planName, feature: 'inviting managers');
      }
      final count = await countManagers();
      assertWithinLimit(
        limits: limits,
        currentCount: count,
        maxAllowed: limits.maxManagers,
        resourceLabel: 'managers',
      );
    } else if (role == 'artisan') {
      if (limits.maxArtisans == 0) {
        throw SubscriptionFeatureException(plan: limits.planName, feature: 'inviting artisans');
      }
      final count = await countArtisans();
      assertWithinLimit(
        limits: limits,
        currentCount: count,
        maxAllowed: limits.maxArtisans,
        resourceLabel: 'artisans',
      );
    }
  }
}

class SubscriptionLimitException implements Exception {
  final String plan;
  final String resource;
  final int currentCount;
  final int maxAllowed;

  SubscriptionLimitException({
    required this.plan,
    required this.resource,
    required this.currentCount,
    required this.maxAllowed,
  });

  String get message =>
      'You have reached the maximum number of $resource on the $plan plan ($maxAllowed). Please upgrade.';

  Map<String, dynamic> toJson() => {
    'message': message,
    'code': 'SUBSCRIPTION_LIMIT',
    'resource': resource,
    'currentCount': currentCount,
    'maxAllowed': maxAllowed,
    'plan': plan,
    'upgradeUrl': '/subscriptions/plans',
  };

  Response toResponse() =>
      Response(403, body: jsonEncode(toJson()), headers: {'Content-Type': 'application/json'});
}

class SubscriptionFeatureException implements Exception {
  final String plan;
  final String feature;

  SubscriptionFeatureException({required this.plan, required this.feature});

  String get message => 'The "$feature" feature is not available on the $plan plan. Please upgrade.';

  Map<String, dynamic> toJson() => {
    'message': message,
    'code': 'SUBSCRIPTION_FEATURE',
    'feature': feature,
    'plan': plan,
    'upgradeUrl': '/subscriptions/plans',
  };

  Response toResponse() =>
      Response(403, body: jsonEncode(toJson()), headers: {'Content-Type': 'application/json'});
}
