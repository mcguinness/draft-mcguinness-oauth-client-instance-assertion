---
title: "Attestation-Based Client Instance Evidence for OAuth 2.0"
abbrev: "oauth-client-instance-attestation-evidence"
category: std

docname: draft-mcguinness-oauth-client-instance-attestation-evidence-latest
submissiontype: IETF
stand_alone: yes
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
keyword:
 - OAuth
 - client instance
 - attestation
 - DPoP

venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "mcguinness/draft-mcguinness-oauth-client-instance-assertion"
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-attestation-evidence.html"

author:
 -
    fullname: Karl McGuinness
    organization: Independent
    email: public@karlmcguinness.com

normative:
  RFC6749:
  RFC7638:
  RFC7800:
  RFC8126:
  RFC8414:
  RFC9449:
  ATTEST-CLIENT-AUTH: I-D.ietf-oauth-attestation-based-client-auth
  CIA-CORE:
    title: "OAuth 2.0 Client Instance Assertion Profile"
    target: https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-assertion.html
    author:
      -
        fullname: Karl McGuinness
    date: 2026-05

--- abstract

This specification defines a composition between OAuth
Attestation-Based Client Authentication and the OAuth 2.0 Client
Instance Assertion specification. An authorization server that
has validated a Client Attestation with a DPoP proof of possession
MAY use that validated material as Client Instance Evidence,
deriving the resource-server-visible instance subject from the
bound DPoP key (or from a deployment-defined mapping) without
requiring a separate Client Instance Assertion.

--- middle

# Introduction

OAuth Attestation-Based Client Authentication
({{ATTEST-CLIENT-AUTH}}) defines how an Attester issues a Client
Attestation JWT that an OAuth client uses to authenticate the client
instance. The proof of possession can be a Client Attestation PoP
JWT or, in DPoP combined mode, a DPoP proof defined by {{RFC9449}};
in combined mode the DPoP public key matches the Client
Attestation's `cnf` key. {{ATTEST-CLIENT-AUTH}} authenticates the
client instance for the purposes of client authentication and does
not specify how that instance identity surfaces to resource servers.

The OAuth 2.0 Client Instance Assertion specification {{CIA-CORE}}
defines how client instance identity is represented in issued
access tokens, via `act.sub` (delegation) or top-level `sub`
(self-acting), and how that representation is sender-constrained
to a key the instance possesses. {{CIA-CORE}} expects the instance
to present a signed Client Instance Assertion.

This specification composes the two. When the client authenticates
with {{ATTEST-CLIENT-AUTH}} using DPoP combined mode, the validated
Client Attestation and DPoP proof already establish a per-instance
binding key and an Attester endorsement. This document defines how
an authorization server (AS) MAY consume that material directly as
the instance evidence required by {{CIA-CORE}}, deriving the
resource-server-visible instance subject from a deployment-defined
mapping or from the JWK thumbprint of the bound DPoP key.

This document does not redefine {{ATTEST-CLIENT-AUTH}} or
{{CIA-CORE}}. It adds one optional processing path inside the AS's
token endpoint, together with one authorization-server metadata
parameter advertising support and one IANA sub-registry for the
instance-subject URNs used under this path.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

This document uses the terms "Client Instance Assertion", "Client
Instance Evidence", "instance issuer", "client instance", and
"OAuth client" as defined in {{CIA-CORE}}. It uses "Client
Attestation", "Client Attestation PoP", and "DPoP combined mode" as
defined in {{ATTEST-CLIENT-AUTH}}.

# Relationship to Other Specifications {#relationships}

This document depends normatively on {{CIA-CORE}} for instance
representation in issued access tokens, sender-constraint binding,
refresh-token semantics, and resource-server processing. It depends
normatively on {{ATTEST-CLIENT-AUTH}} for Client Attestation
validation, including the DPoP combined-mode binding rules.

This document is OPTIONAL. An AS conforming to {{CIA-CORE}} need not
implement this composition; an AS conforming to
{{ATTEST-CLIENT-AUTH}} likewise need not implement it. Support is
advertised via the AS metadata parameter
`client_instance_attestation_evidence_supported`
({{as-metadata}}).

