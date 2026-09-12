# In-app purchases

LingoQuest Pro is a subscription sold through the platform stores. This
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

The same three ids are used on both stores, so each product created in
App Store Connect must be created verbatim in the Play Console as well.

Defined once in `ProProducts` (`lib/core/services/purchase_service.dart`).

## Prices and the free trial live in the stores, not in this repo

**The app has no prices in it and cannot set one.** Monthly at $12,
yearly at $30 and the monthly plan's 3-day free trial are all console
configuration:

| What | Where to set it |
| --- | --- |
| Monthly $12 | App Store Connect → Subscriptions → `com.monthly.learning` → Subscription Prices; Play Console → `com.monthly.learning` → base plan → price |
| Yearly $30 | The same two places for `com.yearly.learning` |
| 3-day free trial on monthly | App Store Connect → `com.monthly.learning` → **Introductory Offers** → Free, 3 days; Play Console → `com.monthly.learning` → base plan → **Add offer** → free trial, 3 days |

Changing any of them is a console change that takes effect without an app
release, in every storefront's own currency. Nothing in Dart needs
touching, and nothing in Dart can override it.

### How the trial reaches the screen

`lib/core/services/store_offer.dart` reads the offer back off the product
the store returned — `SKProductWrapper.introductoryPrice` on iOS, the
zero-priced pricing phase on Play — and the badge, the CTA ("Start my 3
days free") and the disclosure line are all built from that. Remove the
offer in the console and all three disappear on the next launch. A
discounted-but-not-free introductory price is deliberately **not** shown
as a trial.

Two Play-specific wrinkles that `store_offer.dart` exists to handle:

- Play builds `ProductDetails` from an offer's **first** pricing phase, so
  a plan with a trial reports its price as "Free" and its raw price as
  zero. `recurringPriceOf` finds the recurring phase instead, so the card
  shows $12.00 and the plans still sort by price.
- Play returns **one product per offer**, all sharing a product id, so a
  monthly plan with a trial arrives twice. `dedupeByPlan` collapses them,
  keeping the trial-bearing offer, because that is the one Play applies at
  checkout.

Eligibility is not claimed anywhere. Apple grants an introductory offer
once per subscription group, and StoreKit 1 does not report eligibility,
so the copy describes the plan rather than promising this learner a trial.

## Google Play setup

1. **Play Console → Monetise → Products → Subscriptions.** Create all three
   ids above, each with a base plan and a price in every target country.
   Add the 3-day free trial to `com.monthly.learning` as an **offer** on
   its base plan.
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
   group ("LingoQuest Pro") containing all three ids above, and add a
   3-day free **Introductory Offer** to `com.monthly.learning`.
2. Fill in a display name, description, and price for each. Apple will not
   return a product missing any of these.
3. **Agreements, Tax and Banking** must show the Paid Applications
   agreement as active, or every product query comes back empty.
4. Create a **Sandbox tester** under Users and Access, and sign in with it
   on the device (Settings → App Store → Sandbox Account).

### Testing without App Store Connect

`ios/Runner/LingoQuest.storekit` describes all three subscriptions
locally — including the monthly plan's 3-day introductory offer — so the
purchase flow and the trial badge can be exercised in the simulator
before any of the above exists:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Product → Scheme → Edit Scheme → Run → Options.
3. Set **StoreKit Configuration** to `LingoQuest.storekit`.

Prices in that file, and the trial in it, are **simulator placeholders
only**. Nothing reads them on a real device — the app displays
`ProductDetails.price` from whichever store answered, already localized
to the buyer's storefront, and reads the trial off that same product.
Setting $12 there does not set $12 in the App Store.

The file's `_storeKitErrors` block can also force failures (load, purchase,
verification) to exercise the error paths by hand.

## After they subscribe

Every surface that was selling Pro has to stop. A subscriber who is still
shown "Upgrade to Pro" concludes the purchase did not register, and the
next thing they look for is the cancel button.

| Surface | Before purchase | After purchase |
| --- | --- | --- |
| Home pill | Bolt icon, brand green, glowing — the one upsell on the screen | Check icon, success green, no glow: a membership badge that still opens the Pro screen |
| Settings | "Upgrade to Pro" + "Restore Purchase" | "LingoQuest Pro · Active · Monthly plan" + "Manage subscription" |
| Pro screen | Plan cards, buy button, "Restore Purchases" | A membership page: the active-plan card, what is unlocked, the learner's totals, and "Manage subscription" |

