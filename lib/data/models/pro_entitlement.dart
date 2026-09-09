/// Where a Pro entitlement came from.
///
/// Recorded alongside the entitlement itself so the app can tell a real
/// store purchase from a restore from a developer override. A bare
/// `isPremium` bool couldn't answer "why does this person have Pro?",
/// which is exactly the question that matters when an entitlement looks
/// wrong.
enum ProSource {
  /// No entitlement.
  none,

  /// Bought in this app, through the platform store.
  store,

  /// Re-granted by Restore Purchases, or by the store replaying a
  /// purchase made on another device with the same account.
  restored,

  /// Set by a developer build. Never produced by the purchase flow.
  debug,
}

/// What the app knows about the learner's Pro subscription.
///
/// Deliberately a record rather than a boolean: an entitlement that can
/// be restored on another device, expire, or be granted for testing
/// needs to say which of those it is.
class ProEntitlement {
  final bool isActive;

  /// The store product this came from, e.g. `com.monthly.learning`.
  final String? productId;
  final DateTime? purchasedAt;
  final ProSource source;

  const ProEntitlement({
    this.isActive = false,
    this.productId,
    this.purchasedAt,
    this.source = ProSource.none,
  });

  static const none = ProEntitlement();

  ProEntitlement copyWith({
    bool? isActive,
    String? productId,
    DateTime? purchasedAt,
    ProSource? source,
  }) {
    return ProEntitlement(
      isActive: isActive ?? this.isActive,
      productId: productId ?? this.productId,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'productId': productId,
        'purchasedAt': purchasedAt?.toIso8601String(),
        'source': source.name,
      };

  factory ProEntitlement.fromJson(Map<String, dynamic> json) {
    final rawSource = json['source'] as String?;
    return ProEntitlement(
      isActive: json['isActive'] as bool? ?? false,
      productId: json['productId'] as String?,
      purchasedAt: json['purchasedAt'] == null
          ? null
          : DateTime.tryParse(json['purchasedAt'] as String),
      source: ProSource.values.firstWhere(
        (s) => s.name == rawSource,
        orElse: () => ProSource.none,
      ),
    );
  }
}