{{ATTEST-CLIENT-AUTH}} additionally defines a Client Attestation
presentation path directly to a resource server (Client Attestation
PoP `aud` = resource identifier). That path is independent of
{{CIA-CORE}}'s access-token surfacing model and is not affected by
this document.

# Attestation-Based Instance Evidence {#attestation-instance-evidence}

An AS that supports {{ATTEST-CLIENT-AUTH}} with a DPoP proof of
possession MAY use the validated Client Attestation and matching DPoP
proof as instance evidence for {{CIA-CORE}} without requiring a
separate Client Instance Assertion. This processing path applies
when both of the following conditions hold:

* the client authenticates using {{ATTEST-CLIENT-AUTH}} and the
  attestation proof of possession is a DPoP proof ({{RFC9449}}); and
* the AS has completed {{ATTEST-CLIENT-AUTH}} validation for the
  request, which under DPoP combined mode includes verifying that
  the DPoP public key matches the Client Attestation JWT `cnf` key.

## Deriving the Instance Subject {#attestation-evidence-subject}

The Client Attestation JWT `sub` identifies the OAuth client under
{{ATTEST-CLIENT-AUTH}} and MUST NOT by itself be used as the
resource-server-visible instance subject under {{CIA-CORE}}. The AS
derives the instance subject from one of the following sources:

1. **Deployment-defined or companion-profile-defined mapping.** If
   the AS or the authenticated client has configured a mapping from
   a Client Attestation claim or out-of-band data to a client
   instance subject, the AS uses the mapped value. The mapped value
   MUST be specific to the client instance rather than to the OAuth
   client as a class. If the mapping also supplies a subject profile,
   that value is used as `sub_profile`; otherwise the AS uses
   `client_instance`. Specifications that define alternative
   mappings (for example, an Attester profile that includes a
   structured instance identifier as a custom Client Attestation
   claim) are companion profiles to this document; they SHOULD
   identify the source of the instance subject unambiguously (a
   specific claim name or out-of-band protocol) and SHOULD specify
   the conditions under which the mapping applies. Such companion
   profiles SHOULD register their subject form in the "OAuth Client
   Instance Derived Subject URN Types" registry
   ({{iana-instance-subject}}) when intended for cross-deployment
   interoperability.

2. **JWK thumbprint of the bound key (`cnf.jkt`).** When no mapping
   is configured, the AS MAY derive the instance subject from the
   JWK thumbprint of the DPoP public key per {{RFC7638}}. Under
   this key-as-name convention, the instance is identified by the
   key it holds. The AS MUST format the derived subject as the URN

   ~~~
   urn:ietf:params:oauth:instance:jkt:<base64url-jkt>
   ~~~

   where `<base64url-jkt>` is the base64url-encoded SHA-256 JWK
   thumbprint of the DPoP public key, computed per {{RFC7638}}, with
   no padding. The URN form ensures cross-AS comparability of
   subjects derived under this fallback. Because the URN carries
   only the bound key thumbprint, two instances belonging to
   different OAuth clients that happen to hold the same DPoP key
   produce identical `sub` values; the access token's `client_id`
   claim disambiguates them, and resource servers consuming
   instance-subject values of this form MUST evaluate the
   `(client_id, sub)` tuple rather than `sub` alone when making
   authorization or audit decisions on instance identity (see the
   Resource Server Processing section of {{CIA-CORE}}). The AS sets
   `sub_profile` to `client_instance`. See
   {{security-attestation-evidence-subject}} for considerations on
   opacity, key rotation, and subject namespacing.

   Under the `cnf.jkt` fallback, the derived instance subject is a
   function of the bound DPoP key; rotating that key changes the
   subject. Refresh tokens issued under {{CIA-CORE}} are bound to
   the original DPoP key (`(iss, sub)` continuity is enforced by
   the Refresh Tokens section of {{CIA-CORE}}); rotating the DPoP
   key invalidates the refresh token. Deployments that require both
   attestation-based evidence and refresh-token continuity across
   DPoP key rotation MUST use a deployment-defined or
   companion-profile-defined mapping (source 1 above) rather than
   the `cnf.jkt` fallback, because a mapping yields a key-
   independent instance subject.

