%dw 2.0

// ================= TYPES =================
type OAuthTokenResponseType = {
    access_token: String,
    token_type?: String,
    issued_at?: String | Number,
    instance_url?: String,
    id?: String,
    signature?: String
}

type IntrospectResponseType = {
    active: Boolean,
    scope?: String | Null,
    client_id?: String | Null,
    username?: String | Null,
    sub?: String | Null,
    token_type?: String | Null,
    session_type?: String | Null,
    exp?: Number | Null,
    iat?: Number | Null,
    nbf?: Number | Null
}

type TokenContextType = {
    access_token: String,
    token_type: String | Null,
    issued_at: Number | Null,
    instance_url: String | Null,
    id: String | Null,
    signature: String | Null,
    active: Boolean,
    scope: String | Null,
    client_id: String | Null,
    username: String | Null,
    sub: String | Null,
    introspect_token_type: String | Null,
    session_type: String | Null,
    exp: Number | Null,
    iat: Number | Null,
    nbf: Number | Null
}

// ================= BUILDER TYPES =================
type WithIntrospectStepType = {
    withIntrospect: (IntrospectResponseType) -> TokenContextBuilderType,
    build: () -> TokenContextType
}

type WithTokenStepType = {
    withOAuthToken: (OAuthTokenResponseType) -> TokenContextBuilderType,
    build: () -> TokenContextType
}

type TokenContextBuilderType = {
    isCurrentlyValid: (Number) -> Boolean,
    remainingSeconds: (Number) -> Number,
    isAboutToExpire: (Number) -> Boolean,
    expAsDateTime: (String) -> DateTime | Null,
    build: () -> TokenContextType
}

// ================= BUILDER FUNCTIONS =================

/**
 * Start from OAuth token response (your sf token response example)
 */
fun fromOAuthToken(tokenResp: OAuthTokenResponseType): WithIntrospectStepType =
    createWithIntrospectStep({
        access_token: tokenResp.access_token,
        token_type: tokenResp.token_type default null,
        issued_at: (tokenResp.issued_at default null) as Number | Null,
        instance_url: tokenResp.instance_url default null,
        id: tokenResp.id default null,
        signature: tokenResp.signature default null,
        active: false,
        scope: null,
        client_id: null,
        username: null,
        sub: null,
        introspect_token_type: null,
        session_type: null,
        exp: null,
        iat: null,
        nbf: null
    })

/**
 * Start from Introspect response (your sf introspect response example)
 */
fun fromIntrospect(introspectResp: IntrospectResponseType): WithTokenStepType =
    createWithTokenStep({
        active: introspectResp.active default false,
        scope: introspectResp.scope default null,
        client_id: introspectResp.client_id default null,
        username: introspectResp.username default null,
        sub: introspectResp.sub default null,
        introspect_token_type: introspectResp.token_type default null,
        session_type: introspectResp.session_type default null,
        exp: introspectResp.exp default null,
        iat: introspectResp.iat default null,
        nbf: introspectResp.nbf default null,
        access_token: "",
        token_type: null,
        issued_at: null,
        instance_url: null,
        id: null,
        signature: null
    })

fun createWithIntrospectStep(ctx: TokenContextType): WithIntrospectStepType = {
    withIntrospect: (introspectResp) -> createTokenContextBuilder({
        access_token: ctx.access_token,
        token_type: ctx.token_type,
        issued_at: ctx.issued_at,
        instance_url: ctx.instance_url,
        id: ctx.id,
        signature: ctx.signature,
        active: introspectResp.active default false,
        scope: introspectResp.scope default null,
        client_id: introspectResp.client_id default null,
        username: introspectResp.username default null,
        sub: introspectResp.sub default null,
        introspect_token_type: introspectResp.token_type default null,
        session_type: introspectResp.session_type default null,
        exp: introspectResp.exp default null,
        iat: introspectResp.iat default null,
        nbf: introspectResp.nbf default null
    }),
    build: () -> ctx
}

fun createWithTokenStep(ctx: TokenContextType): WithTokenStepType = {
    withOAuthToken: (tokenResp) -> createTokenContextBuilder({
        access_token: tokenResp.access_token,
        token_type: tokenResp.token_type default null,
        issued_at: (tokenResp.issued_at default null) as Number | Null,
        instance_url: tokenResp.instance_url default null,
        id: tokenResp.id default null,
        signature: tokenResp.signature default null,
        active: ctx.active default false,
        scope: ctx.scope default null,
        client_id: ctx.client_id default null,
        username: ctx.username default null,
        sub: ctx.sub default null,
        introspect_token_type: ctx.introspect_token_type default null,
        session_type: ctx.session_type default null,
        exp: ctx.exp default null,
        iat: ctx.iat default null,
        nbf: ctx.nbf default null
    }),
    build: () -> ctx
}

/**
 * Convenience: Combine both in one call
 */
fun combineTokenAndIntrospect(tokenResp: OAuthTokenResponseType, introspectResp: IntrospectResponseType): TokenContextBuilderType =
    fromOAuthToken(tokenResp).withIntrospect(introspectResp)

/**
 * From stored Object Store TokenContext (for validation)
 */
fun fromStoredContext(storedCtx: TokenContextType): TokenContextBuilderType =
    createTokenContextBuilder(storedCtx)

fun createTokenContextBuilder(ctx: TokenContextType): TokenContextBuilderType = {
    isCurrentlyValid: (skewSeconds = 30) -> 
        if (!ctx.active or !(ctx.exp is Number))
            false
        else do {
            var nowEpoch = now() as Number { unit: "seconds" }
            var notBefore = (ctx.nbf default nowEpoch) as Number
            var expiresAt = ctx.exp as Number
            ---
            nowEpoch + skewSeconds >= notBefore and nowEpoch <= (expiresAt - skewSeconds)
        },
    remainingSeconds: (skewSeconds = 0) ->
        if (!ctx.active or !(ctx.exp is Number))
            0
        else do {
            var nowEpoch = now() as Number { unit: "seconds" }
            var expiresAt = ctx.exp as Number
            var remaining = expiresAt - nowEpoch - skewSeconds
            ---
            if (remaining < 0) 0 else remaining
        },
    isAboutToExpire: (thresholdSeconds = 60) ->
        ctx.active and (createTokenContextBuilder(ctx).remainingSeconds(0) <= thresholdSeconds),
    expAsDateTime: (zone = "UTC") ->
        if (ctx.exp is Number)
            (ctx.exp * 1000) as DateTime { unit: "milliseconds", timezone: zone }
        else null,
    build: () -> ctx
}
