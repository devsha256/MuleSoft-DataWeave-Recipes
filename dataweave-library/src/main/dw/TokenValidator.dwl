%dw 2.0
// ============================================================================
// Token utilities — production-ready module
// - Compact, well-documented DataWeave 2.0 module for evaluating OAuth/Salesforce
//   introspection responses.
// - Provides: normalization, datetime helpers, validity checks, a performance
//   snapshot (compute once, reuse many times), and a small validation helper.
// - All functions are pure and safe for use inside Mule flows and unit tests.
// ============================================================================

/* ---------------- TYPES ---------------- */

type IntrospectResponse = {
  active: Boolean,
  scope?: String | Null,
  username?: String,
  sub?: String,
  token_type?: String,
  session_type?: String,
  exp?: Number | Null,    // epoch seconds
  iat?: Number | Null,    // epoch seconds
  nbf?: Number | Null     // epoch seconds
}

type TokenTimeContext = {
  active: Boolean,
  exp: Number | Null,
  iat: Number | Null,
  nbf: Number | Null,
  scope: String | Null,
  username: String | Null,
  sub: String | Null,
  token_type: String | Null,
  session_type: String | Null
}

type TokenSnapshot = {
  nowEpoch: Number,            // epoch seconds captured for snapshot
  expiresAt: Number | Null,    // same as ctx.exp (number) or null
  notBefore: Number,           // computed not-before (nbf or nowEpoch - skew)
  remaining: Number,           // remaining seconds (>= 0)
  isValid: Boolean,            // true if currently valid (respecting skew)
  aboutToExpire: Boolean       // true if remaining <= threshold
}

/* ---------------- NORMALIZER ----------------
   Convert raw introspection payload into a stable TokenTimeContext.
   Always call this before querying validity/timestamps.
*/
fun fromIntrospect(resp: IntrospectResponse): TokenTimeContext =
  {
    active: resp.active default false,
    exp: (resp.exp default null) as Number | Null,
    iat: (resp.iat default null) as Number | Null,
    nbf: (resp.nbf default null) as Number | Null,
    scope: (resp.scope default null) as String | Null,
    username: (resp.username default null) as String | Null,
    sub: (resp.sub default null) as String | Null,
    token_type: (resp.token_type default null) as String | Null,
    session_type: (resp.session_type default null) as String | Null
  }

/* ---------------- DATETIME HELPERS ----------------
   Convert epoch seconds to DateTime and back.
*/
fun epochSecondsToDateTime(epochSeconds: Number, zone: String = "UTC"): DateTime =
  (epochSeconds * 1000) as DateTime { unit: "milliseconds", timezone: zone }

fun dateTimeToEpochSeconds(dt: DateTime): Number =
  dt as Number { unit: "seconds" }

fun expAsDateTime(ctx: TokenTimeContext, zone: String = "UTC"): DateTime | Null =
  if (ctx.exp is Number) epochSecondsToDateTime(ctx.exp as Number, zone) else null

fun iatAsDateTime(ctx: TokenTimeContext, zone: String = "UTC"): DateTime | Null =
  if (ctx.iat is Number) epochSecondsToDateTime(ctx.iat as Number, zone) else null

fun nbfAsDateTime(ctx: TokenTimeContext, zone: String = "UTC"): DateTime | Null =
  if (ctx.nbf is Number) epochSecondsToDateTime(ctx.nbf as Number, zone) else null

/* ---------------- CORE VALIDITY LOGIC (accepts optional nowEpoch) ----------------
   - remainingSeconds(ctx, skewSeconds, nowEpoch)
   - isCurrentlyValid(ctx, skewSeconds, nowEpoch)
   - isAboutToExpire(ctx, threshold, nowEpoch)
   These accept an optional nowEpoch so callers can avoid repeated now() calls.
*/
fun remainingSeconds(ctx: TokenTimeContext, skewSeconds: Number = 0, nowEpoch: Number | Null = null): Number =
  if (!ctx.active or !(ctx.exp is Number))
    0
  else do {
    var nowE = nowEpoch default (now() as Number { unit: "seconds" })
    var expiresAt = ctx.exp as Number
    var remaining = expiresAt - nowE - skewSeconds
    ---
    if (remaining < 0) 0 else remaining
  }

fun isCurrentlyValid(ctx: TokenTimeContext, skewSeconds: Number = 30, nowEpoch: Number | Null = null): Boolean =
  if (!ctx.active or !(ctx.exp is Number))
    false
  else do {
    var nowE = nowEpoch default (now() as Number { unit: "seconds" })
    var notBefore =
      if (ctx.nbf is Number)
        ctx.nbf as Number
      else
        nowE - skewSeconds
    var expiresAt = ctx.exp as Number
    ---
    nowE + skewSeconds >= notBefore and nowE <= (expiresAt - skewSeconds)
  }

fun isAboutToExpire(ctx: TokenTimeContext, thresholdSeconds: Number = 60, nowEpoch: Number | Null = null): Boolean =
  ctx.active and (remainingSeconds(ctx, 0, nowEpoch) <= thresholdSeconds)