Local AS policy MAY disable the `cnf.jkt` fallback for a client or
deployment that requires a richer instance identifier. When the
fallback is disabled and no mapping is configured, the AS MUST NOT
use the Client Attestation as instance evidence under {{CIA-CORE}}.

## Access Token Representation and Validation {#attestation-evidence-access-token}

When the AS uses attestation-based instance evidence, the derived
instance subject is used as `act.sub` in delegation cases or
top-level `sub` in self-acting cases, per the Access Token
Representation section of {{CIA-CORE}}. The matched DPoP public key
is the instance binding key for {{CIA-CORE}}'s sender-constraint
requirement, and the issued access token MUST be DPoP-bound to that
key.

For delegation cases, the AS MUST set `act.iss` to the issuer
identifier of the validated Client Attestation JWT. For self-acting
cases, the Client Attestation issuer is not represented as a
standard access-token claim; the AS MUST retain it with token state
when needed for revocation, introspection, audit, or issuer-aware
resource-server policy. If resource servers need that issuer context
in self-contained JWT access tokens, the AS SHOULD expose it using a
deployment-specific claim understood by those resource servers.

The Client Instance Assertion validation steps in {{CIA-CORE}} that
depend on a presented assertion -- token-type matching, instance
issuer descriptor lookup, assertion signature verification,
assertion claim validation, assertion `client_id` binding, and
assertion replay checking -- are satisfied by the completed
{{ATTEST-CLIENT-AUTH}} processing and the subject-derivation checks
in {{attestation-evidence-subject}}. Processing then continues with
delegation policy, authorization-time consistency, and instance
binding as described in {{CIA-CORE}}.

Replay protection for this evidence path is provided by
{{ATTEST-CLIENT-AUTH}} validation, including the DPoP proof
freshness rules in {{RFC9449}} Section 4.3 and any Client
Attestation `jti` / `exp` checks defined by
{{ATTEST-CLIENT-AUTH}}. The `(iss, jti)` replay cache defined by
{{CIA-CORE}} does not apply to this path, because there is no
Client Instance Assertion `iss` / `jti` to cache.

Trust for this evidence path is the AS-to-Attester trust used by
{{ATTEST-CLIENT-AUTH}}; the `instance_issuers` metadata defined in
{{CIA-CORE}} is not used for this path unless a companion profile
explicitly says otherwise.

If the AS supports this composition mode but cannot derive an
instance subject (no mapping is configured and the `cnf.jkt`
fallback is not available or has been disabled by local policy),
the AS MUST NOT use the Client Attestation as instance evidence
under this composition. If the request or client policy requires
{{CIA-CORE}}'s instance representation, the AS MUST reject the
request with `invalid_grant`; otherwise it MAY process the request
under {{ATTEST-CLIENT-AUTH}} alone, without applying
{{CIA-CORE}}'s access-token representation.

## Refresh Tokens {#attestation-evidence-refresh}

Refresh tokens issued when the AS uses attestation-based instance
evidence follow the refresh-token rules of {{CIA-CORE}} with the
derived instance subject, the Client Attestation issuer, and the
matched DPoP key recorded as the originating instance state.

The refresh token MUST be sender-constrained to the same DPoP key
used as the instance binding key at original issuance. A refresh
request that presents a fresh {{ATTEST-CLIENT-AUTH}} Client
Attestation and DPoP proof as instance evidence MUST validate under
{{ATTEST-CLIENT-AUTH}}, MUST derive the same instance subject as the
original issuance, and MUST use the same DPoP key to which the
refresh token is bound. If any of these checks fail, the AS MUST
reject the request with `invalid_grant`.

A refresh request MAY omit fresh attestation-based instance evidence
when local policy permits refresh from the stored originating
instance state and the refresh token's sender-constraint proof
validates with the original DPoP key. In that case, refresh does not
introduce a new instance identity; the AS reuses the original
classification, derived instance subject, Client Attestation issuer,
and binding key. A deployment that requires current Attester
endorsement at every refresh MUST require fresh attestation-based
instance evidence on refresh.

## Authorization Server Metadata {#as-metadata}

This document defines the following authorization server metadata
parameter for {{RFC8414}} (see {{iana-as-metadata}}):

