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

/// The four states the rest of the app branches on.
///
/// [trialActive] and [subscribedActive] grant **identical** access — see
/// [EntitlementStatus.grantsAccess]. They are separated only so the app
/// can say which one a member is on; nothing gates on the difference,
/// which is what keeps the distinction safe (see [ProEntitlement.isTrial]
/// for why it cannot be known for certain without a receipt server).
enum EntitlementStatus {
  /// Never subscribed, or the store has no record for this account.
  notSubscribed,

  /// Inside an introductory free trial. Full access.
  trialActive,

  /// Paying. Full access.
  subscribedActive,

  /// Subscribed once; the store no longer reports it as active. No
  /// access, and the paywall comes back.
  expired;

  /// The one question every premium gate asks.
  bool get grantsAccess =>
      this == EntitlementStatus.trialActive ||
      this == EntitlementStatus.subscribedActive;
}

/// What the app knows about the learner's Pro subscription.
///
/// Deliberately a record rather than a boolean: an entitlement that can
/// be restored on another device, expire, or be granted for testing
/// needs to say which of those it is.
///
/// **This is a cache, not the authority.** The store is the authority.
/// On iOS (StoreKit 2) and on Play, asking to restore replays only
/// *currently active* entitlements, and `EntitlementReconciler` uses
/// that on every launch to confirm or expire what is cached here. The
/// cache exists so a member does not watch their content lock and
/// unlock during the round-trip.
class ProEntitlement {
  final EntitlementStatus status;

  /// The store product this came from, e.g. `com.monthly.learning`.
  final String? productId;
  final DateTime? purchasedAt;
  final ProSource source;

  /// When an active introductory trial is expected to end.
  ///
  /// Inferred from the offer the store advertised plus the transaction
  /// date, because `in_app_purchase` exposes no trial end date on either
  /// platform. It is display-only: no gate reads it, so an inference
  /// that is a few hours out costs a label and never access. The store
  /// remains the authority on whether access continues at all.
  final DateTime? trialEndsAt;

  /// When the store last confirmed this entitlement.
  ///
  /// Null for a cache that has never been checked against the store —
  /// which is the state after an app update that added this field, and
  /// the reason reconciliation never expires an entitlement it has not
  /// actually been able to ask about.
  final DateTime? lastVerifiedAt;

  const ProEntitlement({
    this.status = EntitlementStatus.notSubscribed,
    this.productId,
    this.purchasedAt,
    this.source = ProSource.none,
    this.trialEndsAt,
    this.lastVerifiedAt,
  });

  static const none = ProEntitlement();

  /// The single question every premium gate in the app asks.
  bool get isActive => status.grantsAccess;

  /// Whether this member is inside a free trial rather than paying.
  ///
  /// Informational only. Both stores grant an introductory offer at most
  /// once per subscription group and neither reports, through
  /// `in_app_purchase`, whether *this* transaction used one — so this is
  /// derived from the offer that was advertised at purchase time. It
  /// labels a row in Settings; it gates nothing.
  bool get isTrial => status == EntitlementStatus.trialActive;

  ProEntitlement copyWith({
    EntitlementStatus? status,
    String? productId,
    DateTime? purchasedAt,
    ProSource? source,
    DateTime? trialEndsAt,
    DateTime? lastVerifiedAt,
    bool clearTrialEnd = false,
  }) {
    return ProEntitlement(
      status: status ?? this.status,
      productId: productId ?? this.productId,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      source: source ?? this.source,
      trialEndsAt: clearTrialEnd ? null : (trialEndsAt ?? this.trialEndsAt),
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  /// The same entitlement, no longer active.
  ///
  /// Keeps the product and purchase date: "your Monthly plan ended" is a
  /// more useful thing to be able to say than "you have no subscription",
  /// and it is what makes a win-back offer possible later.
  ProEntitlement expire({DateTime? at}) => copyWith(
        status: EntitlementStatus.expired,
        lastVerifiedAt: at ?? DateTime.now(),
        clearTrialEnd: true,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'productId': productId,
        'purchasedAt': purchasedAt?.toIso8601String(),
        'source': source.name,
        'trialEndsAt': trialEndsAt?.toIso8601String(),
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      };

  factory ProEntitlement.fromJson(Map<String, dynamic> json) {
    final rawSource = json['source'] as String?;
    final source = ProSource.values.firstWhere(
      (s) => s.name == rawSource,
      orElse: () => ProSource.none,
    );

    return ProEntitlement(
      status: _statusFrom(json),
      productId: json['productId'] as String?,
      purchasedAt: _dateFrom(json['purchasedAt']),
      source: source,
      trialEndsAt: _dateFrom(json['trialEndsAt']),
      lastVerifiedAt: _dateFrom(json['lastVerifiedAt']),
    );
  }

  /// Reads the status, falling back to the `isActive` bool this record
  /// used to carry.
  ///
  /// An entitlement written by an earlier build has no `status`. Mapping
  /// its `isActive: true` to [EntitlementStatus.subscribedActive] rather
  /// than to a trial is the safe direction: it under-claims the trial
  /// label and never removes access from somebody who has it. The next
  /// reconciliation against the store corrects it either way.
  static EntitlementStatus _statusFrom(Map<String, dynamic> json) {
    final raw = json['status'] as String?;
    if (raw != null) {
      for (final s in EntitlementStatus.values) {
        if (s.name == raw) return s;
      }
    }
    return (json['isActive'] as bool? ?? false)
        ? EntitlementStatus.subscribedActive
        : EntitlementStatus.notSubscribed;
  }

  static DateTime? _dateFrom(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}