/* ---------------- SNAPSHOT (performance optimization) ----------------
   computeSnapshot(ctx, skewSeconds?, thresholdSeconds?, nowEpoch?)
   - Captures now() once and derives frequently-used values.
   - Use this when performing multiple checks for the same context.
*/
fun computeSnapshot(
  ctx: TokenTimeContext,
  skewSeconds: Number = 30,
  thresholdSeconds: Number = 60,
  nowEpoch: Number | Null = null
): TokenSnapshot =
  do {
    var nowE = nowEpoch default (now() as Number { unit: "seconds" })
    var expiresAt = if (ctx.exp is Number) ctx.exp as Number else null
    var notBefore =
      if (ctx.nbf is Number)
        ctx.nbf as Number
      else
        nowE - skewSeconds

    var remaining =
      if (!ctx.active or expiresAt == null)
        0
      else do {
        var rem = (expiresAt as Number) - nowE - skewSeconds
        ---
        if (rem < 0) 0 else rem
      }

    var valid = ctx.active and (expiresAt is Number) and (nowE + skewSeconds >= notBefore) and (nowE <= ((expiresAt default 0) - skewSeconds))
    var about = ctx.active and (remaining <= thresholdSeconds)
    ---
    {
      nowEpoch: nowE,
      expiresAt: expiresAt,
      notBefore: notBefore,
      remaining: remaining,
      isValid: valid,
      aboutToExpire: about
    }
  }

/* ---------------- BUILDER (lean, immutable, production-ready) ----------------
   tokenBuilder(seedCtx?, seedZone?)
   - fromIntrospect(resp) -> new builder seeded with normalized context
   - fromContext(ctx) -> new builder seeded with a TokenTimeContext
   - withZone(zone) -> new builder with timezone for DateTime helpers
   - snapshot(...) -> fast snapshot object (see computeSnapshot)
   - remainingSeconds(...) / isCurrentlyValid(...) / isAboutToExpire(...) -> single-call helpers
   - expAsDateTime(...) / iatAsDateTime(...) / nbfAsDateTime(...) -> DateTime helpers that use builder zone by default
   - build() -> returns the underlying TokenTimeContext (or null)
*/
fun tokenBuilder(seedCtx: TokenTimeContext | Null = null, seedZone: String = "UTC") =
  do {
    fun newBuilder(newCtx: TokenTimeContext | Null, newZone: String) =
      tokenBuilder(newCtx, newZone)

    ---
    {
      // chaining / setup
      fromIntrospect: (resp: IntrospectResponse) -> newBuilder(fromIntrospect(resp), seedZone),
      fromContext: (ctx: TokenTimeContext) -> newBuilder(ctx, seedZone),
      withZone: (z) -> newBuilder(seedCtx, z),

      // terminal / inspection
      build: () -> seedCtx,

      // performance snapshot (preferred when multiple checks are needed)
      snapshot: (skewSeconds = 30, thresholdSeconds = 60, nowEpoch = null) ->
        if (seedCtx is TokenTimeContext) computeSnapshot(seedCtx, skewSeconds, thresholdSeconds, nowEpoch) else null,

      // DateTime conversions (use builder zone unless overridden)
      expAsDateTime: (zone = null) -> if (seedCtx is TokenTimeContext) expAsDateTime(seedCtx, (zone default seedZone)) else null,
      iatAsDateTime: (zone = null) -> if (seedCtx is TokenTimeContext) iatAsDateTime(seedCtx, (zone default seedZone)) else null,
      nbfAsDateTime: (zone = null) -> if (seedCtx is TokenTimeContext) nbfAsDateTime(seedCtx, (zone default seedZone)) else null,

      // single-call helpers (backwards-compatible)
      remainingSeconds: (skewSeconds = 0, nowEpoch = null) -> if (seedCtx is TokenTimeContext) remainingSeconds(seedCtx, skewSeconds, nowEpoch) else 0,
      isCurrentlyValid: (skewSeconds = 30, nowEpoch = null) -> if (seedCtx is TokenTimeContext) isCurrentlyValid(seedCtx, skewSeconds, nowEpoch) else false,
      isAboutToExpire: (thresholdSeconds = 60, nowEpoch = null) -> if (seedCtx is TokenTimeContext) isAboutToExpire(seedCtx, thresholdSeconds, nowEpoch) else false,

      // utility
      toMap: () -> seedCtx default {}
    }
  }


/* ---------------- USAGE EXAMPLES (single-line comments only) ----------------
   1) Basic quick check:
      var b = tokenBuilder().fromIntrospect(introspectResponse)
      b.isCurrentlyValid()          // Boolean
      b.remainingSeconds()          // Number

   2) Fast path (recommended when performing multiple checks):
      var b = tokenBuilder().fromIntrospect(introspectResponse)
      var snap = b.snapshot()       // TokenSnapshot (reads now() once)
      snap.isValid
      snap.remaining
      if (snap.expiresAt is Number) epochSecondsToDateTime(snap.expiresAt, "Asia/Kolkata")

   3) Deterministic unit tests:
      var nowPre = (now() as Number { unit: "seconds" })
      tokenBuilder().fromIntrospect(resp).isCurrentlyValid(30, nowPre)

*/