`client_instance_attestation_evidence_supported`:
: A boolean indicating whether the AS supports using a validated
  {{ATTEST-CLIENT-AUTH}} Client Attestation and DPoP proof of
  possession as instance evidence under
  {{attestation-instance-evidence}}. An AS that supports this
  composition mode MUST publish this parameter set to `true`.

# Precedence When Both Evidence Sources Are Present {#composition-with-cia}

A client MAY combine {{ATTEST-CLIENT-AUTH}} with an explicit Client
Instance Assertion presented via the `client_instance_assertion`
request parameter of {{CIA-CORE}}. In that deployment the Client
Attestation continues to authenticate the client instance, while
the Client Instance Assertion supplies the
resource-server-visible instance identifier (which can be richer
than the `cnf.jkt` URN form of {{attestation-evidence-subject}},
for example a SPIFFE ID or a workload-identity-issuer-minted
subject). The reason to apply this composition in such a
deployment is the shared-key cross-check defined below: it lets
the AS verify, in one pass, that the key bound by the Attester and
the key bound by the instance issuer are the same instance key.

When a token request presents both attestation-based instance
evidence and a Client Instance Assertion, the Client Instance
Assertion is authoritative for instance identity: the AS MUST
derive `act.sub` (delegation) or top-level `sub` (self-acting)
from the validated Client Instance Assertion per the Access Token
Representation section of {{CIA-CORE}}, not from the attestation
evidence. The {{ATTEST-CLIENT-AUTH}} validation continues to apply
for client authentication. To ensure the two sources name the same
instance, the AS MUST verify that the Client Instance Assertion's
`cnf` and the DPoP key matched against the Client Attestation's
`cnf` per {{ATTEST-CLIENT-AUTH}} identify the same key material:

* if the Client Instance Assertion's `cnf` is `jkt`, the value MUST
  equal the JWK thumbprint ({{RFC7638}}) of the DPoP key;
* the Client Instance Assertion's `cnf` MUST NOT be `x5t#S256` in
  this composition, because the {{ATTEST-CLIENT-AUTH}} DPoP-combined
  mode binds to a JWK and there is no in-band TLS certificate to
  compare against. The AS MUST reject such requests with
  `invalid_grant`.

The Client Instance Assertion `cnf` forms available for this
comparison are the forms permitted by {{CIA-CORE}}; this composition
does not add a new `cnf` confirmation method to Client Instance
Assertions.

If the keys are not the same under the comparison above, the AS
MUST reject the request with `invalid_grant`.

This precedence rule gives clients a deterministic outcome when
both sources are present.

# Error Responses {#errors}

Errors are returned per {{RFC6749}} Section 5.2. This document
uses `invalid_grant` for failures specific to this evidence path:

* the AS cannot derive an instance subject (no mapping is
  configured and the `cnf.jkt` fallback is unavailable or disabled
  by local policy) when {{CIA-CORE}}'s instance representation is
  required ({{attestation-evidence-access-token}});
* the Client Instance Assertion's `cnf` and the Client
  Attestation's bound DPoP key do not identify the same key
  material under the precedence rule in
  {{composition-with-cia}};
* the Client Instance Assertion's `cnf` is `x5t#S256` in the
  combined-mode composition;
* on a refresh request ({{attestation-evidence-refresh}}), a
  presented fresh Client Attestation fails to validate, derives a
  different instance subject from the original issuance, or is
  bound to a different DPoP key than the refresh token.

All other error returns inherit from {{ATTEST-CLIENT-AUTH}} (for
Client Attestation and DPoP validation failures) and from
{{CIA-CORE}} (for the access-token surfacing path this document
feeds into).

# Conformance {#conformance}

An AS conforms to this document by:

* completing the {{ATTEST-CLIENT-AUTH}} processing path for the
  request, including DPoP combined-mode validation per
  {{RFC9449}};
* applying the instance-subject derivation rules in
  {{attestation-evidence-subject}} (deployment-defined mapping,
  or the `cnf.jkt` URN fallback when no mapping is configured and
  local policy has not disabled the fallback);
* binding the issued access token to the same DPoP key per the
  Sender-Constrained Access Tokens section of {{CIA-CORE}};