The Pro screen still opens from both of its entry points after a
purchase — the Home pill and the Settings row — because a subscriber
needs somewhere to confirm what they are on and reach the store. What
changes is which page the route builds: `_SalesBody` or
`_MemberBody`. They are separate columns rather than one column
full of conditionals, because the two have opposite shapes. Selling
asks the reader to compare plans and ends at a button, so its weight
sits at the bottom; confirming a membership answers "what do I have?",
so its weight sits at the top. While they shared a column, the plan
cards were the only thing holding the spacing together, and removing
them for a subscriber left a headline at the top, a receipt at the
bottom and a hole in between.

The membership card reports only what the stored entitlement actually
holds: the plan, and the purchase date as "Member since". No renewal
date and no next-charge amount — with no receipt verification this app
does not know either, and the store does, which is what the manage
button is for.

Below `_MemberBody` the screen also shows the learner's lifetime XP,
streak and lesson count, using the same glyphs and colours Home gives
those three figures. They are labelled "Your progress" rather than
anything since-purchase: `UserProgress` counts from the first lesson
and holds no notion of when a subscription began. On a screen shorter
than 700pt — an iPhone SE — the strip is dropped rather than letting
the page scroll, since Home shows the same three figures anyway.

The plan name comes from `ProProducts.planLabel(productId)`, derived
from the product id rather than the store's localized title — that title
is translated and usually carries the app name, so it is display text,
not data. An entitlement restored by a build that never recorded a
product id reads "Active" with no plan, because naming a plan they might
not be on is worse than naming none.

### Seeing both states

`test/widget/pro_screen_golden.dart` renders the Pro screen in both
states and Settings in the subscribed one, at 6.9" iPhone geometry with
the app's real bundled fonts:

```
flutter test test/widget/pro_screen_golden.dart --update-goldens
```

It is named without the `_test` suffix on purpose, so `flutter test`
does not pick it up — golden output moves with the Flutter version and
the host's font rasterizer, and these exist to be looked at rather than
to fail a build. The behaviour itself is pinned platform-independently
in `pro_member_state_test.dart` and `premium_screen_test.dart`, including
that neither state scrolls on a Pixel 5a or an iPhone SE.

### Manage subscription

Both stores require an app selling an auto-renewable subscription to
point the buyer at where it can be changed or cancelled, and a line of
prose saying "manage it in your account settings" is not a link that
goes there. `SubscriptionManager` builds the right URL per platform:

- **iOS** — `https://apps.apple.com/account/subscriptions`. One page
  for the whole account; the product id is irrelevant.
- **Android** — `https://play.google.com/store/account/subscriptions?sku=<productId>&package=com.lernova.lernova`,
  falling back to the account list when the product is unknown.

Neither platform lets an app cancel on the buyer's behalf, and neither
should — the store is the only party that knows the real renewal state.

The package name is hard-coded in `SubscriptionManager.androidPackage` and
must match `applicationId` in `android/app/build.gradle.kts`.

### Restore

"Restore Purchase" in Settings used to show a snackbar explaining that
purchases restore from the store account, and then restore nothing. It
now calls `PurchaseController.restore()`. It is hidden once Pro is
active, because there is nothing left to restore — the Pro screen makes
the same swap, showing "Manage subscription" in its place.

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
- **Subscriber state**: with Pro active, Settings must show "Active · <plan>"
  and "Manage subscription", never "Upgrade to Pro" or "Restore Purchase",
  and the Home pill must be the quiet check badge.
- **Manage subscription** must open the store account page on a real
  device on both platforms. It cannot work in the simulator.
- Airplane mode — "Prices unavailable", disabled button, no invented price.
- **The trial**: with the offer configured, the monthly card shows
  "3 DAYS FREE", "then $12.00 per month", and the CTA reads "Start my 3
  days free". Remove the offer in the console and all three must vanish
  without an app release.
- **A second trial attempt**: a store account that has already used the
  introductory offer is charged immediately. The screen still advertises
  the trial, because neither store reports per-account eligibility here —
  known and accepted.

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
