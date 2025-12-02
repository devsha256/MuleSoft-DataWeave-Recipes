%dw 2.0

// ================= TYPES =================

// Raw Salesforce introspection (success)
type IntrospectSuccess = {
    active: Boolean,
    scope?: String | Null,
    username?: String,
    sub?: String,
    token_type?: String,
    session_type?: String,
    exp?: Number,
    iat?: Number,
    nbf?: Number
}

// Raw Salesforce introspection (success or invalid)
type IntrospectResponse = {
    active: Boolean,
    scope?: String | Null,
    username?: String,
    sub?: String,
    token_type?: String,
    session_type?: String,
    exp?: Number | Null,
    iat?: Number | Null,
    nbf?: Number | Null
}

// Normalized context used by the builder / chain functions
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

// =============== BUILDER ENTRY ===============

/**
 * Builder entry: from raw Salesforce introspection response.
 * Handles both success (active=true) and invalid (active=false) cases.
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


// =============== CLAIMS AS DATETIME ===============

/**
 * Convert exp (epoch seconds) to DateTime in given zone.
 */
fun expAsDateTime(ctx: TokenTimeContext, zone: String = "UTC"): DateTime | Null =
    if (ctx.exp is Number)
        (ctx.exp * 1000) as DateTime { unit: "milliseconds", timezone: zone }
    else
        null

/**
 * Convert iat (epoch seconds) to DateTime in given zone.
 */
fun iatAsDateTime(ctx: TokenTimeContext, zone: String = "UTC"): DateTime | Null =
    if (ctx.iat is Number)
        (ctx.iat * 1000) as DateTime { unit: "milliseconds", timezone: zone }
    else
        null

/**
 * Convert nbf (epoch seconds) to DateTime in given zone.
 */
fun nbfAsDateTime(ctx: TokenTimeContext, zone: String = "UTC"): DateTime | Null =
    if (ctx.nbf is Number)
        (ctx.nbf * 1000) as DateTime { unit: "milliseconds", timezone: zone }
    else
        null

// =============== VALIDITY / LIFETIME ===============

/**
 * Remaining validity in seconds (0 if already expired OR inactive OR no exp).
 * Uses exp claim from Salesforce (epoch seconds).
 * skewSeconds lets you subtract a safety margin.
 */
fun remainingSeconds(ctx: TokenTimeContext, skewSeconds: Number = 0): Number =
    if (!ctx.active or !(ctx.exp is Number))
        0
    else do {
        var nowEpoch = now() as Number { unit: "seconds" }
        var expiresAt = ctx.exp as Number
        var remaining = expiresAt - nowEpoch - skewSeconds
        ---
        if (remaining < 0) 0 else remaining
    }

/**
 * Check if token is currently valid:
 *  - active must be true
 *  - now must be >= nbf (if present)
 *  - now must be < exp
 *  - skewSeconds adds clock‑skew/safety margin on both sides
 */
fun isCurrentlyValid(ctx: TokenTimeContext, skewSeconds: Number = 30): Boolean =
    if (!ctx.active or !(ctx.exp is Number))
        false
    else do {
        var nowEpoch = now() as Number { unit: "seconds" }
        var notBefore =
            if (ctx.nbf is Number)
                ctx.nbf as Number
            else
                nowEpoch - skewSeconds
        var expiresAt = ctx.exp as Number
        ---
        nowEpoch + skewSeconds >= notBefore
        and nowEpoch <= (expiresAt - skewSeconds)
    }

/**
 * True if token is active AND its remaining lifetime is within thresholdSeconds.
 * Useful to proactively refresh before expiry.
 */
fun isAboutToExpire(ctx: TokenTimeContext, thresholdSeconds: Number = 60): Boolean =
    ctx.active and (remainingSeconds(ctx, 0) <= thresholdSeconds)

// =============== GENERIC EPOCH HELPERS ===============

/**
 * Convert epoch seconds to DateTime.
 */
fun epochSecondsToDateTime(epochSeconds: Number, zone: String = "UTC"): DateTime =
    (epochSeconds * 1000) as DateTime { unit: "milliseconds", timezone: zone }

/**
 * Convert DateTime to epoch seconds.
 */
fun dateTimeToEpochSeconds(dt: DateTime): Number =
    dt as Number { unit: "seconds" }