* representing the instance in the access token per the Access
  Token Representation section of {{CIA-CORE}}, with
  `sub_profile` set to `client_instance` (or to a
  mapping-supplied value);
* applying the refresh-token continuity rules in
  {{attestation-evidence-refresh}};
* applying the precedence rule in {{composition-with-cia}} when a
  Client Instance Assertion is also presented; and
* advertising support via
  `client_instance_attestation_evidence_supported`
  ({{as-metadata}}).

Resource servers consuming tokens issued through the `cnf.jkt`
fallback conform to this document by evaluating the `(client_id,
sub)` tuple (or `(client_id, act.sub)` in delegation cases), rather
than the derived URN alone, when making authorization or audit
decisions on instance identity.

Conformance to this document is OPTIONAL for an AS conforming to
{{CIA-CORE}} or to {{ATTEST-CLIENT-AUTH}}.

# Security Considerations {#security}

This document inherits the security considerations of
{{ATTEST-CLIENT-AUTH}}, {{CIA-CORE}}, and {{RFC9449}}.

## Instance Subject Derived from `cnf.jkt` {#security-attestation-evidence-subject}

When the AS derives the instance subject from `cnf.jkt`
({{attestation-evidence-subject}}), the subject is the URN
`urn:ietf:params:oauth:instance:jkt:<base64url-jkt>` carrying the
base64url-encoded SHA-256 JWK thumbprint of the bound DPoP key.

The thumbprint carries no semantic content beyond uniquely
identifying the bound key. Deployments needing a richer instance
identifier (e.g., for resource-server policy or audit) SHOULD
configure a deployment-defined mapping per
{{attestation-evidence-subject}}.

The derived subject changes when the bound DPoP key rotates.
Refresh tokens issued under {{CIA-CORE}} become unusable when the
bound key changes; deployments requiring both DPoP key rotation
and refresh-token continuity MUST use a deployment-defined mapping
rather than the `cnf.jkt` fallback.

Two different clients whose instances happen to use the same DPoP
key produce identical URN values; resource servers MUST evaluate
the `(client_id, sub)` tuple, or `(client_id, act.sub)` for
delegation tokens, rather than the derived URN alone when making
authorization decisions on instance identity. Deployments whose
resource servers or audit pipelines key principally on `sub` SHOULD
use a deployment-defined mapping instead of the `cnf.jkt` fallback.

A client whose access tokens are issued through both this fallback
and a workload-identity Client Instance Assertion path will have
heterogeneous `sub` shapes (the URN form here versus, e.g., a
SPIFFE ID elsewhere); deployments needing a uniform `sub` shape
SHOULD configure a deployment-defined mapping per
{{attestation-evidence-subject}}.

The `cnf.jkt` URN is stable for the lifetime of the bound DPoP key
and is visible to every resource server that consumes an access
token derived through this fallback. Compared to a SPIFFE ID or a
workload-identity-issuer-minted subject, it is opaque (no encoded
deployment topology), but it is also durable per-instance and
linkable across requests for as long as the key lives. Resource
servers and audit pipelines that record `sub` for non-authorization
purposes (analytics, billing, correlation) inherit the per-instance
linkability that goes with this fallback. Deployments that need a
shorter linkability window SHOULD rotate the bound DPoP key on a
schedule matching their privacy or anti-tracking requirements, or
configure a deployment-defined mapping that produces non-durable
identifiers.

## Shared Trust Root with Attestation-Based Client Authentication {#security-shared-trust-root}

Under this composition, the AS-to-Attester trust relationship that
authenticates the client instance for {{ATTEST-CLIENT-AUTH}} also
underpins the instance identity surfaced to resource servers.
Compromise of the Attester's signing key therefore affects both the
client-authentication assurance of {{ATTEST-CLIENT-AUTH}} and the
instance-identity assurance of {{CIA-CORE}}. Operators SHOULD
evaluate Attester custody, lifecycle, and rotation accordingly,
and SHOULD ensure incident-response procedures for an Attester
compromise cover access-token revocation under both specifications.

# IANA Considerations {#iana}

## OAuth Client Instance Derived Subject URN Types {#iana-instance-subject}

IANA is requested to create a new sub-registry titled "OAuth Client
Instance Derived Subject URN Types" under the "OAuth Parameters"
registry group established by {{RFC6749}}. Registration policy is
Specification Required {{RFC8126}}.

