# In-app purchases

Lernova Pro is a subscription sold through the platform stores. This
document covers what the app does, and the store-side setup it depends
on — which is configuration work, not code, and cannot be done from the
repository.

## Status

| | State |
|---|---|
| Purchase logic | Complete, covered by 14 tests against a fake store |
| Android wiring | Connects to Play Billing; blocked on Play Console products |
| iOS wiring | **Never compiled.** Needs a Mac |

The last row matters: the iOS code has never been built or run. Treat it
as unverified until someone opens the project in Xcode.

## How it fits together

```
premium_screen.dart          UI only. Renders products, never prices of its own.
  └─ purchase_controller.dart   State machine. Every store outcome handled here.
       └─ purchase_service.dart    The only file that imports in_app_purchase.
            └─ StoreKit / Play Billing
```

Entitlement is written through `ProgressController.applyEntitlement`, which
records a `ProEntitlement` (product id, purchase date, and whether it came
from a purchase, a restore, or a debug override) alongside the existing
`isPremium` flag every other feature already reads.

The purchase stream is opened in `main.dart` at launch, not when the Pro
screen opens — a store can deliver a transaction that completed while the
app was closed, and missing it would leave someone paying for Pro without
having it.

## Product IDs

Both stores must use these exact ids. They are the only hard-coded thing
about a plan — name, price, and billing period all come from the store at
runtime, so a price change is a store change and never an app release.

| Id | Period |
|---|---|
| `com.weekly.learning` | 1 week |
| `com.monthly.learning` | 1 month |
| `com.yearly.learning` | 1 year |

All three belong to one subscription group, so a learner can move
between them rather than holding two at once. The longest period is
shown first and carries the "Best value" badge — the Pro screen sorts by
the store's own price, so that ordering follows the prices you set
rather than the order the ids are declared in.

The same two ids are used on both stores, so each product created in App
Store Connect must be created verbatim in the Play Console as well.

Defined once in `ProProducts` (`lib/core/services/purchase_service.dart`).

## Google Play setup

1. **Play Console → Monetise → Products → Subscriptions.** Create both ids
   above, each with a base plan and a price in every target country.
2. **Activate** them. A subscription left in draft returns nothing from
   `queryProductDetails`, which looks identical to "not configured".
3. **Upload a signed build** to a track — internal testing is enough. Play
   Billing does not serve products to a sideloaded debug APK, so the build
   installed by `flutter run` will always show "Plans are not available".
4. **Play Console → Setup → License testing.** Add the Google accounts
   that will test. Testers buy at no charge and can renew on an
   accelerated schedule.
5. Install from the track link, signed in as a licence tester.

The `com.android.vending.BILLING` permission is already in
`android/app/src/main/AndroidManifest.xml`.

## App Store setup

1. **App Store Connect → your app → Subscriptions.** Create a subscription
   group ("Lernova Pro") containing both ids above.
2. Fill in a display name, description, and price for each. Apple will not
   return a product missing any of these.
3. **Agreements, Tax and Banking** must show the Paid Applications
   agreement as active, or every product query comes back empty.
4. Create a **Sandbox tester** under Users and Access, and sign in with it
   on the device (Settings → App Store → Sandbox Account).

### Testing without App Store Connect

`ios/Runner/Lernova.storekit` describes both subscriptions locally, so the
purchase flow can be exercised in the simulator before any of the above
exists:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Product → Scheme → Edit Scheme → Run → Options.
3. Set **StoreKit Configuration** to `Lernova.storekit`.

Prices in that file are placeholders for local runs only. Nothing reads
them at runtime — the app displays `ProductDetails.price` from whichever
store answered, which is already localized to the buyer's storefront.

The file's `_storeKitErrors` block can also force failures (load, purchase,
verification) to exercise the error paths by hand.

## What to test

The unit tests cover the logic; these need a real store.

- Buy each plan, on each platform.
- Cancel the sheet — nothing granted, no error shown. Backing out is not a
  failure and must not be styled as one.
- Buy with a declined card — a readable message, nothing granted.
- **Pending**: on Android use a test card set to "slow"; on iOS enable Ask
  to Buy on a sandbox child account. Pro must stay locked until it clears,
  then unlock on its own.
- **Restore** on a second device with the same store account.
- Reopen the app after buying — Pro still on.
- Open the Pro screen while already subscribed — the CTA must refuse to
  start a second purchase.
- Airplane mode — "Prices unavailable", disabled button, no invented price.

## Known limitation: no server verification

There is no backend, so `PurchaseDetails.verificationData` is never
verified against Apple's or Google's servers. The entitlement is stored
locally, which means it is **spoofable on a rooted or jailbroken device**.

This is a deliberate, documented gap rather than an oversight. Closing it
needs a server endpoint that validates the receipt with the store and
returns the entitlement — at which point `applyEntitlement` should be
driven by that response instead of directly by the purchase stream.

For a paid app of this size the practical risk is low, but it should be
understood before launch rather than discovered after.