A Client Instance Subject Type identifies a syntactic form for the
`sub` value (or `act.sub` in delegation cases) of access tokens
issued under {{CIA-CORE}} when the instance subject is derived
without a deployment-defined mapping
({{attestation-evidence-subject}}). The URN form
`urn:ietf:params:oauth:instance:<type>:<value>` encodes a subject of
the registered type; the `<value>` syntax is defined by the
registering specification. This registry covers the token-side
identifier; the related descriptor-side identifier (the
`subject_syntax` member of an instance issuer descriptor in
{{CIA-CORE}}) is covered by the separate "OAuth Client Instance
Subject Syntaxes" sub-registry established by {{CIA-CORE}}.

Registry fields:

Type Identifier:
: A short label used as the `<type>` component of the URN. ABNF:
  1*( ALPHA / DIGIT / "-" ).

Value Syntax:
: The syntax of the `<value>` portion of the URN, defined by the
  registering specification.

Common Name:
: A short, human-readable name for the subject type.

Change Controller:
: As required by Specification Required policy.

Specification Document(s):
: The defining specification.

IANA is requested to register the following initial value:

Type Identifier:
: `jkt`

Value Syntax:
: The base64url-encoded SHA-256 JWK thumbprint ({{RFC7638}}) of the
  instance's bound DPoP key, with no padding.

Common Name:
: JWK Thumbprint (DPoP-bound instance key)

Change Controller:
: IETF

Specification Document(s):
: {{attestation-evidence-subject}} of this document

The URN form for this type is
`urn:ietf:params:oauth:instance:jkt:<base64url-jkt>`. It is used as
the `sub` value of access tokens issued under the `cnf.jkt`
fallback path in {{attestation-evidence-subject}}.

## OAuth Authorization Server Metadata {#iana-as-metadata}

IANA is requested to register the following parameter in the "OAuth
Authorization Server Metadata" registry established by {{RFC8414}}.
The Change Controller is IETF.

Metadata Name:
: `client_instance_attestation_evidence_supported`

Metadata Description:
: Boolean indicating whether the AS supports using a validated
  {{ATTEST-CLIENT-AUTH}} Client Attestation and DPoP proof of
  possession as instance evidence under {{CIA-CORE}}.

Specification Document(s):
: {{as-metadata}} of this document

--- back

# Worked Examples {#appendix-examples}
{:numbered="false"}

The examples share a common deployment:

* OAuth client: `https://app.example.com/agent`
* Attester: `https://attester.app.example.com` (issues Client
  Attestations naming the client)
* AS: `https://as.example.com`
* Resource server: `https://api.example.com`
* The workload holds a DPoP key whose JWK thumbprint is
  `0ZcOCORZNYy...iguA4I`.
* The AS advertises
  `client_instance_attestation_evidence_supported: true`; no
  per-client mapping is configured, so the AS uses the `cnf.jkt`
  URN fallback for instance-subject derivation.

## Client Credentials with `cnf.jkt` Fallback {#appendix-examples-client-credentials}
{:numbered="false"}

The client makes a `client_credentials` request with the
ATTEST-CLIENT-AUTH headers and a DPoP proof, and no
`client_instance_assertion` parameter:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJhbGciOiJFUzI1NiIs...
DPoP: <DPoP proof bound to the workload's instance key>

grant_type=client_credentials
&scope=repo.read
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
~~~

The Client Attestation's `sub` is `https://app.example.com/agent`
(the OAuth client identifier) and its `cnf.jkt` is the JWK
thumbprint of the workload's instance key, matching the DPoP
proof's public key.

AS processing:

1. Validate the Client Attestation and DPoP proof per
   {{ATTEST-CLIENT-AUTH}}, including the `cnf`/DPoP key match.
2. No deployment-defined mapping is configured for this client, so
   the AS derives the instance subject under the `cnf.jkt`
   fallback ({{attestation-evidence-subject}}).
3. The derived URN is
   `urn:ietf:params:oauth:instance:jkt:0ZcOCORZNYy...iguA4I`
   (where the suffix is the base64url SHA-256 thumbprint of the
   DPoP public key).
4. Self-acting classification per {{CIA-CORE}} (no other principal
   under `client_credentials`).
5. Issue a sender-constrained access token bound to the same DPoP
   key.

Issued access token (JWT access-token shape):

~~~ json
{
  "iss":         "https://as.example.com",
  "aud":         "https://api.example.com",
  "sub":         "urn:ietf:params:oauth:instance:jkt:0ZcOCORZNYy...iguA4I",
  "sub_profile": "client_instance",
  "client_id":   "https://app.example.com/agent",
  "scope":       "repo.read",
  "iat":         1770000005,
  "exp":         1770001805,
  "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
}
~~~

A resource server authorizing on instance identity MUST evaluate
the `(client_id, sub)` tuple ({{attestation-evidence-subject}}),
since the URN by itself does not include the OAuth client. If the
workload later rotates its DPoP key, the next access token issued
under the same flow will carry a different `sub` URN; any refresh
token issued under this flow is bound to the original DPoP key and
becomes unusable across that rotation.

## Token-Exchange Variant {#appendix-examples-token-exchange}
{:numbered="false"}

The same workload exchanges an inbound user-delegated
`subject_token` for a downstream-resource token, presenting only
the ATTEST-CLIENT-AUTH material (no Client Instance Assertion).
Under {{CIA-CORE}}'s classification rules the request is
delegation, so the derived URN goes into `act.sub` rather than
top-level `sub`. Because no Client Instance Assertion is
presented, the precedence rule in {{composition-with-cia}} does
not apply.

Token request (abridged):

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJhbGciOiJFUzI1NiIs...
DPoP: <DPoP proof bound to the workload's instance key>

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&audience=https%3A%2F%2Fapi.example.com
&subject_token=eyJhbGciOiJFUzI1NiIs...
&subject_token_type=
  urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aaccess_token
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
~~~

The AS validates the Client Attestation and DPoP proof, derives
the URN subject from `cnf.jkt`, classifies as delegation (per
{{CIA-CORE}}), and issues:

~~~ json
{
  "iss":       "https://as.example.com",
  "aud":       "https://api.example.com",
  "sub":       "user:alice@example.com",
  "client_id": "https://app.example.com/agent",
  "scope":     "repo.write",
  "iat":       1770000010,
  "exp":       1770001810,
  "cnf":       { "jkt": "0ZcOCORZNYy...iguA4I" },
  "act": {
    "iss":         "https://attester.app.example.com",
    "sub":         "urn:ietf:params:oauth:instance:jkt:0ZcOCORZNYy...iguA4I",
    "sub_profile": "client_instance",
    "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
  }
}
~~~

`act.iss` here is the Attester identifier from the validated
Client Attestation; the URN in `act.sub` is the same form as the
self-acting example above.

# Document History
{:numbered="false"}

*RFC EDITOR: please remove this section before publication.*

## -00 {#history-00}
{:numbered="false"}

* Initial publication. The substantive content of this document
  was previously the §Attestation-Based Instance Evidence section
  (and its security and IANA subsections) of
  draft-mcguinness-oauth-client-instance-assertion-01; the split
  is editorial -- the composition is OPTIONAL to either core
  spec.
* Defines a precedence rule for token requests that present both
  attestation-based evidence and an explicit Client Instance
  Assertion: the Client Instance Assertion is authoritative for
  instance identity, and the AS MUST verify the two evidence
  sources name the same binding key.
* Establishes the IANA "OAuth Client Instance Derived Subject URN
  Types" sub-registry (Specification Required), seeded with
  `jkt`, and the AS metadata parameter
  `client_instance_attestation_evidence_supported`.
* The composition references to {{ATTEST-CLIENT-AUTH}} match the
  semantics of that document at the time of writing; subsequent
  revisions of {{ATTEST-CLIENT-AUTH}} that change DPoP-combined-
  mode validation, the location of the bound key (`cnf`), or the
  Attester's `sub` semantics may require corresponding updates to
  this document.

# Acknowledgments
{:numbered="false"}

The author thanks participants in the OAuth Working Group for
discussions on workload identity, attestation, and the composition
between client-instance authentication and instance-identity
surfacing that motivated this companion document.
