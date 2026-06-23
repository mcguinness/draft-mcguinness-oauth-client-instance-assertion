---
title: "OAuth 2.0 Client Instance Assertion"
abbrev: "oauth-client-instance-assertion"
category: std

docname: draft-mcguinness-oauth-client-instance-assertion-latest
submissiontype: IETF
number:
date: 2026-05-28
v: 3
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
keyword:
 - OAuth
 - CIMD
 - Workload Identity
 - Client Instance
 - SPIFFE
venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "mcguinness/draft-mcguinness-oauth-client-instance-assertion"
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-assertion.html"

author:
 -
    fullname: Karl McGuinness
    organization: Independent
    email: public@karlmcguinness.com

normative:
  RFC6749:
  RFC6755:
  RFC7515:
  RFC7517:
  RFC7518:
  RFC7519:
  RFC7523:
  RFC7591:
  RFC7662:
  RFC7800:
  RFC8126:
  RFC8414:
  RFC8693:
  RFC8705:
  RFC8725:
  RFC9068:
  RFC9449:
  ACTOR-PROFILE: I-D.mcguinness-oauth-actor-profile
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  ENTITY-PROFILES: I-D.mora-oauth-entity-profiles
  SPIFFE-CLIENT-AUTH: I-D.ietf-oauth-spiffe-client-auth

informative:
  RFC7009:
  RFC8037:
  ATTEST-CLIENT-AUTH: I-D.ietf-oauth-attestation-based-client-auth
  WIMSE-ARCH: I-D.ietf-wimse-arch
  WIMSE-CREDS: I-D.ietf-wimse-workload-creds
  SPIFFE:
    title: "SPIFFE: Secure Production Identity Framework For Everyone"
    target: https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/
    author:
      org: SPIFFE
    date: 2024

--- abstract

This specification defines the Client Instance Assertion: a signed
JWT identifying a concrete runtime instance of an OAuth 2.0 client.
It registers the `client_instance_assertion` request parameter for
carrying the assertion at the OAuth 2.0 token endpoint on the
`authorization_code`, `client_credentials`, `refresh_token`, and
JWT bearer (RFC 7523) grants; on the token-exchange grant (RFC
8693), the same assertion is presented as `actor_token` with
`actor_token_type` set to
`urn:ietf:params:oauth:token-type:client-instance-jwt`, also
registered by this specification.

This specification does not introduce a new `client_instance`
identifier in protocol messages. Instead, it defines client
metadata parameters (applicable to clients identified by a Client
ID Metadata Document (CIMD) or registered via OAuth Dynamic Client
Registration (RFC 7591)) that let a `client_id` identify a logical
client whose concrete runtime instances are authenticated by one or
more trusted instance issuers (for example, workload identity
systems).

The Authorization Server validates the instance assertion and
represents the instance either as an `act` claim, when another
principal is present (e.g., a user delegating to the instance), or as
the access token's `sub`, when the instance itself is the principal
(e.g., a client credentials grant). The issued access token is
sender-constrained to a key the instance possesses.


--- middle

# Introduction

OAuth 2.0 {{RFC6749}} defines `client_id` as the identifier of a
client. In deployments where a single OAuth client identifier
represents many short-lived runtime instances, resource servers
and authorization servers need to know not only *which* client
made a request but *which instance* of that client made it.
Instances may be acting on a user's behalf or as the principal
themselves; this specification covers both.

OAuth 2.0 Token Exchange {{RFC8693}} defines the `actor_token` and
`actor_token_type` token request parameters and the `act` claim for
representing an actor in an issued token, scoped to the
token-exchange grant. The OAuth Actor Profile {{ACTOR-PROFILE}}
further constrains the `act` claim and registers actor-related
claims, but explicitly leaves out a token request parameter for
proving an actor in flows other than token exchange.

This document defines a profile for representing client instance
identity at the OAuth 2.0 token endpoint. It:

* Recognizes that an OAuth `client_id` commonly abstracts over many
  concrete runtime instances (a relationship already implicit in
  deployed OAuth practice; see {{client-instance-model}}), and
  defines client metadata describing the *instance issuers* trusted
  to attest those instances. The metadata applies whether
  the client is identified by a Client ID Metadata Document {{CIMD}}
  or registered via {{RFC7591}}; see {{registration-models}}.
* Defines the Client Instance Assertion, a JSON Web Token (JWT)
  {{RFC7519}} signed by an instance issuer published in the client's
  metadata, and registers the `client_instance_assertion` request
  parameter for carrying it at the OAuth 2.0 token endpoint on the
  grants listed in {{permitted-grants}}. On the token-exchange grant
  ({{RFC8693}}), the same assertion is presented as `actor_token`
  with `actor_token_type` set to
  `urn:ietf:params:oauth:token-type:client-instance-jwt`, also
  registered by this profile.
* Requires issued access tokens to be sender-constrained to a key
  the instance possesses, and specifies how the instance
  assertion's `cnf` claim drives that binding in the interoperable
  re-minted assertion format.
* Registers `client_instance_assertion` as a
  `token_endpoint_auth_method` value, allowing deployments without
  an online client-controlled credential to authenticate the client
  via the instance assertion alone.
* Defines first-class support for SPIFFE workload identity, including
  optional direct presentation of JWT-SVIDs without re-minting.
* Defines authorization server metadata so that clients can
  discover support.

What this document does *not* do:

* It does not introduce a `client_instance` identifier parameter
  flowing through the authorization request, token request,
  introspection, or access token (see
  {{rationale-no-instance-identifier}}).
* It does not change the syntax or processing of the `act` claim
  beyond what {{ACTOR-PROFILE}} already defines.
* It does not define authorization endpoint interactions for
  conveying actor identity; like {{ACTOR-PROFILE}}, this is left for
  future work.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

This document uses the following terms:

OAuth Client:
: As defined in {{RFC6749}}, identified by a `client_id` (a CIMD
  URL or a registered `client_id` under {{RFC7591}}; see
  {{registration-models}}). In this profile, the OAuth client
  publishes the set of instance issuers permitted to authenticate
  its runtime instances ({{client-instance-model}}).

Client Instance:
: A concrete runtime of an OAuth client (for example, a particular
  process, container, function invocation, or session). See
  {{client-instance-model}} for the class-and-instance relationship
  between an OAuth client and its instances.

Instance Issuer:
: An authority trusted by the client to authenticate client
  instances and issue instance assertions for those instances. Examples include
  workload identity providers (e.g., a SPIFFE control plane
  {{SPIFFE}}) and platform-managed identity services.

Client Instance Assertion:
: A JWT issued by an instance issuer asserting the identity of a
  client instance, presented at the OAuth 2.0 token endpoint as the
  `client_instance_assertion` request parameter ({{cia-param}}) or,
  on the token-exchange grant, as the `actor_token` parameter with
  `actor_token_type` set to
  `urn:ietf:params:oauth:token-type:client-instance-jwt`
  ({{token-exchange-presentation}}). The terms "Client Instance
  Assertion" and "instance assertion" are used interchangeably in
  prose; "the presented assertion" denotes the JWT carried by either
  parameter, with processing identical in both cases.

Delegation Case:
: A token request whose grant produces a principal distinct from the
  instance presenting the Client Instance Assertion (for example, a
  user under authorization_code or jwt-bearer). The issued access
  token's `sub` is the principal and the instance appears in `act`
  per {{access-token-delegation}}.

Self-Acting Case:
: A token request whose grant produces no principal distinct from
  the instance (notably `client_credentials`). The issued access
  token's `sub` is the instance and `act` is omitted per
  {{access-token-self-acting}}.

# Relationship to Other Specifications {#relationships}

**RFC 8693 (Token Exchange).** On the token-exchange grant the
assertion is presented as `actor_token` with `actor_token_type`
set to `urn:ietf:params:oauth:token-type:client-instance-jwt`,
per {{RFC8693}}'s conventions
({{token-exchange-presentation}}); on the other grants in
{{permitted-grants}} the assertion is the
`client_instance_assertion` request parameter ({{cia-param}}).
The parameter to use is determined by the grant; the assertion
format, validation, sender-constraint, and access-token surfacing
are identical across both paths
({{access-token-classification}}).

**OAuth Actor Profile.** {{ACTOR-PROFILE}} defines the structure of
the `act` claim, the `sub_profile` claim, and nested actor
representation. This document does not redefine those constructs;
it defines how a client instance proves itself at the token
endpoint and how the Authorization Server (AS) represents the
validated assertion in issued access tokens (`act` for delegation,
top-level `sub` for self-acting). Implementations of this document MUST also implement
{{ACTOR-PROFILE}}.

**SPIFFE Client Authentication.** {{SPIFFE-CLIENT-AUTH}} (an OAuth
Working Group document) defines how a SPIFFE workload authenticates
*as the OAuth client itself* using a JWT-SVID or X.509-SVID in
place of a client secret. This document operates at a different
layer (actor / instance identity, not client authentication) and
on different OAuth parameters and trust sources:

| Layer | SPIFFE Client Auth | This document |
| --- | --- | --- |
| What is authenticated | The OAuth client | An actor (instance) acting under an OAuth client |
| Token request parameter | `client_assertion` / `client_assertion_type` | `client_instance_assertion` (or `actor_token` on token-exchange grants) |
| Trust source (client metadata) | SPIFFE bundle endpoint and `spiffe_id` | `instance_issuers` |
| Where the SPIFFE ID surfaces | Validated against `spiffe_id`; not propagated | Surfaced in `act.sub` or top-level `sub` of issued access tokens |

The two specifications are orthogonal and MAY be combined: a
typical combined deployment uses {{SPIFFE-CLIENT-AUTH}} (with a
wildcard `spiffe_id`) to authenticate the OAuth client and this
profile to surface and bind the specific instance. The same SVID
MAY be presented as both `client_assertion` and
`client_instance_assertion` in a single request when both profiles'
audience, client-binding, and sender-constraint requirements are
satisfied. This document does not require SPIFFE; instance issuers
may use any `subject_syntax`, and the client may authenticate via
any registered method. SPIFFE deployments get first-class support
({{instance-issuers}}, {{spiffe-compatibility}}).

**OAuth Attestation-Based Client Authentication.**
{{ATTEST-CLIENT-AUTH}} (an OAuth Working Group document) defines
how a Client Attester issues a Client Attestation JWT that an OAuth
client uses to authenticate the client instance. That specification
authenticates the client instance for the purposes of client
authentication and does not specify how that instance identity
surfaces to resource servers. This profile addresses that
surfacing gap.

| Concern | Attestation-Based Client Auth | This document |
| --- | --- | --- |
| Authenticates the client instance | Yes | Not by itself; consumes a separately registered client authentication method |
| Surfaces instance identity to the access token | Out of scope | `act.sub` (delegation) or top-level `sub` (self-acting) |
| Wire-level presentation | `OAuth-Client-Attestation` plus either `OAuth-Client-Attestation-PoP` or `DPoP` | `client_instance_assertion` form parameter (or `actor_token` on token-exchange grants) |
| Trust anchor | AS-to-Attester trust (deployment-defined) | Per-client `instance_issuers` in client metadata |
| Sender-constraint binding | `cnf` per {{RFC7800}}; PoP via dedicated `-PoP` JWT or DPoP combined mode | `cnf.jkt` or `cnf.x5t#S256` thumbprint |
| Primary motivating context | Mobile/native apps; wallet ecosystems; workload deployments | Agentic workloads, autoscaled services, ephemeral functions, sub-agents; workload identity |

The two specifications are orthogonal: this profile does not
require {{ATTEST-CLIENT-AUTH}} and does not redefine or extend it.
Deployments may combine them by presenting a Client Instance
Assertion alongside a Client Attestation, in which case the Client
Attestation continues to authenticate the client instance for
client-authentication purposes while the Client Instance Assertion
provides this profile's resource-server-visible instance identity.

{{ATTEST-CLIENT-AUTH}} additionally defines a Client Attestation
presentation path directly to a resource server (Client Attestation
PoP `aud` = resource identifier); that path is independent of this
profile's access-token surfacing model.

**WIMSE Workload Credentials.** The IETF WIMSE working group is
defining specifications for workload identity ({{WIMSE-CREDS}},
{{WIMSE-ARCH}}); WIMSE work is in progress. This profile's Client
Instance Assertion is the OAuth-aware projection of the same
workload identity model, carrying OAuth-specific bindings
(`client_id`, `aud`) needed at the OAuth token endpoint. Deployments
holding a WIMSE workload credential, SPIFFE JWT-SVID, Kubernetes
projected service-account token, or other workload credential
SHOULD use the OAuth-aware adapter pattern ({{adoption}}) to mint
a Client Instance Assertion. For sender-constraint, this
profile pins the binding member of `cnf` to `jkt` ({{RFC9449}}) or
`x5t#S256` ({{RFC8705}}); WIMSE-defined binding mechanisms (for
example, a future Workload Proof Token) can be added by a future
specification when those mechanisms reach deployment maturity.

# Client Instance Assertion Request Parameter {#cia-param}

This section defines the `client_instance_assertion` request parameter,
the wire-level mechanism this profile uses to carry a Client Instance
Assertion at the OAuth 2.0 token endpoint on the grant types listed
in {{permitted-grants}}.

The parameter carries the Client Instance Assertion JWT defined in
{{client-instance-jwt}}. The assertion's purpose is to
identify the client instance and bind subsequent proof-of-possession
to the instance's key, independent of how the client itself is
authenticated. Validation, sender-constraint, and access-token
representation rules are defined in {{token-endpoint}}.

On token-exchange grants ({{RFC8693}}), the same assertion is
presented as `actor_token` with `actor_token_type` set to
`urn:ietf:params:oauth:token-type:client-instance-jwt`, per
{{RFC8693}}'s conventions. See {{token-exchange-presentation}}. The
two presentation paths produce identical processing outcomes; the
parameter to use is determined by the grant.

## Permitted Grant Types {#permitted-grants}

The `client_instance_assertion` parameter MAY be presented on the
following token endpoint grant types:

* `authorization_code` ({{RFC6749}})
* `client_credentials` ({{RFC6749}})
* `refresh_token` ({{RFC6749}})
* `urn:ietf:params:oauth:grant-type:jwt-bearer` ({{RFC7523}})

The `client_instance_assertion` parameter MUST NOT be presented on
the token-exchange grant ({{RFC8693}}); on token-exchange grants the
assertion is presented as `actor_token` per
{{token-exchange-presentation}}. An AS MUST reject a token-exchange
request that includes `client_instance_assertion`.

This document does not define behavior for the implicit grant or
for the device authorization grant; specifying those is left to
future work.

## Token-Exchange Presentation {#token-exchange-presentation}

When the grant is token-exchange ({{RFC8693}}), the Client Instance
Assertion is presented as the `actor_token` parameter with
`actor_token_type` set to
`urn:ietf:params:oauth:token-type:client-instance-jwt`. This is the
conventional {{RFC8693}} path; the AS validates the assertion under
the same rules as for the `client_instance_assertion` parameter
({{as-processing}}).

The two parameter names are wire-syntax siblings, not distinct
artifacts: the assertion format ({{client-instance-jwt}}),
validation procedure, sender-constraint binding, and access-token
representation are identical. The grant determines which parameter
name carries the assertion.

In the delegation case under token-exchange, the assertion represents
the actor distinct from the subject named in `subject_token`, which
is the conventional {{RFC8693}} use of `actor_token`. The
self-acting case ({{access-token-self-acting}}) does not arise on
token-exchange, where {{RFC8693}} requires a distinct subject.

# Client Instance Model {#client-instance-model}

A registered OAuth client commonly abstracts over many concrete
runtimes (for example, a single OAuth client identifier representing
an application across iOS, Android, web, and server-side runtimes;
or an agent platform across each running agent or session).
This profile makes that class-and-instance relationship explicit so
each runtime can be named, attested, and bound to access tokens
individually. For agent platforms, a sub-agent spawned by an agent
is represented as a nested actor via token-exchange
({{chain-merging}}).

The remainder of this section covers the architecture
({{architecture}}), registration models ({{registration-models}}),
and trust delegation model ({{trust-model}}).

## Architecture {#architecture}

Three roles cooperate to authenticate a client instance:

| Role | Responsibility |
| --- | --- |
| OAuth Client | Logical OAuth client identified by a `client_id` (CIMD URL or RFC 7591-registered identifier). Publishes the list of trusted instance issuers in its registered client metadata. |
| Instance Issuer | Authenticates concrete runtime instances and issues short-lived JWT instance assertions describing them. |
| Authorization Server (AS) | Authenticates the client per its registered client authentication method; resolves the client metadata (via CIMD dereference or local registration storage); verifies the instance assertion against a trusted instance issuer; mints an access token whose `act` claim or top-level `sub` represents the instance. |

A high-level flow:

~~~ ascii-art
+-----------+ instance assert.+------------+
|  Client   |<----------------|  Instance  |
|  Instance |                 |   Issuer   |
+-----------+                 +------------+
      |
      | token request:
      |  - client authentication (e.g., private_key_jwt)
      |  - client_instance_assertion (instance JWT)
      |    [on token-exchange grants: actor_token /
      |     actor_token_type =
      |     urn:...:client-instance-jwt]
      v
+--------------------+
| Authorization      |  -> resolves client metadata
| Server             |  -> validates the assertion
|                    |  -> issues access token with act or sub
+--------------------+
~~~

When the client registers `token_endpoint_auth_method` =
`client_instance_assertion` ({{instance-assertion-auth}}), the
two trust anchors (client credential and instance issuer)
collapse onto a single artifact: the instance assertion both
authenticates the client (via the client metadata endorsement of
its issuer) and identifies the instance, and the request carries
no separate `client_assertion`.

## Client Registration Models {#registration-models}

This profile applies to OAuth clients regardless of how their
metadata is registered with the AS. For most existing OAuth
deployments, this means RFC 7591-style static registration
administered by the AS operator (whether via the dynamic
registration endpoint or pre-registered out of band); CIMD is the
more recent option that adds public discovery and cross-organization
auditability where those are required. The descriptor format and
processing rules are identical in both cases.

Static registration ({{RFC7591}}):
: The `client_id` is opaque or AS-assigned. Metadata is registered
  via the dynamic registration endpoint or out of band, and stays
  internal to the AS. Updates take effect when the registration
  store is updated. This model integrates with existing RFC
  7591-based registration toolchains and is the typical mode for
  closed or managed deployments where the trust relationship does
  not need to be publicly discoverable.

Client ID Metadata Document ({{CIMD}}):
: The `client_id` is an HTTPS URL that dereferences to a metadata
  document. The AS fetches the document on demand and caches it;
  updates take effect after the cache window expires (or upon
  explicit re-fetch). This model suits cross-organization
  deployments where the trust relationship between the OAuth
  client and its instance issuers must be auditable in a publicly
  resolvable document, and is operationally easier for
  cross-organization
  SPIFFE federation ({{cross-org-federation}}) because the foreign
  organization can publicly publish its bundle endpoint and instance
  descriptors. Under static registration, equivalent federation
  requires manual coordination of registration between
  organizations.

The descriptor format ({{instance-issuers}}), the instance-assertion
auth mode ({{instance-assertion-auth}}), the SPIFFE compatibility
features ({{spiffe-compatibility}}), and the AS processing rules
({{as-processing}}) all apply uniformly to both models. The only
deployment-time differences are how metadata updates propagate (cache
TTL versus admin update) and whether the trust relationship is
publicly discoverable.

## Trust Delegation Model {#trust-model}

This profile defines a three-party trust delegation between the
client, the instance issuer, and the AS. The client
*delegates* attestation of its runtime instances to one or more
instance issuers; the AS *relies on* that delegation as expressed
in the client's registered metadata.

### Delegation by the OAuth Client {#trust-model-delegation}

By listing an instance issuer in its `instance_issuers` metadata
({{instance-issuers}}), a client delegates to that issuer the
authority to attest that a concrete runtime is an instance of the
client. The descriptor bounds the delegation: `trust_domain`,
`subject_syntax`, `spiffe_id`, and `signing_alg_values_supported`
constrain what the issuer may assert and what the AS will accept
({{instance-issuers}}). The issuer's per-client minting obligations
are in {{issuer-obligations}}; client-side guidance on choosing
issuers is in {{security-trust-model}}.

The per-client minting requirement (an issuer mints assertions
naming a given `client_id` only for runtimes authorized as
instances of that client) prevents cross-client instance
impersonation when the same instance issuer is listed by multiple
OAuth clients.

Because the `instance_issuers` listing endorses the issuer to mint
tokens naming this `client_id`, an instance assertion signed by
such an issuer is itself attributable to the client. This makes the
assertion usable as the client credential under
{{instance-assertion-auth}}.

### Authority of the Authorization Server {#trust-model-as}

The AS treats the registered `instance_issuers` list as
authoritative: it derives its trust in an instance assertion solely
from the descriptor whose issuer member matches the instance
assertion's `iss` claim. AS-side configuration that augments or
overrides the registered list (for example, an AS-operator-managed
allow-list of additional instance issuers) is out of scope for
this document. Deployments that introduce such configuration
SHOULD document the resulting trust model and ensure it is
consistent with the per-client trust the registered metadata
expresses; in particular, AS-side issuer additions weaken the
client's ability to audit who can act on its behalf.

### Trust Lifecycle {#trust-lifecycle}

The trust relationship between client and instance issuer is
mutable. When the client's metadata changes (for example, an
instance issuer is removed, its `jwks_uri` or `jwks` rotates, its
`trust_domain` or `spiffe_id` is replaced, or its
`signing_alg_values_supported` narrows), updates take effect
according to the registration model: for CIMD, the AS applies the
same freshness and re-fetch rules it applies to other
CIMD-published trust material such as `jwks_uri` (see {{CIMD}});
for static registration, updates take effect when the AS's
registration store is updated and re-read.

While the AS may continue to honor a stale descriptor within the
propagation window, this profile imposes no additional revocation
requirement on previously issued access tokens. AS treatment of
access tokens whose validated instance identity is no longer
endorsed after the update is governed by {{revocation}}; sizing
the resulting trust-withdrawal latency is in
{{security-trust-withdrawal-latency}}.

### Cross-Organization Federation {#cross-org-federation}

A client MAY list instance issuers operated by a different
organization, including cases where SPIFFE trust domains differ.
The per-client minting rule ({{trust-model-delegation}}) applies
unchanged. For SPIFFE cross-trust-domain deployments, the
descriptor's `spiffe_bundle_endpoint` MUST be operated by the
foreign organization or its delegate.

# Metadata and Discovery {#metadata}

This section defines client metadata used to delegate instance
attestation and authorization server metadata used by clients to
discover support.

## Client Metadata Extensions {#client-metadata}

This document defines client metadata parameters describing the
trust relationship between a client and the instance issuers
that authenticate its runtime instances. These parameters are
registered in the OAuth Dynamic Client Registration Metadata
registry ({{iana-client-metadata}}) and apply to clients regardless
of how their metadata reaches the AS:

* For clients identified by a Client ID Metadata Document {{CIMD}},
  these parameters appear in the CIMD document and the AS resolves
  them by dereferencing the CIMD URL.
* For clients registered via OAuth Dynamic Client Registration
  {{RFC7591}} (or admin-registered with RFC 7591-shaped metadata),
  these parameters appear in the registered client metadata stored
  by the AS.

The descriptor format and processing rules are identical in both
cases. {{registration-models}} discusses the trade-offs between the
two registration models.

### instance_issuers {#instance-issuers}

OPTIONAL. A non-empty JSON array of *instance issuer descriptor*
objects. Each descriptor declares an issuer that the client
trusts to authenticate its instances. If this parameter is absent,
or is present as an empty array, the AS MUST NOT accept instance assertions
of type `urn:ietf:params:oauth:token-type:client-instance-jwt` for this
client; the AS SHOULD treat an empty array as a metadata error and
log it for the client operator.

The set of accepted instance issuers for a given `client_id` is a
trust boundary: any listed issuer can mint assertions that the AS
accepts under this client. Deployments that place workloads
belonging to distinct organizations or tenants under a single
`client_id` should consult {{security-multi-tenancy}} for the
trust-aggregation implications.

An instance issuer descriptor has the following members:

issuer (REQUIRED):
: A StringOrURI {{RFC7519}} identifying the instance issuer. This
  value MUST exactly match the `iss` claim of accepted instance
  assertions and MUST be unique within the `instance_issuers` array.

  For raw JWT-SVID compatibility ({{spiffe-compatibility}}), this
  value is the SPIFFE JWT-SVID issuer for the trust domain. For
  re-minted Client Instance Assertions, this value identifies the
  OAuth-aware adapter or instance issuer that signed the assertion;
  `trust_domain` and `spiffe_id` then bound the SPIFFE subject
  space that issuer is allowed to assert.

A descriptor MUST contain exactly one of `jwks_uri`, `jwks`, and
`spiffe_bundle_endpoint`. If two or more are present, or all are
absent, the AS MUST reject the descriptor as invalid client metadata.

`jwks_uri`:
: An HTTPS URL of a JWK Set {{RFC7517}} containing the public keys
  used to verify signatures of instance assertions issued by this issuer.

`jwks`:
: An inline JWK Set serving the same purpose as `jwks_uri`.

`spiffe_bundle_endpoint`:
: An HTTPS URL of a SPIFFE trust bundle endpoint {{SPIFFE}} from
  which the AS resolves verification keys for instance assertions
  issued by this issuer. When present, `subject_syntax` MUST be
  "spiffe", and the AS MUST validate assertions from this issuer
  under SPIFFE semantics: it MUST treat the assertion as a SPIFFE
  JWT-SVID (or a re-minted Client Instance Assertion signed with
  a key distributed in the SPIFFE bundle) and apply the
  validation rules of {{spiffe-compatibility}}.

  This descriptor field is intended for JWT-SVID validation and for
  other assertions signed with keys distributed in the SPIFFE
  bundle for the relevant trust domain. OAuth-aware adapters that
  sign re-minted Client Instance Assertions with separate OAuth
  signing keys use `jwks_uri` or `jwks` instead.

  Bundle endpoint format and resolution rules are governed by
  SPIFFE; see {{SPIFFE-CLIENT-AUTH}} for the analogous use in
  client authentication.

`signing_alg_values_supported` (OPTIONAL):
: A JSON array of JSON Web Signature (JWS) {{RFC7515}} `alg` values the AS accepts for
  instance assertions issued by this issuer. If present, the AS MUST
  reject instance assertions whose `alg` is not listed. Issuers SHOULD
  publish only algorithms they actually use.

`subject_syntax` (OPTIONAL):
: A short identifier indicating the syntactic profile of the `sub`
  claim used by this issuer. This document defines two values: "uri"
  (default, arbitrary StringOrURI) and "spiffe" (a SPIFFE ID
  {{SPIFFE}}; see also {{SPIFFE-CLIENT-AUTH}} for the related
  SPIFFE-based client authentication profile). An AS that does not
  understand the value MUST reject instance assertions for that
  descriptor with `invalid_grant`.

`trust_domain` (OPTIONAL):
: When `subject_syntax` is "spiffe", a SPIFFE trust domain that the
  `sub` claim MUST belong to. The AS MUST reject any instance
  assertion whose `sub` does not lie within this trust domain.

  A SPIFFE ID lies within a trust domain only when it parses as a
  valid SPIFFE ID whose trust-domain component exactly equals
  `trust_domain`; ASes MUST NOT use case folding, Unicode
  normalization, or percent-decoding to make a non-matching trust
  domain match.

  `trust_domain` is meaningful only when `subject_syntax` is
  "spiffe"; an AS MUST ignore `trust_domain` in descriptors whose
  `subject_syntax` is any other value. A descriptor's
  `trust_domain` is independent of any SPIFFE trust domain
  associated with the client itself under {{SPIFFE-CLIENT-AUTH}};
  the two MAY differ.

`spiffe_id` (OPTIONAL):
: When `subject_syntax` is "spiffe", a SPIFFE ID that further
  bounds which workloads this issuer may attest as instances of
  this client. The value is a SPIFFE ID, optionally with a trailing
  "/*" wildcard.

  Without "/*", the instance assertion's `sub` MUST equal this
  value exactly; with "/*", matching follows the `spiffe_id`
  matching rule of {{SPIFFE-CLIENT-AUTH}}. If both `spiffe_id` and
  `trust_domain` are present, the trust domain in `spiffe_id` MUST
  equal `trust_domain`.

  When present, this member structurally binds a workload subtree
  to this client; see {{spiffe-client-id-omission}}. If
  `subject_syntax` is "spiffe" and `spiffe_id` is absent,
  `trust_domain` MUST be present and the descriptor delegates the
  entire trust domain to this instance issuer.

  Clients SHOULD include `spiffe_id`; omitting it is appropriate
  only when every workload in the SPIFFE trust domain is authorized
  to act as an instance of the client.

Example client metadata document with a SPIFFE instance issuer:

~~~ json
{
  "client_id": "https://app.example.com/agent",
  "jwks_uri": "https://app.example.com/agent/jwks.json",
  "token_endpoint_auth_method": "private_key_jwt",
  "instance_issuers": [
    {
      "issuer": "https://workload.app.example.com",
      "jwks_uri": "https://workload.app.example.com/jwks.json",
      "subject_syntax": "spiffe",
      "trust_domain": "app.example.com",
      "spiffe_id": "spiffe://app.example.com/agent/*",
      "signing_alg_values_supported": ["ES256"]
    }
  ]
}
~~~

## Authorization Server Metadata {#as-metadata}

This document defines the following AS metadata parameters for
{{RFC8414}} (see {{iana-as-metadata}}):

`client_instance_assertion_supported`:
: A boolean indicating whether the AS supports the
  `client_instance_assertion` request parameter ({{cia-param}}) on
  the grants listed in {{permitted-grants}}. An AS implementing this
  profile MUST publish this parameter set to `true`. Clients use it
  to decide whether to assemble token requests carrying a Client
  Instance Assertion on non-token-exchange grants. This signal is
  intentionally coarse: it does not describe grant-specific
  enablement, raw JWT-SVID support, accepted sender-constraint
  methods, refresh-token behavior, or client-specific registration
  policy. Clients may still need registration-time or deployment
  agreement with the AS for those details.

`actor_token_types_supported`:
: A JSON array of `actor_token_type` values supported by the AS on
  the token-exchange grant ({{RFC8693}}). An AS implementing this
  profile that supports the token-exchange presentation
  ({{token-exchange-presentation}}) MUST publish this parameter and
  include `urn:ietf:params:oauth:token-type:client-instance-jwt` in
  it. Other values MAY appear and are processed under their own
  specifications; their trust resolution is not via
  `instance_issuers`.

In addition, an AS that supports {{instance-assertion-auth}} MUST
advertise `client_instance_assertion` in
`token_endpoint_auth_methods_supported` ({{RFC8414}}).

Example AS metadata document (abridged):

~~~ json
{
  "issuer": "https://as.example.com",
  "token_endpoint": "https://as.example.com/token",
  "client_instance_assertion_supported": true,
  "token_endpoint_auth_methods_supported": [
    "private_key_jwt",
    "client_instance_assertion",
    "attest_jwt_client_auth"
  ],
  "actor_token_types_supported": [
    "urn:ietf:params:oauth:token-type:client-instance-jwt"
  ],
  "dpop_signing_alg_values_supported": ["ES256", "RS256"]
}
~~~

# Client Instance Assertion Format {#client-instance-jwt}

This section defines the format of the Client Instance Assertion,
the signed JWT this profile uses to identify a client instance at
the OAuth 2.0 token endpoint.

A *Client Instance Assertion* is a JWT {{RFC7519}} that asserts the
identity of a client instance. It is presented as the
`client_instance_assertion` request parameter on the grants listed
in {{permitted-grants}} ({{cia-param}}), or as the `actor_token`
parameter with `actor_token_type` set to
`urn:ietf:params:oauth:token-type:client-instance-jwt` (see
{{iana-token-type}}) on the token-exchange grant
({{token-exchange-presentation}}). The assertion serves two
purposes: it authenticates the runtime instance (workload identity),
and it
asserts that the instance is a member of the named OAuth client.
This document defines a single JWT carrying both, signed by the
instance issuer. This matches the prevailing pattern in workload
identity systems, which already issue audience-scoped, signed
assertions of runtime identity (e.g., JWT-SVIDs in {{SPIFFE}}).

## Issuer Obligations {#issuer-obligations}

The instance issuer is the trust authority for the assertion and
MUST, before minting an instance assertion under this profile:

* Authenticate the runtime instance (e.g., via attestation,
  platform-level identity, or possession of an instance key); and
* Verify, under issuer-side policy, that the runtime is permitted
  to claim the `client_id` named in the token. This typically
  means the runtime is operationally part of the client's
  deployment. An instance issuer MUST refuse to mint an instance
  assertion whose `client_id` claim names a client for which the
  runtime has not been authorized, by issuer-side policy, as a
  member.

An instance issuer MUST NOT reassign an active or audit-relevant
`sub` value to a different runtime. Issuers SHOULD use stable,
non-reassigned subjects, or include sufficient generation or
session uniqueness in `sub` to distinguish runtime incarnations.
If subject reassignment is unavoidable, the client, issuer, and AS
audit logs need enough lifecycle metadata to distinguish the old
and new runtimes.

How the issuer internally authenticates the runtime is out of
scope. Common deployment patterns (adapter, raw JWT-SVID
compatibility, X.509-SVID binding) are described in {{adoption}}.

## JWT Claims {#claims}

The following claims are defined for client instance assertions.

`iss` (REQUIRED):
: The instance issuer identifier. MUST exactly match an issuer
  member of an `instance_issuers` descriptor in the client's
  registered metadata.

`sub` (REQUIRED):
: The identifier of the client instance, in the syntax declared by
  the descriptor's `subject_syntax` (default: arbitrary StringOrURI).
  Sub-uniqueness considerations for self-acting tokens are addressed
  in {{access-token-self-acting}}.

`aud` (REQUIRED):
: The intended audience, identifying the AS. The AS validates `aud`
  per {{RFC7523}} Section 3, accepting its own issuer identifier or
  token endpoint URL; if multiple values are present, at least one
  MUST match.

  Each AS SHOULD specify a single canonical `aud` format (typically
  its issuer identifier) and document it; instance issuers SHOULD
  use that canonical form. Where instance assertions are scoped per
  AS, instance issuers SHOULD mint an AS-specific instance assertion
  rather than a multi-`aud` JWT, to limit the replay surface.

`client_id` (REQUIRED unless the SPIFFE compatibility conditions of {{spiffe-client-id-omission}} are met):
: The `client_id` of the client to which this instance belongs.
  This claim uses the JWT `client_id` claim defined in
  {{RFC8693}} Section 4.3.

  The claim binds the actor token to a specific client and is not
  part of the actor's identity (per {{ACTOR-PROFILE}}, `client_id`
  identifies an OAuth client, not an actor). When present, the AS
  MUST reject the token if this value does not exactly equal the
  `client_id` of the authenticated client.

  When omitted under {{spiffe-client-id-omission}}, the binding is
  established structurally by the matched descriptor's SPIFFE scope
  (`spiffe_id` when present, otherwise `trust_domain`) rather than
  by a JWT claim, and a SPIFFE JWT-SVID may be presented as the
  Client Instance Assertion directly without re-minting.

`exp` (REQUIRED):
: Expiration time. Issuers SHOULD set short lifetimes (e.g., five
  minutes or less); see {{security-replay}}.

`iat` (REQUIRED):
: Issued-at time.

`jti` (REQUIRED):
: A unique identifier used for replay prevention; see
  {{security-replay}}.

`sub_profile` (RECOMMENDED):
: One or more OAuth Entity Profile names {{ENTITY-PROFILES}}
  classifying the actor. {{ENTITY-PROFILES}} defines this claim as
  OPTIONAL; this profile elevates it to RECOMMENDED so resource
  servers can apply actor-class-aware policy without bespoke
  configuration.

  Its syntax (a space-delimited string of profile names) is the one
  defined by {{ACTOR-PROFILE}}. This document registers the value
  `client_instance` ({{iana-entity-profile}}). Issuers MAY include
  additional values registered with the "Actor Profile" usage
  location in the OAuth Entity Profiles registry, or privately
  defined collision-resistant values, per {{ACTOR-PROFILE}}.

`cnf` (REQUIRED unless the token is a raw JWT-SVID accepted under {{spiffe-client-id-omission}}):
: A confirmation claim {{RFC7800}} carrying a key bound to this
  instance. The `cnf` value MUST contain exactly one of `jkt` (a
  JWK SHA-256 thumbprint per {{RFC9449}} Section 3.1) or
  `x5t#S256` (an X.509 certificate SHA-256 thumbprint per
  {{RFC8705}} Section 3.1) as the binding member; other
  confirmation methods registered under {{RFC7800}} MAY appear
  alongside but are not the binding and do not change this
  profile's sender-constraint verification requirement.

  The instance issuer MUST mint `cnf` from a key the named runtime
  instance demonstrably possesses (e.g., an instance-attested key,
  a per-instance workload key, or a Demonstration of
  Proof-of-Possession (DPoP, {{RFC9449}}) public key presented to
  the issuer at attestation time). Binding rules and AS
  verification are defined in {{sender-constrained}}.

  Raw JWT-SVID compatibility is the only exception to this claim
  requirement, because the AS validates the SVID without
  re-minting; see {{spiffe-client-id-omission}} and
  {{sender-constrained}}.

`nbf` (OPTIONAL):
: Not-before time. If present, the AS MUST reject the token before
  this time.

When validating `exp`, `nbf`, and `iat`, ASes SHOULD permit a small
clock skew tolerance, typically no more than 60 seconds, applied
symmetrically. This bound is consistent with the short-lifetime
recommendation in {{security-replay}} and prevents brittle
inter-clock failures across deployments.

A Client Instance Assertion MUST NOT contain an `act` claim. The
assertion is a direct identity assertion of a single party (the
instance); per {{ACTOR-PROFILE}}, an assertion that carries an
`act` claim represents a delegation chain rather than a direct
identity, and the AS MUST reject such a token with `invalid_grant`
({{chain-merging}}, {{errors}}).

Additional claims MAY be present and MUST be ignored if not
understood, except where this document or {{ACTOR-PROFILE}} specifies
processing rules. Future profiles requiring AS understanding of a
new claim SHOULD use the JWS `crit` header parameter ({{RFC7515}}
Section 4.1.11) to mark it must-understand; ASes MUST reject
assertions whose `crit` header is malformed or includes claims they
do not implement, per {{RFC7515}} Section 4.1.11.

## Signing and JOSE Header {#signing}

A Client Instance Assertion MUST be signed using an asymmetric JWS
{{RFC7515}} algorithm; `none` and symmetric (HMAC-based)
algorithms (`HS256`, `HS384`, `HS512`) MUST NOT be used and ASes
MUST reject assertions signed with them. The descriptor's
`signing_alg_values_supported` ({{instance-issuers}}), when present,
MUST contain only asymmetric algorithm identifiers. Implementations
SHOULD follow the JWT BCP guidance in {{RFC8725}}.

ASes and instance issuers implementing this profile MUST support
`ES256` ({{RFC7518}}). This is the mandatory-to-implement baseline
for interoperability. ASes and instance issuers SHOULD additionally
support `RS256` and MAY support other asymmetric JWS algorithms
({{RFC7518}}, {{RFC8037}}) as deployment requirements dictate.

Issuers SHOULD include a `kid` in the JWS protected header; ASes
SHOULD use `kid` for key selection.

Issuers minting a Client Instance Assertion under this profile MUST
set the JWS `typ` (type) protected header parameter to
`client-instance+jwt` per {{RFC8725}} Section 3.11, and ASes MUST
reject such assertions whose `typ` is anything else. Explicit typing
prevents JWT confusion attacks where a token of a different type
(for example, a WIMSE workload identity credential {{WIMSE-CREDS}},
a JWT-SVID outside the SPIFFE compatibility mode, or an OAuth JWT
access token {{RFC9068}}) is mistaken for a Client Instance
Assertion.

The only exception is the SPIFFE compatibility mode in
{{spiffe-client-id-omission}}, where a raw JWT-SVID is intentionally
presented without re-minting. In that mode, the AS MUST validate the
token as a JWT-SVID according to {{SPIFFE-CLIENT-AUTH}} and
{{spiffe-bundle-resolution}}, and MUST NOT require the JWS `typ`
header to be `client-instance+jwt`.

Verification keys are obtained from the descriptor's `jwks_uri`,
`jwks`, or `spiffe_bundle_endpoint` for the issuer that matches the
`iss` claim; the AS MUST verify `alg` against
`signing_alg_values_supported` when present.

## Example Assertion {#example-assertion}

A decoded re-minted Client Instance Assertion (JWS protected header
and JWT payload):

~~~ json
{ "alg": "ES256", "kid": "4vC8agycHu6rnkE...", "typ": "client-instance+jwt" }
~~~

~~~ json
{
  "iss":         "https://workload.app.example.com",
  "sub":         "spiffe://app.example.com/agent/session-abc",
  "aud":         "https://as.example.com",
  "client_id":   "https://app.example.com/agent",
  "sub_profile": "client_instance",
  "iat":         1770000000,
  "exp":         1770000300,
  "jti":         "1a2b3c4d-5e6f",
  "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
}
~~~

# Token Endpoint Processing {#token-endpoint}

This section specifies AS-side processing for token requests that
provide a Client Instance Assertion. The assertion is presented
either as the `client_instance_assertion` request parameter on the
grants in {{permitted-grants}} ({{cia-param}}) or as the
`actor_token` parameter with `actor_token_type` =
`urn:ietf:params:oauth:token-type:client-instance-jwt` on the
token-exchange grant ({{token-exchange-presentation}}). This
section defines the validation, authorization-time consistency,
sender-constraint, representation, refresh, client authentication,
SPIFFE compatibility, and error rules.

This profile applies whether the AS issues JWT access tokens
({{RFC9068}}) or opaque (reference) access tokens. The
representation rules in {{access-token}} describe the *claims* an
issued access token carries (`act`, `sub`, `client_id`, `cnf`,
`sub_profile`); for JWT access tokens these appear directly in the
token payload, while for opaque access tokens they MUST be reflected
in introspection responses ({{RFC7662}}, {{introspection-on-revocation}}). The
sender-constraint binding in {{sender-constrained}} applies to both
formats; the binding key is verified at presentation regardless of
whether the access token is self-contained or requires introspection.

## Token Request {#token-request}

A client presents a Client Instance Assertion at the token endpoint
using the parameter appropriate to the grant:

* On the grants listed in {{permitted-grants}}, the assertion is
  presented as the `client_instance_assertion` request parameter
  ({{cia-param}}).
* On the token-exchange grant ({{RFC8693}}), the assertion is
  presented as the `actor_token` parameter with `actor_token_type`
  set to `urn:ietf:params:oauth:token-type:client-instance-jwt`
  ({{token-exchange-presentation}}).

The following example shows a client credentials grant carrying a
Client Instance Assertion. The client authenticates with
`private_key_jwt`; line breaks are for readability:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to the instance's key>

grant_type=client_credentials
&scope=repo.write
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIsImtpZCI6...
&client_instance_assertion=eyJhbGciOiJFUzI1NiIsImtpZCI6...
~~~

## Authorization Server Processing {#as-processing}

When evaluating a token request for this profile, an AS implementing
this document MUST perform the following checks and steps in addition
to grant-type-specific processing.

In this section the term "presented assertion" means the
`client_instance_assertion` parameter ({{cia-param}}) on the grants
in {{permitted-grants}}, or the `actor_token` parameter (with
`actor_token_type` set to
`urn:ietf:params:oauth:token-type:client-instance-jwt`) on the
token-exchange grant ({{token-exchange-presentation}}). Processing
is identical regardless of which parameter carried the assertion.

Before the steps below, the AS MUST reject the request with
`invalid_request` if any of the following pre-conditions hold:

* **Parameter on the wrong grant.** The Client Instance Assertion
  is carried as `client_instance_assertion` on grants in
  {{permitted-grants}} and as `actor_token` (with
  `actor_token_type` =
  `urn:ietf:params:oauth:token-type:client-instance-jwt`) on the
  token-exchange grant. The AS MUST reject a request that
  carries `client_instance_assertion` on the token-exchange
  grant, carries `client_instance_assertion` on a grant not
  listed in {{permitted-grants}}, or carries `actor_token` with
  the client-instance-jwt token type on any grant other than
  token-exchange.
* **Token-exchange `actor_token` / `actor_token_type` mismatch.**
  The AS MUST reject a token-exchange request in which exactly one
  of `actor_token` and `actor_token_type` is present, or in which
  `actor_token_type` is
  `urn:ietf:params:oauth:token-type:client-instance-jwt` but
  `actor_token` is absent.
* **Malformed assertion.** The AS MUST reject a request whose
  presented assertion is not a syntactically valid JWT.

1. **Authenticate the client.** Authenticate the client using
   its registered `token_endpoint_auth_method` per {{RFC6749}} and, if
   applicable, {{RFC7523}}. The `client_id` identifies the OAuth
   client. When the registered method is `client_instance_assertion`,
   follow {{instance-assertion-auth}} instead of presenting a
   separate client-controlled credential.

2. **Match the token type.** On a token-exchange request, if
   `actor_token_type` is not
   `urn:ietf:params:oauth:token-type:client-instance-jwt`, processing
   under this document does not apply; the AS processes the request
   per {{RFC8693}}, including handling other registered
   `actor_token_type` values under their own specifications. If the
   AS does not support
   `urn:ietf:params:oauth:token-type:client-instance-jwt` for the
   requested grant, it MUST reject the request with
   `unsupported_token_type` ({{errors}}). On the grants in
   {{permitted-grants}}, presence of
   `client_instance_assertion` selects processing under this document.

3. **Resolve client metadata.** Retrieve the client metadata for the
   authenticated `client_id`. For clients identified by {{CIMD}},
   dereference the CIMD document subject to its caching rules. For
   clients registered via {{RFC7591}} or pre-registered with the AS,
   read the stored metadata. The remaining steps operate on the
   resolved metadata regardless of source.

4. **Locate the instance issuer descriptor.** Parse the presented
   assertion as a JWT and read its `iss` claim. Find the descriptor
   in `instance_issuers` whose issuer member exactly equals `iss`. If
   no descriptor is found, or `instance_issuers` is absent, reject
   the request with `invalid_grant` ({{errors}}).

5. **Verify the signature.** Using the descriptor's `jwks_uri`, `jwks`,
   or `spiffe_bundle_endpoint`, verify the JWS signature per
   {{RFC7515}}, {{signing}}, and, when applicable,
   {{spiffe-bundle-resolution}}.

6. **Validate JWT claims.** Validate `iss`, `sub`, `aud`, `exp`, `iat`, `nbf`,
   and `jti` per {{claims}} and {{RFC7523}} Section 3, subject to the
   raw JWT-SVID exceptions in {{spiffe-client-id-omission}}. Enforce
   `subject_syntax`, `trust_domain`, `spiffe_id`, and
   `signing_alg_values_supported` when present in the descriptor. If
   `subject_syntax` is "spiffe" and `spiffe_id` is absent, require
   `trust_domain` and treat the descriptor as delegating the whole
   trust domain. Validate the JWS `typ` per {{signing}} and reject
   unrecognized `crit` header parameters per {{claims}}.

7. **Verify `client_id` binding.** If the instance assertion contains a
   `client_id` claim, it MUST exactly equal the authenticated
   `client_id`; reject with `invalid_grant` otherwise. "Exactly
   equal" means octet-for-octet equality on the UTF-8 encoding of
   the two values: ASes MUST NOT apply case folding, Unicode
   normalization, percent-decoding, URI canonicalization, or other
   string-equivalence transformations before comparison. The same
   octet-equality rule applies wherever this document requires
   `iss`, `sub`, `client_id`, `aud`, or `spiffe_id` values to "match"
   or "exactly equal" another value, except where a specifically
   cited matching rule (for example, the SPIFFE "/*" wildcard rule
   in {{instance-issuers}}) defines a different comparison. If the
   instance assertion has no `client_id` claim, the AS MUST verify that the
   matched descriptor satisfies the SPIFFE compatibility conditions
   ({{spiffe-client-id-omission}}); if not, reject with
   `invalid_grant`. When the descriptor satisfies those conditions,
   the AS MUST verify that the presented assertion's `sub` falls under the
   descriptor's SPIFFE scope: `spiffe_id` when present, otherwise the
   descriptor's `trust_domain`; if not, reject with `invalid_grant`.

8. **Verify proof-of-possession of the `cnf` key.** Verify
   possession of the assertion's `cnf` key per
   {{sender-constrained}}; reject with `invalid_request` if
   verification fails. For raw JWT-SVIDs accepted under
   {{spiffe-client-id-omission}}, establish the binding key per
   {{spiffe-binding}} instead.

9. **Apply replay checking.** After `client_id` binding and PoP
   verification succeed, apply the replay check per
   {{security-replay}}; reject with `invalid_grant` if a previously
   seen `(iss, jti)` tuple is found. For raw JWT-SVIDs, this replay
   check applies only when `jti` is present. The replay check
   follows `client_id` binding so that an attacker cannot burn a
   legitimate client's `jti` by presenting the assertion under a
   mismatched `client_id`. The replay check follows PoP
   verification so that the `cnf`-bound reusable-mode optimization
   in {{security-replay}} can be applied.

10. **Enforce delegation policy.** Apply the AS's local maximum
    delegation depth per {{ACTOR-PROFILE}}.

11. **Check authorization-time consistency.** For grants that
    originate from a prior authorization step (notably
    authorization_code), apply the rules of
    {{auth-time-consistency}}.

12. **Bind the instance to the issued access token.** If issuance
    succeeds, represent the instance in the access token per
    {{access-token}} and apply the sender-constraint binding per
    {{sender-constrained}}, using the key whose possession was
    verified in step 8. Reflect any prior actor chain present in
    input tokens by nesting per {{ACTOR-PROFILE}}; chain merging
    rules are given in {{chain-merging}}.

If validation succeeds, the AS issues an access token (and optionally
a refresh token) per the requested grant.

## Client Authentication via Instance Assertion {#instance-assertion-auth}

A client MAY register the `token_endpoint_auth_method` value
`client_instance_assertion` in its registered metadata (whether
published as a CIMD document or stored at the AS) to indicate that
the AS authenticates the client implicitly from a presented Client
Instance Assertion, without requiring a separate `client_assertion`
or other credential controlled by the client itself.

This mode is the natural choice for workload-only deployments (for
example, agentic services, autoscaled microservices, or ephemeral
functions) where there is no human user authorizing operations and
the team operating the runtime is also the natural owner of the
workload identity provider. For these deployments, requiring a
separate client-level credential typically means provisioning a
private key into every pod alongside the instance-attested
assertion, which (per {{security-instance-assertion-auth}}) does
not meaningfully improve defense against runtime compromise. The
mode is also appropriate where the client identifier is a logical
CIMD URL with client-key custody centralized away from the runtime,
or where the workload identity provider trusted to attest instances
is the only authority the client wishes to publish.

The trust chain to the client is preserved: the client's listing of
the instance issuer in its registered metadata is itself the
endorsement, and a token signed by such an issuer naming this
`client_id` is attributable to the client.
When `token_endpoint_auth_method` is `client_instance_assertion`,
every accepted instance issuer for the client is also a client
authentication trust root. Clients MUST NOT enable this method unless
each listed issuer is authorized for that role.

`client_instance_assertion` is a confidential-client token-endpoint
authentication method: the AS authenticates the request through the
client's registered endorsement of the presenting instance issuer.
Clients without any registered trust relationship for the AS to
evaluate cannot use it. This exclusion is scoped to this auth
method only; deployments using {{ATTEST-CLIENT-AUTH}} for client
authentication follow that specification's client-authentication
model, independent of this section.

### Request Format {#instance-assertion-auth-request}

A request using this auth method MUST include the `client_id` form
parameter and the assertion under the parameter appropriate to the
grant (`client_instance_assertion` for grants in
{{permitted-grants}}, or `actor_token` with `actor_token_type` for
the token-exchange grant). It MUST NOT carry `client_assertion` or
any other client authentication credential. The `client_id` form
parameter is required so the AS can resolve client metadata before
validating the assertion; the assertion's `client_id` claim
({{claims}}) is then matched against this value. Example, using the
`client_credentials` grant:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&scope=repo.write
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_instance_assertion=eyJhbGciOiJFUzI1NiIsImtpZCI6...
~~~

### Validation Procedure {#instance-assertion-auth-validation}

When the registered `token_endpoint_auth_method` for the `client_id`
is `client_instance_assertion`, the pre-conditions of
{{as-processing}} (rejecting malformed or misplaced presented
assertions) still apply, and the AS replaces step 1 of
{{as-processing}} ("Authenticate the client") with the following
procedure:

1. Resolve client metadata for `client_id` (per the registration
   model: dereference the CIMD URL or read stored registration data).
2. Validate the presented assertion using the token-type check
   (where applicable), instance issuer descriptor lookup, signature
   verification, and JWT claim validation rules in {{as-processing}}.
3. Verify that the presented assertion's `client_id` claim exactly
   equals the request's `client_id` parameter.
4. Verify that the presented assertion contains a `cnf` claim; this
   mode does not permit a `cnf`-less assertion, because the
   assertion serves as the sole client authentication credential
   and the bearer-replay considerations in {{security-replay}}
   apply with no fallback credential.
5. Verify proof-of-possession of the assertion's `cnf` key per
   {{sender-constrained}}.
6. Apply the replay check in {{security-replay}} after `client_id`
   binding and PoP verification succeed.
7. Reject the request with `invalid_client` if any of steps 1-6
   fails. This re-code applies to failures that would otherwise be
   returned as `invalid_grant` (under {{as-processing}}) or
   `invalid_request` (under {{sender-constrained}}); pre-condition
   failures of {{as-processing}} (malformed JWT, misplaced
   parameter) continue to return `invalid_request`.
8. Treat the client as authenticated. The validated assertion also
   satisfies this profile's assertion requirement and is used for
   instance representation per {{access-token}}.

The presented assertion's `aud` claim serves both purposes (the
{{RFC7523}} client-assertion audience and this profile's assertion
audience). A single value identifying the AS satisfies both.

The SPIFFE `client_id` claim omission mode
({{spiffe-client-id-omission}}) does not apply to
`client_instance_assertion` client authentication. Because the same
JWT is the sole client authentication credential, the assertion MUST
contain the `client_id` claim and the AS MUST verify it exactly as
described above.

After this procedure completes, processing continues with the
"Enforce delegation policy" step of {{as-processing}} and onward,
reusing the validated instance assertion. The AS MUST NOT re-apply
the token-type check, descriptor lookup, signature verification,
claim validation, `client_id` binding, PoP, or replay checks to the
same assertion in a way that would cause the request to fail replay
detection for its own presentation.

## Authorization-Time Consistency {#auth-time-consistency}

When a token request is made under the authorization_code grant
({{RFC6749}} Section 4.1), the user has authorized the *client*
identified by `client_id`, not any specific client instance. The AS
MUST ensure that the instance introduced at the token endpoint is
consistent with that authorization:

* The `client_id` authenticated at the token endpoint MUST match the
  `client_id` that received the authorization_code ({{RFC6749}}
  Section 4.1.3). Combined with the `client_id`-binding requirement
  in {{as-processing}}, this prevents an instance assertion from
  another client from being attached to a code.
* The AS MUST NOT permit the instance identity to bypass standard
  authorization-code controls (single-use redemption, redirect URI
  matching, and any code challenge bound to the original
  authorization request).
* If the AS has any authorization-time policy that depends on the
  instance (for example, a per-instance allow-list), the AS MUST
  evaluate that policy against the instance assertion presented at /token
  and reject inconsistent requests with `invalid_grant`.

When the issued access token is to be DPoP-bound, clients SHOULD
include the `dpop_jkt` parameter ({{RFC9449}} Section 10) on the
authorization request, naming the same public key whose thumbprint
will appear in the instance assertion's `cnf.jkt` at the token endpoint.
When `dpop_jkt` is present, the AS binds the authorization code to
that key per {{RFC9449}}, and at the token endpoint MUST verify that
the DPoP proof, the authorization code's `dpop_jkt`, and the
instance assertion's `cnf.jkt` all reference the same key. This provides
cryptographic continuity from /authorize to /token bound to a
specific instance: only the instance that holds the named DPoP
private key can redeem the resulting code, even if the code is
intercepted or transferred to another runtime under the same
client.

If `dpop_jkt` is absent, DPoP still sender-constrains the issued
access token at the token endpoint, but this profile does not provide
cryptographic continuity between the authorization endpoint and the
token endpoint for that authorization code.

For Mutual-TLS-bound access tokens ({{RFC8705}}), authorization-code
continuity is deployment-specific. If the AS binds the authorization
request or authorization code to a client certificate seen at the
authorization endpoint, then at the token endpoint the AS MUST verify
that the certificate used to redeem the code and the instance
assertion's `cnf.x5t#S256` match the certificate bound at
authorization time. Otherwise, mTLS sender-constraint is established
at the token endpoint and does not by itself provide authorization-
to-token endpoint continuity.

User consent under this profile applies to the client as a
whole; consent thereby covers all instances attested by listed
instance issuers. The key-bound continuity above adds cryptographic
guarantees about *which* instance redeems a code, but does not by
itself constitute per-instance consent.

An AS MAY require per-instance or per-key authorization policy when
the authorization request includes a sender-constraining key such as
`dpop_jkt`. Such policy is deployment-specific: `dpop_jkt`
identifies a key, not an instance, unless the AS has an
authorization-time mapping from that key to an instance identity. In
those deployments, the AS can require user or administrator approval
for the specific instance or key and then verify at the token
endpoint that the DPoP proof, authorization code binding, and
instance assertion `cnf.jkt` all reference the approved key.

ASes that record consent SHOULD record the descriptor scope under
which consent was granted (in particular, the descriptor's issuer
and `trust_domain`), and MAY refuse access tokens for the same
client issued under a different descriptor scope than the one
consented. This matters for clients deployed across multiple
trust domains (for example, "production" vs. "staging" SPIFFE trust
domains, or distinct PaaS environments) where the user's consent to
one is not necessarily consent to another.

This document does not define a general authorization endpoint
mechanism for presenting instance identity. Deployments requiring
standardized per-instance consent without an authorization-time key
mapping need a separate extension.

## Sender-Constrained Access Tokens {#sender-constrained}

When the AS issues an access token under this profile, whether the
instance is represented in `act` (delegation case;
{{access-token-delegation}}) or in `sub` (self-acting case;
{{access-token-self-acting}}), the AS MUST issue a
sender-constrained access token bound to a key the instance
possesses. Established mechanisms include `DPoP` {{RFC9449}} and
Mutual-TLS-bound access tokens {{RFC8705}}.

The AS MUST NOT issue a bearer access token under this profile.
Sender-constraint is a structural prerequisite, not a preference:
per-instance non-repudiation depends on binding the access token
to a key the validated instance possesses. Deployments adopting
this profile therefore require AS and RS support for DPoP
({{RFC9449}}), Mutual-TLS-bound access tokens ({{RFC8705}}), or
both, and SHOULD verify implementation support before committing.
Adoption guidance for DPoP or mTLS rollout is outside the scope
of this document; deployments unable to deploy either mechanism
within their adoption timeline should defer adopting this profile.

If the instance assertion includes a `cnf` claim ({{claims}}), the AS MUST:

* bind the issued access token to the same key by setting the access
  token's top-level `cnf` to the instance assertion's `cnf` value;
* verify possession of the `cnf` key at the token endpoint, matching
  the binding member used in `cnf` per {{RFC7800}}. For `cnf.jkt`,
  the JWK thumbprint of the `DPoP` proof's public key {{RFC9449}} MUST
  equal `cnf.jkt`. For `cnf.x5t#S256`, the certificate authenticated at
  the TLS layer {{RFC8705}} MUST match `cnf.x5t#S256`. Other
  confirmation methods present in `cnf` are not binding members for
  this profile and MAY be ignored unless local policy or their defining
  specifications require additional processing;
* reject the request with `invalid_request` if verification fails.

This protects the instance assertion from bearer-style replay within its
validity window ({{security-replay}}); without it, the instance assertion
would be a bearer credential whose replay is bounded only by `exp`
and the `jti` cache.

The binding key MUST be specific to the validated client instance.
A credential shared by the client as a whole, such as the
client-level mTLS certificate authenticated under {{RFC8705}}, the
client's `private_key_jwt` key, or any other client-controlled key
not provisioned per-instance, is not sufficient.

A re-minted Client Instance Assertion MUST contain `cnf` so that
the binding key is supplied by the same authority that named the
instance. The only profile-defined case where `cnf` can be absent
is raw-JWT-SVID compatibility, where the AS establishes an
instance-specific binding through a channel independent of the
SVID; rules are in {{spiffe-binding}}.

Deployments combining client-level Mutual-TLS-bound client
authentication ({{RFC8705}}) with this profile MUST establish
instance binding through a separate, instance-specific key. The
typical configuration uses the client's mTLS certificate at the TLS
layer for client authentication and a `cnf.jkt` in the instance assertion
paired with `DPoP` {{RFC9449}} at the token endpoint for instance
binding. Per-instance mTLS certificates issued by the instance
issuer (or otherwise bound to instance attestation) are an
alternative; in that case the same TLS certificate satisfies both
client authentication and instance binding only if the AS treats it
as belonging to the instance for binding purposes.

## Access Token Representation {#access-token}

This section defines how a validated Client Instance Assertion
surfaces in the issued access token. It does not restate the
generic access-token claim set: JWT access tokens issued under
this profile follow {{RFC9068}}; opaque (reference) access tokens
carry the same set of claims through introspection per
{{rs-processing-introspection}}. The profile-specific surfacing
rules are:

* The access token MUST be sender-constrained per
  {{sender-constrained}} (i.e., `cnf` is bound to the instance's
  key, not bearer).
* The validated instance identity surfaces in `act` (delegation
  case) or top-level `sub` (self-acting case), per the
  classification and per-case rules below; `sub_profile`
  ({{ACTOR-PROFILE}}) signals the kind of subject in either case.
* Any upstream actor chain MUST be preserved by nesting per
  {{ACTOR-PROFILE}}; merge rules are in {{chain-merging}}.

A client instance may be acting on behalf of another principal
(*delegation case*; e.g., a user authorized the request through an
authorization_code grant) or acting as itself with no other
principal involved (*self-acting case*; e.g., a `client_credentials`
grant). The AS MUST classify each request as delegation or
self-acting before populating the issued access token's claims;
the classification rules are in {{access-token-classification}}.

### Classification {#access-token-classification}

The AS classifies the request based on whether the grant produces
a principal distinct from the client instance presenting the
Client Instance Assertion:

| Grant | Principal | Classification |
| --- | --- | --- |
| authorization_code ({{RFC6749}}) | the user who authorized the code | delegation |
| `client_credentials` ({{RFC6749}}) | none | self-acting |
| `refresh_token` ({{RFC6749}}) | inherited from the original grant | inherited |
| jwt-bearer ({{RFC7523}}) | the assertion's `sub` | delegation |
| token-exchange ({{RFC8693}}) | the `subject_token`'s subject | delegation |

The jwt-bearer and token-exchange rows always classify as delegation
under this profile. {{RFC7523}} requires a JWT-bearer assertion that
identifies a principal, and {{RFC8693}} Section 2.1 requires a
`subject_token`; in both cases another party is present and named, so
the issued access token's `sub` is that party and the actor appears
in `act`. ASes MUST NOT classify these grants as self-acting based
on heuristic matching of subject identifiers; see
{{security-mode-switch}}. This rule applies even when the
`subject_token` was itself a self-acting access token whose `sub`
named the same instance now presenting the assertion (e.g., a
client-credentials token from an upstream AS exchanged at a
downstream AS): the resulting access token has `sub` and `act.sub`
naming the same instance. This is benign chain self-reference and
is not an error; the AS MUST NOT collapse the two into a self-
acting representation.

When neither delegation nor self-acting cleanly applies (for example,
custom or experimental grants), the AS MUST refuse to issue the
access token rather than guess; reject with `invalid_grant`
({{errors}}).

### Delegation Case {#access-token-delegation}

When the request is classified as delegation, the AS MUST populate
the issued access token's `act` claim per {{ACTOR-PROFILE}} from the
validated client instance assertion:

* `act.iss` = the assertion's `iss`
* `act.sub` = the assertion's `sub`
* `act.sub_profile` = the assertion's `sub_profile` (if present);
  the value `client_instance` SHOULD be included.
* `act.cnf` = the assertion's `cnf`, if present.

The access token's `sub` MUST be the principal identified by the
grant (e.g., the authenticated user). Sender-constraint binding
(top-level `cnf` and PoP verification) is governed by
{{sender-constrained}}. Note that the instance assertion's `aud`,
`client_id`, `exp`, `iat`, and `jti` are validated and consumed by
the AS but do not appear in the issued access token (`client_id`
appears at the top level as a property of the token, not as an
actor claim).

For a worked example see {{appendix-examples-auth-code}}; for a
nested actor chain (token-exchange whose `subject_token` already
carries an `act` chain), see {{appendix-examples-token-exchange}}.

### Self-Acting Case {#access-token-self-acting}

When the request is classified as self-acting, the instance is the
principal and there is no other party on whose behalf it acts. The
AS MUST populate the issued access token from the validated
instance assertion:

* `sub` = the assertion's `sub` (optionally with AS-applied
  namespacing, see below)
* `sub_profile` = the assertion's `sub_profile` (if present); the
  value `client_instance` SHOULD be included
* `cnf` is set per {{sender-constrained}}
* `act` MUST be omitted

The instance issuer's identifier (the assertion's `iss`) is not
represented as a standard access-token claim in the self-acting
case; trust in the issuer is structural via the descriptor
({{instance-issuers}}). The AS MUST nevertheless retain the
validated issuer with its token state when needed for revocation,
introspection, audit, or issuer-aware resource-server policy. For
JWT access tokens consumed without introspection, if resource
servers need issuer context and the client lists multiple issuers
with potentially colliding subject spaces, the AS SHOULD either
apply AS-scoped namespacing to `sub` as described below or expose
issuer context using a deployment-specific claim understood by the
resource server. For raw JWT-SVIDs that do not carry `sub_profile`,
the AS SHOULD set the access token's `sub_profile` to
`client_instance` after successful validation, unless local policy
intentionally suppresses that signal.

A client that lists multiple instance issuers MUST ensure those
issuers' `sub` spaces do not collide (for example, by using
disjoint naming conventions, prefixes, or a SPIFFE trust-domain
split); when the client cannot guarantee disjointness, the AS
SHOULD apply AS-scoped namespacing that incorporates both the
matched descriptor's `issuer` and the original `sub` value, to
prevent a compromised issuer from spoofing another's `sub`. The
specific encoding is a deployment choice. AS-applied namespacing
produces an AS-scoped subject identifier; resource-server policy
and audit tooling need to treat it as AS-issued rather than
issuer-native.

For a worked example see {{appendix-examples-client-credentials}}.

### Actor Chain Merging {#chain-merging}

The AS constructs the issued access token's `act` chain per
{{ACTOR-PROFILE}}'s Delegation Chain Validation and Construction
algorithm: the validated client instance assertion is the new
outermost actor, and any `subject_token` `act` chain (only
applicable to token-exchange) is preserved verbatim under it.
Depth limits and rejection on overflow follow {{ACTOR-PROFILE}}.

In the self-acting case ({{access-token-self-acting}}) the `act`
claim is omitted.

## Refresh Tokens {#refresh}

When an access token is refreshed ({{RFC6749}} Section 6), the AS
reuses the classification ({{access-token-classification}}) of the
original grant to shape the refreshed access token; the original
classification is *inherited* and is not re-derived from the refresh
request itself.

Refresh tokens issued under this profile MUST be sender-constrained
to the originating instance's `cnf` key, by the same mechanism used
to sender-constrain the access token ({{sender-constrained}}). Only
the originating instance can present the refresh token. A refresh
request MUST NOT introduce a client instance identity if the refresh
token was not originally issued under this profile.

A client MAY include a fresh Client Instance Assertion on a
refresh request (for example, to rotate the underlying assertion
before its `exp`) via the `client_instance_assertion` parameter
({{cia-param}}). When present, the assertion MUST:

* be bound to the same `cnf` key as the refresh token;
* have `(iss, sub)` matching those recorded at the refresh token's
  original issuance;
* pass the instance issuer descriptor lookup, signature
  verification, JWT claim validation, and `client_id` binding checks
  defined in {{as-processing}}; and
* pass the replay check defined in {{security-replay}} against its
  own `(iss, jti)` tuple. The bound `cnf` of the refresh token
  prevents off-instance replay, but does not prevent an attacker
  with the same refresh token from replaying a captured fresh
  assertion across successive refreshes; the replay check closes
  that window.

If the presented assertion is a raw JWT-SVID without `cnf`, the AS
MUST establish the binding key per {{spiffe-binding}} and verify
that the established binding key matches the refresh token's
binding. The AS MUST reject with `invalid_grant` any refresh
request whose presented assertion is not bound to the same `cnf`
key, or whose `(iss, sub)` differ from those recorded at issuance.

Because the refresh token is bound to the originating instance, it
is implicitly invalidated when that instance terminates. This keeps
`act.sub` (delegation) or `sub` (self-acting) stable across the
refresh chain, matching the expectation of audit pipelines that a
token's actor identity does not change after issuance.

For SPIFFE deployments, the cnf binding key SHOULD outlive the
JWT-SVID rotation cycle (typically a few minutes in default SPIFFE
implementations) when refresh tokens are issued. Deployments that bind `cnf` to a
per-instance DPoP or mTLS key held by the workload satisfy this
naturally; deployments that attempt to bind `cnf` to the SVID's
signing key directly will lose refresh-token continuity at every
rotation and SHOULD NOT use that pattern.

This profile does not extend refresh-token semantics to
cross-instance succession; doing so would break the per-instance
audit-stability invariant the profile is designed to provide.
Deployments requiring cross-instance session continuity address
it outside refresh-token semantics (the mechanisms are deployment
choices and out of scope for this document).

## SPIFFE Compatibility {#spiffe-compatibility}

A SPIFFE workload typically obtains a JWT-SVID from the SPIFFE
Workload API. JWT-SVIDs carry `iss` (the trust domain), `sub` (the
SPIFFE ID), `aud`, `exp`, and a signature, and may carry additional
registered claims such as `iat` and `jti`; they do not carry an
OAuth `client_id` claim. To allow such SVIDs to be presented as
Client Instance Assertions without re-minting, this profile defines
an optional SPIFFE compatibility mode driven entirely by descriptor
configuration. An AS is not required to support raw JWT-SVID
compatibility in order to support re-minted Client Instance
Assertions with `subject_syntax` = "spiffe".

This profile uses JWT-format Client Instance Assertions. X.509-SVIDs
are not presented as Client Instance Assertions; SPIFFE deployments
using X.509-SVIDs authenticate at the TLS layer (per {{RFC8705}})
and obtain a JWT-SVID separately for presentation. The X.509-SVID
certificate thumbprint MAY serve as `cnf.x5t#S256` in either the
re-minted assertion or the issued access token's binding.

The AS MUST select exactly one validation mode before accepting the
assertion and MUST apply that mode's rules exclusively. Selection
is determined by whether the assertion contains a `client_id`
claim: presence selects re-minted mode unconditionally, even when
the descriptor's SPIFFE conditions would otherwise have permitted
raw mode. This means an OAuth-aware adapter that mints a
Client Instance Assertion with a SPIFFE-formatted `sub` together
with a `client_id` claim is always processed as re-minted, and
the `client_id` value is verified per {{as-processing}}.

| Mode | Selected when | Key source | Claim requirements | Binding |
| --- | --- | --- | --- | --- |
| Raw JWT-SVID mode | The token has no `client_id` claim and satisfies {{spiffe-client-id-omission}} | `spiffe_bundle_endpoint` | SPIFFE JWT-SVID claims; `client_id`, `typ`, `cnf`, and `jti` are not required | Established separately per {{spiffe-binding}} |
| Re-minted assertion mode | The token contains `client_id`, or raw JWT-SVID mode does not apply | `jwks_uri`, `jwks`, or `spiffe_bundle_endpoint` when the signing key is distributed in the SPIFFE bundle | Full Client Instance Assertion claims and `typ` per {{claims}} and {{signing}} | The assertion's `cnf` drives binding per {{sender-constrained}} |

In raw JWT-SVID mode, the AS MUST:

1. match the descriptor by exact comparison of the JWT-SVID `iss` to
   the descriptor's `issuer`;
2. require `subject_syntax` = "spiffe";
3. validate the token as a JWT-SVID using SPIFFE JWT-SVID validation
   rules and the descriptor's `spiffe_bundle_endpoint`;
4. validate the SPIFFE JWT-SVID claims required by SPIFFE and ignore
   unrecognized claims unless local policy rejects them;
5. validate `aud` and `exp`;
6. validate `iat` if present;
7. validate `nbf` if present;
8. enforce the descriptor's `signing_alg_values_supported` when
   present;
9. apply the replay-cache rule in {{security-replay}} if `jti` is
   present;
10. validate `sub` as a SPIFFE ID and enforce the descriptor's
   `spiffe_id`, or `trust_domain` when `spiffe_id` is absent; and
11. establish an instance-specific sender-constraint binding per
   {{spiffe-binding}}.

In raw JWT-SVID mode, the JWT-SVID's `iss` claim MUST identify the
SPIFFE JWT-SVID issuer for the trust domain and MUST exactly match
the descriptor's `issuer` member. Because raw JWT-SVIDs do not
require `jti`, an AS that accepts a raw JWT-SVID without `jti` MUST
rely on sender-constraint and short SVID lifetimes for replay
protection.

In re-minted assertion mode, the AS MUST:

1. match the descriptor by exact comparison of the assertion's `iss`
   to the descriptor's `issuer`;
2. verify the JWS signature using the descriptor key source;
3. validate `typ` = `client-instance+jwt` per {{signing}};
4. require and validate the claims defined in {{claims}}, including
   `client_id`, `exp`, `iat`, `jti`, and `cnf`;
5. verify that `client_id` equals the authenticated client;
6. apply the replay-cache rule in {{security-replay}};
7. if `subject_syntax` is "spiffe", validate `sub` as a SPIFFE ID
   and enforce `spiffe_id`, or `trust_domain` when `spiffe_id` is
   absent; and
8. verify possession of the `cnf` key per {{sender-constrained}}.

A deployment that re-mints an SVID into a Client Instance Assertion
MUST include the claims required by {{claims}} and MUST use `typ` =
`client-instance+jwt` per {{signing}}.

### Client ID Claim Omission {#spiffe-client-id-omission}

Raw JWT-SVID mode applies when the presented assertion has no
`client_id` claim and all of the following hold for the descriptor
that matches the assertion's `iss`:

* `subject_syntax` is "spiffe";
* either (a) a `spiffe_id` member is present and the assertion's
  `sub` satisfies the `spiffe_id` matching rule of {{instance-issuers}}
  (exact match, or with "/*", path-segment prefix match per
  {{SPIFFE-CLIENT-AUTH}}), or (b) `spiffe_id` is absent,
  `trust_domain` is present, and the assertion's `sub` falls
  within that trust domain;

the AS MUST treat the descriptor as the per-client binding for the
raw JWT-SVID. In this mode:

* The AS MUST verify that the assertion's `sub` satisfies the
  descriptor's SPIFFE scope: `spiffe_id` when present, otherwise the
  descriptor's whole `trust_domain`.
* All other JWT claims and validation rules of {{claims}} continue
  to apply unchanged, except that a raw JWT-SVID is not required to
  carry `iat` or `jti`; if either claim is present, the AS MUST
  validate it per {{claims}} and {{security-replay}}.

A token that contains a `client_id` claim is processed as a
re-minted Client Instance Assertion, not under this omission mode;
that claim MUST equal the request's `client_id` parameter
({{as-processing}}).

The security rationale is that the descriptor's SPIFFE scope,
present in the client's registered metadata (whether published as a
CIMD document or stored at the AS), is itself the per-client binding:
a workload's SPIFFE ID is bound to a client by the client explicitly
listing the prefix that contains it, or by omitting `spiffe_id` and
thereby delegating the whole trust domain. This is the same model
{{SPIFFE-CLIENT-AUTH}} uses for client authentication, applied here to
actor identity. Clients SHOULD include `spiffe_id` unless
whole-domain delegation is intentional.

### SPIFFE Trust Bundle Resolution {#spiffe-bundle-resolution}

When a descriptor specifies `spiffe_bundle_endpoint` instead of
`jwks_uri` or `jwks`, the AS resolves verification keys via the SPIFFE
trust bundle endpoint. The AS MUST validate the bundle's freshness
and applicability to the trust domain in the descriptor's
`trust_domain` (or the trust domain implied by `spiffe_id`). The AS
MUST verify JWT signatures with JWT authority keys from the bundle
for the relevant trust domain, and MUST separately require the
assertion's `iss` and `sub` to satisfy the descriptor's issuer and
SPIFFE scope constraints. The bundle endpoint format, freshness,
rotation rules, and TLS authentication (WebPKI) follow
{{SPIFFE-CLIENT-AUTH}}, the same handling used for client
authentication. When the AS uses an X.509-SVID at the TLS layer for
sender-constraint binding under raw-JWT-SVID compatibility
({{spiffe-binding}}), the X.509-SVID is validated against the
X.509 trust anchors served by the same SPIFFE bundle.

### Sender-Constraint Binding for Raw JWT-SVIDs {#spiffe-binding}

A raw JWT-SVID accepted under {{spiffe-client-id-omission}} does
not include a `cnf` claim. The AS MUST establish an
instance-specific binding through some other means whose key is
attributable to the validated instance. The AS MUST reject the
request unless the presented DPoP key or mTLS certificate is bound,
by the AS's local policy, to the same runtime named by the
JWT-SVID's `sub`. The binding mechanism MUST establish key custody
through a channel independent of the JWT-SVID itself (for example,
issuer-provisioned per-instance credentials or a workload
attestation channel that names the same `sub`); accepting a DPoP
key solely because it accompanied a valid JWT-SVID is not a binding
and reduces this mode to bearer-with-`aud`.

Acceptable binding mechanisms include:

* a per-instance mTLS client certificate provisioned by the
  instance issuer (or otherwise tied to instance attestation) and
  presented under {{RFC8705}}; when the certificate is an
  X.509-SVID, the AS MUST verify that its SAN URI exactly equals
  the JWT-SVID's `sub`; or
* a `DPoP` key {{RFC9449}} that the AS confirms, through
  deployment-specific attestation or out-of-band binding to the
  instance issuer, represents the same runtime named by the
  instance assertion's `sub`.

In raw-JWT-SVID mode, the AS MUST set the issued access token's
top-level `cnf` to a confirmation member identifying the binding
key established above (`cnf.x5t#S256` for an X.509-SVID, `cnf.jkt`
for a DPoP key). Access tokens bound via `cnf.x5t#S256` to a
rotating X.509-SVID are usable only while the workload holds that
specific certificate; deployments SHOULD size access-token TTL
with the SVID rotation cycle in mind.

The AS SHOULD record which mechanism established the binding and
which key or certificate was bound to the instance, to support
incident response and per-instance revocation
({{per-instance-revocation}}). If the AS cannot establish an
instance-specific binding, it MUST reject the request with
`invalid_request` ({{errors}}).

## Error Responses {#errors}

Errors are returned per {{RFC6749}} Section 5.2 and {{RFC8693}}
Section 2.2.2. This profile uses the existing OAuth error codes:

* `invalid_request`: pre-condition and request-shape failures,
  including missing or mismatched
  `client_instance_assertion` (or, on token-exchange grants,
  `actor_token`/`actor_token_type`), presence of
  `client_instance_assertion` on the token-exchange grant, malformed
  JWT, JWS `typ` mismatch ({{signing}}), sender-constraint binding
  failures ({{sender-constrained}}), and chain depth exceeding the
  AS local maximum ({{ACTOR-PROFILE}}).
* `invalid_grant`: failures of instance-assertion validation,
  including signature, JWT claim validation, descriptor lookup or
  shape, `client_id` binding, SPIFFE compatibility conditions,
  classification ambiguity, and a presented assertion carrying an
  `act` claim.
* `unsupported_token_type` ({{RFC8693}}): on a token-exchange grant,
  an unrecognized `actor_token_type`.
* `invalid_client`: when the presented assertion is the client
  authentication credential under {{instance-assertion-auth}},
  validation failures that would otherwise be returned as
  `invalid_grant` (assertion-validation failures) or
  `invalid_request` (sender-constraint failures, including a
  `cnf`-less assertion) are returned as `invalid_client`. The
  pre-condition failures of {{as-processing}} (malformed JWT,
  misplaced parameter, mismatched grant/parameter) continue to be
  returned as `invalid_request` even in this mode.

The AS MAY return additional information via the error_description
parameter; deployments MUST NOT include sensitive instance details
(e.g., raw SPIFFE IDs of unrelated workloads) in error responses.
To help client-developer debugging, AS implementations SHOULD
include non-sensitive diagnostic context such as which validation
step failed (for example, "issuer not in instance_issuers" or
"cnf possession failed").

# Resource Server Processing {#rs-processing}

Resource servers consuming access tokens issued under this profile
follow the resource server processing rules defined in
{{ACTOR-PROFILE}} for delegated access tokens, including actor
authorization, JWT access token validation, sender-constraint
validation against the top-level `cnf`, and introspection. This
section adds three considerations specific to this profile.

**`cnf` is the instance's key, not the principal's.** Under this
profile the access token's top-level `cnf` is bound to the
instance that presents the token. In the delegation case the
principal in `sub` (typically a user) does not present the
token; the instance named in `act.sub` does, and
sender-constraint validation authenticates that instance.

**Self-acting access tokens** ({{access-token-self-acting}})
carry no `act`. `sub` names the client *instance* (typically a
SPIFFE ID or other workload identifier), `sub_profile` =
`client_instance` signals that the subject is a runtime instance,
and `client_id` continues to name the OAuth *client*. Resource
servers MUST NOT treat `client_id` as the actor identifier in
the self-acting case; the actor identifier is `sub`. Resource
servers that distinguish workload-self-acting from human-
delegated requests SHOULD make the determination based on the
presence or absence of `act`, not on the format of `sub`.

**Authorization policy SHOULD evaluate instance identity.**
Policies that authorize solely on `client_id` lose the
instance-level distinction this profile is designed to provide.

## Introspection Responses {#rs-processing-introspection}

When the AS issues opaque (reference) access tokens under this
profile, the set of profile-defined claims in the introspection
response ({{RFC7662}}) MUST be identical to the set that would
appear in the payload of a JWT access token for the same grant,
including `act` (when applicable), `sub`, `sub_profile`, `client_id`,
`cnf`, and any actor-chain members defined by {{ACTOR-PROFILE}}.
Resource servers that consume introspection apply the same
processing as for JWT access tokens described above; the
representational difference is only in where the claims arrive
(token payload versus introspection response).

The following example shows an introspection response for an
opaque access token issued under the authorization_code grant
({{appendix-examples-auth-code}}). The corresponding self-acting
case ({{appendix-examples-client-credentials}}) and token-exchange
case ({{appendix-examples-token-exchange}}) follow the same
pattern: the top-level claims and any `act` chain appear in the
response exactly as they would in a JWT access token payload.

~~~ json
{
  "active":      true,
  "iss":         "https://as.example.com",
  "aud":         "https://api.example.com",
  "sub":         "user:alice@example.com",
  "client_id":   "https://app.example.com/agent",
  "scope":       "repo.write",
  "iat":         1770000005,
  "exp":         1770001805,
  "token_type":  "DPoP",
  "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" },
  "act": {
    "iss":         "https://workload.app.example.com",
    "sub":         "https://workload.app.example.com/inst-01",
    "sub_profile": "client_instance",
    "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
  }
}
~~~

# Adoption and Migration {#adoption}

This profile is designed for incremental adoption. Existing client
metadata (CIMD documents or static registrations) that does not
declare `instance_issuers` continues to work unchanged, and existing
access tokens in circulation when a client adds `instance_issuers`
remain valid for their original lifetime.

An AS MAY implement this profile while continuing to serve clients
that do not use it. Token requests are dispatched on the presence of
`client_instance_assertion` (on the grants in {{permitted-grants}})
or on `actor_token_type` =
`urn:ietf:params:oauth:token-type:client-instance-jwt` (on the
token-exchange grant). Other (or absent) values are processed under
their own specifications.

ASes implementing this profile MUST advertise support via the
`client_instance_assertion_supported` AS metadata parameter and, for
token-exchange use, via `actor_token_types_supported`
({{as-metadata}}). Clients SHOULD verify the AS's advertised support
before sending a Client Instance Assertion on a token request, since
RFC 6749 permits ASes that do not implement this extension to
silently ignore unrecognized parameters and issue an unbound access
token. The metadata values are coarse capability signals; clients
may still need registration-time or deployment agreement for grant-
specific use, raw JWT-SVID compatibility, accepted sender-constraint
methods, and refresh-token behavior.

A client MAY add `instance_issuers` at any time. A client that wants
to mandate Client Instance Assertions for every issued access token
can register `token_endpoint_auth_method` =
`client_instance_assertion` ({{instance-assertion-auth}}), which
intrinsically requires the assertion.

Re-minted Client Instance Assertions require `cnf` ({{claims}}).
A deployment whose workload identity system does not yet emit
per-instance keys has two options:

* **Adapter pattern**: an OAuth-aware adapter wraps an existing
  workload identity system (cluster-issued projected
  service-account tokens, cloud-instance metadata services, a
  SPIFFE control plane, etc.) and re-mints a Client Instance
  Assertion with `cnf` from the underlying credential. From the
  AS's perspective the adapter is the instance issuer
  ({{issuer-obligations}}) and inherits the obligations and trust
  model of that role. The adapter holds the workload-identifier
  to `client_id` mapping and the OAuth signing keys, since
  underlying workload-identity systems typically do not know
  about OAuth clients. Recommended for non-SPIFFE deployments and
  for SPIFFE deployments that can run an adapter.

* **Raw JWT-SVID compatibility**: the SVID is presented as the
  Client Instance Assertion without re-minting; the AS establishes
  sender-constraint binding through a channel independent of the
  SVID per {{spiffe-compatibility}} and {{spiffe-binding}} (the
  X.509-SVID at TLS under {{RFC8705}} is the common pattern). See
  {{appendix-examples-spiffe}} for a worked example.

ASes and OAuth client operators SHOULD NOT enable the
`client_instance_assertion` authentication method
({{instance-assertion-auth}}) without `cnf`: that mode has no
fallback client credential, so a `cnf`-less assertion is fully
bearer at presentation ({{security-instance-assertion-auth}}).

# Conformance {#conformance}

An AS conforms to this document by implementing the
`client_instance_assertion` request parameter ({{cia-param}}) and
its token-exchange presentation as `actor_token` with
`actor_token_type` =
`urn:ietf:params:oauth:token-type:client-instance-jwt`
({{token-exchange-presentation}}), together with the validation,
representation, and error processing rules in {{token-endpoint}},
{{access-token}}, and {{errors}}, plus {{ACTOR-PROFILE}}. Raw
JWT-SVID compatibility ({{spiffe-compatibility}}) and the
`client_instance_assertion` authentication method
({{instance-assertion-auth}}) are optional capabilities; an AS
that supports either MUST conform to the respective section.

A client using this profile with a Client Instance Assertion MUST
publish or register `instance_issuers` metadata
({{instance-issuers}}) and MUST ensure each listed issuer is
authorized to attest its instances. An instance issuer MUST mint
assertions per {{claims}}, {{signing}}, and
{{trust-model-delegation}}. A resource server MUST process
delegated tokens per {{ACTOR-PROFILE}} and apply the self-acting
semantics in {{rs-processing}} when `act` is absent.

# Security Considerations {#security}

This document inherits the security considerations of {{RFC6749}},
{{RFC7519}}, {{RFC7523}}, {{RFC8693}}, {{RFC8725}}, {{CIMD}}, and
{{ACTOR-PROFILE}}.

## Trust Model {#security-trust-model}

The normative trust model for this profile is in {{trust-model}}.
This subsection summarizes the security implications.

A client delegates the authentication of its instances to one
or more instance issuers. A compromised or misconfigured instance
issuer can mint instance assertions that the AS will accept as legitimate
instances of the named client. Clients SHOULD list only
instance issuers under their own administrative control (or
contractually equivalent), and SHOULD set `spiffe_id`,
`trust_domain`, and `signing_alg_values_supported` to bound what
each issuer is allowed to assert. Deployments hosting workloads
from multiple tenants under a single `client_id` aggregate those
tenants' trust roots into a single `instance_issuers` list; see
{{security-multi-tenancy}} for the resulting blast-radius
considerations and the recommendation to issue per-tenant
`client_id` values where tenants are independent trust boundaries.

Clients using SPIFFE SHOULD include
`spiffe_id`; omitting it delegates the whole SPIFFE trust domain and
is appropriate only when every workload in that trust domain is
authorized to act as an instance of the client. After a client
detaches a compromised issuer, tokens
minted under the prior trust may continue to validate up to the
trust-withdrawal latency bound in {{security-trust-withdrawal-latency}};
operators SHOULD plan incident response around this window.

The per-client minting requirement of {{issuer-obligations}} is
an operational obligation on the instance issuer, not a check the
AS performs in-band. The AS verifies that a presented assertion's
`client_id` claim matches the authenticated client, but it cannot
detect an issuer that violates its obligation by minting for
runtimes outside the authorized set; such assertions are accepted
as valid. Clients SHOULD list only issuers whose minting policy
they have audited and whose operational practice they trust to
honor {{issuer-obligations}}.

Client metadata is itself trust-affecting: an attacker who can
modify it can add a new instance issuer under their control.
Adding an `instance_issuers` entry, widening a descriptor's
`spiffe_id` or `trust_domain`, changing a descriptor's key source, or
enabling `client_instance_assertion` (as a
`token_endpoint_auth_method`) is equivalent to adding or expanding a
credential issuer for the client and SHOULD require high-assurance
change control by the client operator and AS.
Clients publishing CIMD metadata MUST protect the publication
channel (per {{CIMD}}'s requirement of HTTPS) and the storage
backing it; deployments using static registration MUST protect the
registration store and any administrative API used to update it.
ASes resolving CIMD documents inherit {{CIMD}}'s security
considerations covering transport, intermediary caches, and DNS.

## Trust-Withdrawal Latency {#security-trust-withdrawal-latency}

The trust-withdrawal latency, that is, the worst-case time from a
client metadata change to all derived access tokens having expired,
is approximately the sum of the metadata refresh interval (for CIMD,
the cache TTL; for static registration, the expected lag between an
admin update and AS-side propagation), the instance assertion's
`exp` window, the AS's JWKS or SPIFFE-bundle cache TTL for the
issuer, and the access token TTL. ASes SHOULD size these components
together so that the resulting latency matches their
incident-response target.

Deployments with longer latencies SHOULD support active
revocation ({{revocation}}) and introspection-based status checks
at the resource server.

## Instance Lifecycle {#security-lifecycle}

Client instances are short-lived in many deployments (containers,
function invocations, agent sessions). This profile relies on three
mechanisms to keep actor identity current:

Rotation:
: Instance issuers SHOULD mint short-lived instance assertions
  ({{security-replay}}). New tokens are issued continuously as
  instances start, restart, or rotate keys.

Revocation within the validity window:
: Within an instance assertion's `exp` window, the AS prevents reuse via the
  `jti` replay rule ({{security-replay}}). A specific issued access
  token, or all tokens associated with an instance, can be revoked
  only via the AS's own revocation mechanisms ({{revocation}}); this
  profile does not define a standardized revocation endpoint or
  instance revocation list format.

Trust withdrawal:
: To stop accepting instance assertions from an issuer (e.g., after a
  workload identity compromise), the client removes the issuer
  from `instance_issuers`, replaces or removes `trust_domain`, or
  rotates `jwks` at the issuer level. The AS's response is governed
  by {{trust-lifecycle}}: subsequent uses of access tokens whose
  `act` references the withdrawn scope are treated as no longer
  endorsed.

Refresh windows are a particular concern: an access token refreshed
without a new instance assertion may carry stale instance identity long after
the original instance has terminated. ASes SHOULD prefer requiring a
fresh instance assertion on refresh ({{refresh}}), or set short refresh
intervals when instance identity is present.

Compromise-response latency under this profile is bounded by the
shortest of: the access token TTL, the introspection cache TTL at
the resource server, and the propagation time of whichever
revocation signal a deployment uses ({{per-instance-revocation}}).
None of these are defined by this document; deployments with strict
detection-to-revocation latency requirements SHOULD tune them
together and document the resulting end-to-end bound as part of
operational security posture.

## Token Revocation {#revocation}

This profile supports two complementary revocation models for access
tokens issued under it. Both build on {{RFC7009}}; deployments MAY
support either, both, or neither.

After the AS has adopted updated client metadata
({{trust-lifecycle}}), the AS SHOULD treat further use of access
tokens whose validated instance identity is no longer endorsed by
the client as invalid:

* for delegation tokens, when the `act` claim names a removed
  instance issuer or falls outside the descriptor's updated scope;
* for self-acting tokens, when the instance issuer recorded by the
  AS at issuance time has been removed, or when the access token's
  `sub` falls outside the descriptor's updated scope.

Where the deployment supports it, this is naturally enforced by
introspection ({{introspection-on-revocation}}) and short
access-token lifetimes; AS implementations MAY additionally revoke
such tokens per {{RFC7009}}, including via the per-instance
mechanism in {{per-instance-revocation}}. ASes MAY apply the same
policy to changes in a descriptor's `jwks_uri`, `jwks`, or
`spiffe_bundle_endpoint` keys that {{CIMD}} permits for changes in
client-level keys.

### Per-Token Revocation {#per-token-revocation}

An AS that supports {{RFC7009}} revocation MAY accept the access
token (or its associated refresh token) as the token parameter and
revoke that specific issued token. This works unchanged for tokens
issued under this profile; no profile-specific extensions to the
revocation endpoint are required.

### Per-Instance Revocation {#per-instance-revocation}

When an instance is compromised or otherwise needs to be quarantined,
a deployment may need to invalidate all access tokens whose
validated instance issuer and instance subject identify that
instance, without enumerating every issued token. ASes implementing
this profile SHOULD support a per-instance revocation mode keyed by
the pair (instance issuer, instance subject):

* for delegation tokens, the key is (`act.iss`, `act.sub`);
* for self-acting tokens, the key is the instance issuer recorded by
  the AS at issuance time together with the access token's `sub`;
* invalidates all currently-active access tokens matching that key,
  with descriptor scope as an optional additional filter;
* prevents issuance of new access tokens with that instance
  issuer-and-subject pair as actor or principal until a follow-up
  condition is met (for example, expiration of an internal blocklist
  entry, or removal of the instance from the workload identity
  system).

The mechanism for triggering per-instance revocation is
deployment-specific and out of scope for this document. The
compromise-to-all-tokens-invalid latency is bounded by the
shortest of: the access token TTL, the introspection cache TTL at
any consuming resource server ({{introspection-on-revocation}}),
and the propagation time of whichever revocation signal the
deployment uses.

### Introspection Behavior on Revocation {#introspection-on-revocation}

When an AS supports introspection ({{RFC7662}}), introspection
responses for access tokens issued under this profile MUST honor
both per-token revocation and per-instance revocation: an
introspection response MUST return active = false for any access
token that has been revoked under either model. Introspection MUST
also honor the trust update rules in {{trust-lifecycle}}: when the
AS has adopted updated client metadata that removes an instance
issuer or narrows a descriptor's scope so that an issued access
token's `act` (or, for self-acting tokens, `sub`) is no longer
endorsed, introspection responses for that access token MUST return
active = false once the AS has applied the update. The claim set
returned in active introspection responses is specified by
{{rs-processing-introspection}}.

### Revocation and Refresh Tokens {#revocation-refresh}

When a refresh token is sender-constrained to the originating
instance ({{refresh}}), per-instance revocation MUST also revoke
the refresh token (and prevent any further access tokens it would
mint). This profile does not define successor-instance refresh;
deployments that need cross-instance session continuity use the
separate mechanisms described in {{refresh}}.

## Replay {#security-replay}

Actor tokens MUST include `jti`, `exp`, and `iat` ({{claims}}),
except for raw JWT-SVIDs accepted under {{spiffe-client-id-omission}}.

After identifying the issuer and validating the signature, the AS
MUST reject a token whose (`iss`, `jti`) pair has already been
seen within the token's validity window, and MUST retain
replay-cache entries at least until the token's `exp` plus any
allowed clock skew. For raw JWT-SVIDs, this check applies only
when `jti` is present; otherwise replay is bounded by
sender-constraint, short SVID lifetimes, and audience restriction.

The replay-cache key is `(iss, jti)`; ASes MUST NOT widen the key
to include `client_id`. `jti` uniqueness is the responsibility of
the instance issuer within its own `iss` namespace, so two
different OAuth clients that list the same instance issuer share
the same replay state for that issuer. An attacker controlling
traffic under one OAuth `client_id` cannot replay assertions
under another, but high-volume traffic under one client can cause
replay-cache pressure for other clients sharing the same instance
issuer; ASes SHOULD apply per-issuer rate limits and bounded cache
caps. The cache MUST be scoped at least to a single AS instance;
distributed AS deployments share the cache or coordinate as
specified below.

An AS MAY skip the replay check for cnf-bound assertions that have
been PoP-verified at presentation, treating them as reusable
within their `exp` window, provided the deployment documents this
behavior and applies rate limits, monitoring, and audit logging.
This shifts the blast radius of `cnf`-key compromise from one
access token per assertion to the rate-limit ceiling within `exp`;
the rate limit is therefore the bound on that threat. The MUST
applies unconditionally to assertions without a verified `cnf`.

Issuers SHOULD use short lifetimes (five minutes or less). On
refresh ({{refresh}}), AS implementations SHOULD prefer requiring
a fresh instance assertion; when a fresh assertion is presented,
the AS MUST apply the replay check to its `(iss, jti)` per
{{refresh}}. Distributed AS deployments MUST share the replay
cache or coordinate to prevent cross-replica replay, except on
cnf-bound paths in reusable mode where cnf+PoP verification is
correctness-preserving across replicas.

A compromised instance-issuer signing key creates a
denial-of-service surface: an attacker can mint validly-signed
assertions with arbitrary `jti` values. ASes SHOULD apply
per-issuer rate limits and bounded cache caps; a sustained high
rate of distinct `jti` values from a single issuer is a signal of
compromise.

## Audience and Confused Deputy {#security-audience}

The `aud` claim binds the instance assertion to a specific AS, preventing one
AS from replaying it against another ({{RFC7523}} Section 3). The
`client_id` claim, which this document treats as a binding (not as
actor identity), prevents an instance assertion issued for one client
from being presented under a different client's authentication.

## Trust-Root Collapse {#security-instance-assertion-auth}

The `client_instance_assertion` authentication method
({{instance-assertion-auth}}) collapses two trust roots (client
credential and instance issuer) into one. Compromise of any listed
instance issuer is sufficient to mint tokens that authenticate as
the client. Modes such as `private_key_jwt` require an attacker to
possess both the instance issuer's signing key and the client's
private key; that two-key property holds only when the two keys
live in different security domains. Where genuine custody
separation between the client credential and the instance issuer
is not available, the security property of `private_key_jwt`
paired with a Client Instance Assertion reduces to that of
`client_instance_assertion` alone.

When `client_instance_assertion` is used, clients SHOULD constrain each
instance issuer's authority through `spiffe_id`, `trust_domain`,
and `signing_alg_values_supported`, and SHOULD list only the
minimum set of `instance_issuers` necessary. Trust withdrawal under
this auth method has immediate consequences: removing an instance
issuer from `instance_issuers` (or narrowing its descriptor scope)
invalidates client authentications that depended on that issuer's
endorsement, and the AS MUST stop accepting `client_instance_assertion`
authentications via the removed or narrowed issuer once it has
applied the metadata update ({{trust-lifecycle}}).

## Multi-Tenancy Under a Single Client {#security-multi-tenancy}

The class-and-instance model in {{client-instance-model}} is a
two-level model: the OAuth client (class) and its runtime
instances. It does not model tenancy as a third dimension.
Deployments that aggregate workloads from distinct trust domains
under a single OAuth `client_id` concentrate those tenants' trust
roots into one `instance_issuers` list. Compromise of any listed
issuer extends to every tenant whose workloads it authenticates.

This profile RECOMMENDS issuing a separate `client_id` per tenant
when tenants need to be isolated as trust boundaries. Per-tenant
`client_id`s give each tenant its own `instance_issuers` list, its
own descriptor scope, and its own revocation surface, and align
this profile's trust model with the deployment's tenancy
boundaries.

Where per-tenant `client_id`s are not practical, deployments SHOULD
use tight per-issuer constraints in `instance_issuers` (per-tenant
`spiffe_id` paths, per-tenant `trust_domain` values, or
descriptor-level scope members that constrain accepted `sub`
values to a specific tenant) and treat the cross-tenant blast
radius as a known operational risk. Tenant isolation in such
deployments is enforced by the breadth of these per-issuer
constraints, not by the OAuth client identity.

This profile does not define a tenant identifier as a first-class
claim. Future profiles MAY introduce one if cross-deployment
interoperability of tenant scoping becomes necessary.

## Mode-Switch Between Delegation and Self-Acting {#security-mode-switch}

Whether an issued access token represents delegation or self-acting
({{access-token-classification}}) determines whether the instance is
exposed to resource servers as `act` or as `sub`. An adversary that can
influence classification could escalate privileges, for example by
inducing the AS to drop a `sub` belonging to a user and re-anchor the
token on the instance's `sub`. The classification rule in
{{access-token-classification}} is determined by the grant type, not
by comparison of attacker-influenceable subject strings; ASes MUST
NOT employ heuristic or fuzzy matching of assertion contents to
override the table. In particular, ASes MUST NOT normalize either
side of any comparison they perform on subject identifiers (no
Unicode normalization, no case folding, no percent-decoding beyond
what {{RFC7519}} requires for JSON parsing). When classification is
ambiguous (for example, custom grants not listed in the table), the
AS MUST refuse rather than guess.

## Sender-Constraint Requirement {#security-binding}

Without sender-constraint, an `act` claim is an assertion about who
acted, not a binding enforced at the resource server: any party in
possession of the access token can present it as the named actor.
{{sender-constrained}} therefore requires sender-constrained access
tokens and forbids bearer issuance under this profile. Per
{{ACTOR-PROFILE}}, the resource server validates proof of
possession against the access token's top-level `cnf` only;
confirmation members inside an `act` object are actor context for
audit and correlation, not a binding the RS independently verifies.

## Delegation Control {#security-delegation-control}

Unbounded delegation chains permit privilege amplification across
boundaries. AS implementations MUST enforce a local maximum
delegation depth ({{ACTOR-PROFILE}}). {{ACTOR-PROFILE}} recommends
supporting at least depth 4 for cross-domain interop; deployments
imposing lower ceilings should weigh interoperability against the
privilege-amplification surface they are willing to allow.

## Privacy {#security-privacy}

A client instance assertion reveals fine-grained workload identity
to the AS and, after issuance, to resource servers via the `act` claim
(delegation case) or the access token's top-level `sub` (self-acting
case). Exposing per-instance identity to resource servers is the
deliberate purpose of this profile (it is what enables
instance-level audit, authorization, and binding downstream), but
it has privacy and operational consequences:

* Resource servers gain visibility into the deploying organization's
  internal workload structure, including (depending on `sub`) cluster
  names, namespaces, function instance IDs, or session identifiers.
  Resource server operators SHOULD treat this information with the
  same care as any other identity attribute received from an AS, and
  SHOULD NOT log or propagate it more broadly than necessary.
* Naming conventions in `sub` may inadvertently encode sensitive
  details. Issuers and clients SHOULD avoid encoding
  identifiers of human users, secret material, or internal
  infrastructure topology in `sub`, and SHOULD prefer opaque or
  hierarchical identifiers (e.g., a SPIFFE path) whose minimum
  granularity matches the auditing need.

The error response guidance in {{errors}} extends to logs and audit
trails: instance assertion contents SHOULD be logged at a level commensurate
with the sensitivity of the workload identity they convey.

# IANA Considerations {#iana}

## OAuth Token Type {#iana-token-type}

IANA is requested to register the following value in the "OAuth URI"
registry established by {{RFC6755}} (and used by {{RFC8693}} for
`actor_token_type` values on the token-exchange grant):

URN:
: `urn:ietf:params:oauth:token-type:client-instance-jwt`

Common Name:
: OAuth 2.0 Client Instance Assertion

Change Controller:
: IETF

Specification Document(s):
: This document

## OAuth Client Instance Subject Syntaxes {#iana-subject-syntax}

IANA is requested to create a new sub-registry titled "OAuth Client
Instance Subject Syntaxes" under the "OAuth Parameters" registry
group established by {{RFC6749}}. Registration policy is
Specification Required {{RFC8126}}.

A Client Instance Subject Syntax is a short identifier appearing in
the `subject_syntax` member of an instance issuer descriptor
({{instance-issuers}}). It declares the syntactic form of the `sub`
claim used by the issuer and selects validation rules the AS
applies to that claim.

Registry fields:

Syntax Identifier:
: A short label used as the `subject_syntax` value. ABNF:
  1*( ALPHA / DIGIT / "-" ).

Description:
: A short description of the subject form.

Change Controller:
: As required by Specification Required policy.

Specification Document(s):
: The defining specification.

IANA is requested to register the following initial values:

| Syntax Identifier | Description | Change Controller | Specification |
| --- | --- | --- | --- |
| `uri` | Arbitrary StringOrURI {{RFC7519}} subject (the default when `subject_syntax` is absent). | IETF | {{instance-issuers}} of this document |
| `spiffe` | SPIFFE ID {{SPIFFE}}. Triggers SPIFFE-specific descriptor members (`trust_domain`, `spiffe_id`) and SPIFFE compatibility ({{spiffe-compatibility}}). | IETF | {{instance-issuers}} of this document |

## OAuth Parameters Registration {#iana-token-params}

IANA is requested to register the following value in the "OAuth
Parameters" registry established by {{RFC6749}}:

Parameter name:
: `client_instance_assertion`

Parameter usage location:
: token request

Change Controller:
: IETF

Specification Document(s):
: {{cia-param}} of this document

## OAuth Dynamic Client Registration Metadata {#iana-client-metadata}

IANA is requested to register the following parameters in the "OAuth
Dynamic Client Registration Metadata" registry established by
{{RFC7591}}. The Change Controller for each entry is IETF.

### instance_issuers

Client Metadata Name:
: `instance_issuers`

Client Metadata Description:
: Trusted issuers of client instance assertions for this client.

Specification Document(s):
: {{instance-issuers}} of this document

## OAuth Token Endpoint Authentication Method {#iana-auth-method}

IANA is requested to register the following value in the "OAuth Token
Endpoint Authentication Methods" registry established by {{RFC8414}}:

Token Endpoint Authentication Method Name:
: `client_instance_assertion`

Change Controller:
: IETF

Specification Document(s):
: {{instance-assertion-auth}} of this document

## OAuth Authorization Server Metadata {#iana-as-metadata}

IANA is requested to register the following parameters in the "OAuth
Authorization Server Metadata" registry established by {{RFC8414}}.
The Change Controller for each entry is IETF.

### client_instance_assertion_supported

Metadata Name:
: `client_instance_assertion_supported`

Metadata Description:
: Boolean indicating whether the AS accepts the
  `client_instance_assertion` request parameter on the grants listed
  in {{permitted-grants}}.

Specification Document(s):
: {{as-metadata}} of this document

### actor_token_types_supported

Metadata Name:
: `actor_token_types_supported`

Metadata Description:
: JSON array of `actor_token_type` values supported on the
  token-exchange grant.

Specification Document(s):
: {{as-metadata}} of this document

## Media Type {#iana-media-type}

IANA is requested to register the following media type in the
"Media Types" registry:

Type name:
: application

Subtype name:
: client-instance+jwt

Required parameters:
: N/A

Optional parameters:
: N/A

Encoding considerations:
: binary; A Client Instance Assertion is a JWT; JWT values are
  encoded as a series of base64url-encoded values separated by
  period characters.

Security considerations:
: See {{security}} of this document.

Interoperability considerations:
: N/A

Published specification:
: This document.

Applications that use this media type:
: OAuth 2.0 authorization servers and clients implementing this
  profile.

Fragment identifier considerations:
: N/A

Additional information:
: Magic number(s): N/A; File extension(s): N/A; Macintosh file type
  code(s): N/A

Person & email address to contact for further information:
: Karl McGuinness <public@karlmcguinness.com>

Intended usage:
: COMMON

Restrictions on usage:
: none

Author:
: Karl McGuinness

Change controller:
: IETF

This media type, when used as a value of the `typ` JWS protected
header parameter ({{RFC7515}} Section 4.1.9), MUST be
`client-instance+jwt` (per {{RFC8725}} Section 3.11; the
`application/` prefix is omitted).

## OAuth Entity Profile {#iana-entity-profile}

IANA is requested to register the following value in the "OAuth
Entity Profiles" registry established by {{ENTITY-PROFILES}}. This
registration is contingent on the establishment of that registry.

Profile Name:
: `client_instance`

Profile Description:
: A concrete runtime instance of an OAuth client identified by a
  `client_id`.

Profile Usage Location:
: Actor Profile

Change Controller:
: IETF

Specification Document(s):
: This document


--- back

# Design Rationale {#design-rationale}
{:numbered="false"}

This appendix records design choices that motivated the normative
text.

## Why not a `client_instance` identifier parameter? {#rationale-no-instance-identifier}
{:numbered="false"}

A new top-level `client_instance` identifier would have to flow
through the authorization request, the token request, introspection,
the access token, and several existing extensions. Each is a separate
specification touch-point and a deployment cliff. The validated
instance identity surfaces in the issued access token's `act.sub`
(delegation) or top-level `sub` (self-acting) per {{access-token}},
which is the only place a resource server needs it; downstream
profiles consume that representation rather than a parallel
identifier.

## Why a dedicated `client_instance_assertion` request parameter? {#rationale-dedicated-param}
{:numbered="false"}

This profile defines a dedicated request parameter for presenting a
Client Instance Assertion on the four non-token-exchange grants
listed in {{permitted-grants}}, rather than reusing {{RFC8693}}'s
`actor_token` / `actor_token_type` parameters on those grants.
{{RFC8693}} defines `actor_token` and `actor_token_type` only on
the token-exchange grant; this profile uses `actor_token` only on
that grant ({{token-exchange-presentation}}).

The reasons for a dedicated parameter on the other grants:

First, the parameter name matches what it carries. A request body
with `client_instance_assertion=...` declares its purpose; a request
with `actor_token=...&actor_token_type=urn:...:client-instance-jwt`
requires the AS to inspect the type URN to recognize the same
artifact. The dedicated parameter is more discoverable and easier to
implement against.

Second, the self-acting case (notably `client_credentials`) does not
fit {{RFC8693}}'s "actor" framing, in which the actor is a party
distinct from the subject. In this profile's self-acting case the
instance is the subject (top-level `sub`) rather than the actor
(`act`); see {{access-token-classification}}. Naming the parameter
`actor_token` for that case would require readers to mentally
translate "actor token" to "validated instance identity assertion."
The dedicated parameter removes that translation; the grant
determines whether the result is delegation or self-acting.

Third, the dedicated parameter parallels the wire conventions of
{{ATTEST-CLIENT-AUTH}}, which uses purpose-named headers
(`OAuth-Client-Attestation` and `-PoP`) rather than a typed
general-purpose carrier. The two specifications use purpose-named
wire artifacts that an AS can dispatch by parameter name rather than
by URN inspection.

The URN `urn:ietf:params:oauth:token-type:client-instance-jwt`
remains registered to identify the assertion when carried as
`actor_token` on a token-exchange grant per {{RFC8693}}; see
{{token-exchange-presentation}}. The two parameter names are
wire-syntax siblings carrying the same assertion under identical
validation rules.

## Why client metadata as the trust anchor for instance issuers?
{:numbered="false"}

The trust relationship between a client and its instance
issuers is published in the client's registered metadata (either in
a CIMD document or in the AS's registration store). This keeps the
trust relationship auditable alongside other client metadata and
reuses existing freshness, caching, and key-rotation mechanisms.
Locating it elsewhere (in AS-side static configuration unrelated to
the client, or in a separate trust-relationship registry) would
have fragmented the surface and reduced the auditability of who
trusts whom.

## Why a `token_endpoint_auth_method` rather than a `client_assertion_type`? {#rationale-auth-method}
{:numbered="false"}

{{SPIFFE-CLIENT-AUTH}} models its workload-identity-as-client-auth
mechanism as a `client_assertion_type`. The natural question is why
{{instance-assertion-auth}} does not.

The two cases differ in what the JWT names. A SPIFFE JWT-SVID
presented as a `client_assertion` under {{SPIFFE-CLIENT-AUTH}} names
*the client* (its `sub` is the `spiffe_id` of the workload acting
as the client). The client-metadata listing of `spiffe_id`,
including the permitted "/*" path-segment wildcard, turns the SVID
into a credential for the client. There is no separate notion of
"instance" on the wire.

A client instance assertion under this profile names *the
instance*: its `sub` is the instance identifier and its `client_id`
claim names the client. The same JWT is required to do double duty
only when the client chooses
`token_endpoint_auth_method` = `client_instance_assertion`; in every
other auth method, a separate client credential authenticates the
client and the instance assertion names the instance.

Modeling the dual-use case as a `client_assertion_type` would have
required either (a) inventing a second token type identical to the
Client Instance Assertion to serve as the client assertion, doubling
the wire surface, or (b) overloading `client_assertion_type` with
the actor-token URN, which conflicts with that URN's role on
token-exchange grants. Modeling it as a `token_endpoint_auth_method`
captures what is actually happening, namely that the AS authenticates
the client implicitly from its client-metadata endorsement of the
instance assertion's issuer, while keeping `client_assertion` and
`client_instance_assertion` semantically distinct.

# Worked Examples {#appendix-examples}
{:numbered="false"}

This appendix gives end-to-end worked examples for each grant type
that interacts with this profile. Examples are non-normative and
omit unrelated headers or grant-specific details that do not affect
actor processing. Decoded assertion blocks show only the JWT
payload; re-minted Client Instance Assertions also carry a JWS
protected header with `typ` set to `client-instance+jwt` per
{{signing}} (see the full example in {{example-assertion}}).
Timestamps and lifetimes in these examples are illustrative and do
not override the lifetime guidance in
{{security-trust-withdrawal-latency}} and
{{security-replay}}.

The examples use a CIMD-style `client_id` for clarity; the same
flows apply identically to static-registration deployments
({{registration-models}}), where the `client_id` is opaque or
AS-assigned and the metadata is read from the AS's registration
store rather than dereferenced.

The examples share a common deployment:

* OAuth client: https://app.example.com/agent
* Client metadata declares one instance issuer
  https://workload.app.example.com (`subject_syntax` "uri",
  `signing_alg_values_supported` containing `ES256`).
* AS: https://as.example.com.
* Resource server: https://api.example.com.
* All access tokens are `DPoP`-bound; the instance assertion's `cnf` carries
  the instance's `DPoP` key thumbprint.

## Authorization Code with User Delegation {#appendix-examples-auth-code}
{:numbered="false"}

Alice authorizes the agent (client) at the AS through a
standard authorization_code flow. The agent runs as instance
inst-01, which presents an instance assertion at the token endpoint to
identify itself.

Authorization request from the agent (abridged). `dpop_jkt` carries
the thumbprint of inst-01's DPoP key (matching the instance assertion's
`cnf.jkt`) to establish key-bound continuity per
{{auth-time-consistency}}:

~~~ http-message
GET /authorize?response_type=code
  &client_id=https%3A%2F%2Fapp.example.com%2Fagent
  &redirect_uri=https%3A%2F%2Fapp.example.com%2Fcb
  &scope=repo.write
  &state=xyz
  &code_challenge=...
  &code_challenge_method=S256
  &dpop_jkt=0ZcOCORZNYy...iguA4I HTTP/1.1
Host: as.example.com
~~~

The AS authenticates Alice, displays consent for the client
(per {{auth-time-consistency}} consent applies to the client as a
whole, not per-instance), binds the authorization code to the
`dpop_jkt` value per {{RFC9449}}, and redirects with an
authorization_code.

Token request from instance inst-01:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to inst-01's key>

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcb
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&code_verifier=...
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIs... (private_key_jwt)
&client_instance_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

Decoded `client_instance_assertion`:

~~~ json
{
  "iss":         "https://workload.app.example.com",
  "sub":         "https://workload.app.example.com/inst-01",
  "aud":         "https://as.example.com",
  "client_id":   "https://app.example.com/agent",
  "sub_profile": "client_instance",
  "iat":         1770000000,
  "exp":         1770000300,
  "jti":         "ac-1a2b3c",
  "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
}
~~~

AS validation:

1. Authenticates the client (`private_key_jwt`).
2. Recognizes the `client_instance_assertion` parameter for this
   grant.
3. Resolves CIMD for the agent.
4. Locates the descriptor by matching `iss`.
5. Verifies signature via descriptor's `jwks_uri`.
6. Validates JWT claims.
7. Verifies the assertion's `client_id` == request `client_id` and
   applies the `(iss, jti)` replay check.
8. Applies AS-local maximum delegation depth.
9. {{auth-time-consistency}}: the request's `client_id` matches the
   `client_id` that received the code, and the DPoP proof's
   thumbprint matches both the code's `dpop_jkt` and the
   assertion's `cnf.jkt`.
10. Classifies as delegation; issues sender-constrained access token.

Issued access token:

~~~ json
{
  "iss":       "https://as.example.com",
  "aud":       "https://api.example.com",
  "sub":       "user:alice@example.com",
  "client_id": "https://app.example.com/agent",
  "scope":     "repo.write",
  "iat":       1770000005,
  "exp":       1770001805,
  "cnf":       { "jkt": "0ZcOCORZNYy...iguA4I" },
  "act": {
    "iss":         "https://workload.app.example.com",
    "sub":         "https://workload.app.example.com/inst-01",
    "sub_profile": "client_instance",
    "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
  }
}
~~~

The RS authorizes the request based on (alice, inst-01) per
{{rs-processing}}.

## Client Credentials (Self-Acting) {#appendix-examples-client-credentials}
{:numbered="false"}

A workload makes a `client_credentials` request with no human user
involved.

Token request:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to inst-02's key>

grant_type=client_credentials
&scope=repo.read
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIs...
&client_instance_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

Decoded `client_instance_assertion`:

~~~ json
{
  "iss":         "https://workload.app.example.com",
  "sub":         "https://workload.app.example.com/inst-02",
  "aud":         "https://as.example.com",
  "client_id":   "https://app.example.com/agent",
  "sub_profile": "client_instance",
  "iat":         1770000000,
  "exp":         1770000300,
  "jti":         "cc-2b3c4d",
  "cnf":         { "jkt": "PqR...XyZ" }
}
~~~

Issued access token (self-acting; no user, instance is the
principal):

~~~ json
{
  "iss":         "https://as.example.com",
  "aud":         "https://api.example.com",
  "sub":         "https://workload.app.example.com/inst-02",
  "sub_profile": "client_instance",
  "client_id":   "https://app.example.com/agent",
  "scope":       "repo.read",
  "iat":         1770000005,
  "exp":         1770001805,
  "cnf":         { "jkt": "PqR...XyZ" }
}
~~~

The RS treats `sub` as the workload identity (not a human user) per
{{rs-processing}}.

## Token Exchange with Prior Delegation Chain (Agent Spawns Sub-Agent) {#appendix-examples-token-exchange}
{:numbered="false"}

A parent agent's user-delegated access token is exchanged at the AS
for a sub-agent's downstream-resource-scoped token. The sub-agent
runtime presents an instance assertion; the inbound `subject_token`
already carries an `act` chain naming the parent agent. The
`subject_token` was issued by `upstream.example.com`, which
`as.example.com` trusts as a token issuer under local policy.

Inbound `subject_token` (decoded; issued earlier when a parent agent
"agent-orchestrator-alpha" obtained access on the user's behalf):

~~~ json
{
  "iss":       "https://upstream.example.com",
  "aud":       "https://app.example.com/agent",
  "sub":       "user:alice@example.com",
  "scope":     "repo.write",
  "act": {
    "iss":         "https://platform.example.com",
    "sub":         "agent:orchestrator-alpha",
    "sub_profile": "client_instance"
  }
}
~~~

Token request:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to inst-03's key>

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&audience=https%3A%2F%2Fapi.example.com
&subject_token=eyJhbGciOiJFUzI1NiIs...
&subject_token_type=
  urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aaccess_token
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIs...
&actor_token=eyJhbGciOiJFUzI1NiIs...
&actor_token_type=
  urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aclient-instance-jwt
~~~

The `actor_token` carries the Client Instance Assertion for the
sub-agent runtime inst-03, with no `act` of its own (per
{{ACTOR-PROFILE}}, an `actor_token` MUST NOT carry `act`). Decoded
`actor_token`:

~~~ json
{
  "iss":         "https://workload.app.example.com",
  "sub":         "https://workload.app.example.com/inst-03",
  "aud":         "https://as.example.com",
  "client_id":   "https://app.example.com/agent",
  "sub_profile": "client_instance",
  "iat":         1770000005,
  "exp":         1770000305,
  "jti":         "tx-3c4d5e",
  "cnf":         { "jkt": "AbC...123" }
}
~~~

Chain construction per {{chain-merging}}:

* Outermost: the validated Client Instance Assertion (sub-agent inst-03).
* Inner: the `subject_token`'s `act` chain, preserved
  (agent-orchestrator-alpha).

Issued access token:

~~~ json
{
  "iss":       "https://as.example.com",
  "aud":       "https://api.example.com",
  "sub":       "user:alice@example.com",
  "client_id": "https://app.example.com/agent",
  "scope":     "repo.write",
  "iat":       1770000010,
  "exp":       1770001810,
  "cnf":       { "jkt": "AbC...123" },
  "act": {
    "iss":         "https://workload.app.example.com",
    "sub":         "https://workload.app.example.com/inst-03",
    "sub_profile": "client_instance",
    "cnf":         { "jkt": "AbC...123" },
    "act": {
      "iss":         "https://platform.example.com",
      "sub":         "agent:orchestrator-alpha",
      "sub_profile": "client_instance"
    }
  }
}
~~~

Resulting chain depth is 2, well within typical AS-local maximums.
The chain reads outward-in as: sub-agent inst-03 acted on behalf of
the parent agent agent-orchestrator-alpha, which acted on behalf of
user alice. Each `act` layer names a distinct runtime; resource
servers and audit pipelines can attribute the request to the
specific sub-agent that performed it.

## Refresh with a Fresh Instance Assertion {#appendix-examples-refresh}
{:numbered="false"}

Some time after the authorization-code example
({{appendix-examples-auth-code}}), instance inst-01's original
access token approaches expiry. The original Client Instance
Assertion has also expired, so the client mints a fresh assertion
(same `iss`, `sub`, and `cnf`) and presents it on the refresh
request. The refresh token is sender-constrained to the same DPoP
key per {{refresh}}.

Token request:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to inst-01's key>

grant_type=refresh_token
&refresh_token=tGzv3JOkF0XG5Qx2TlKWIA
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIs... (private_key_jwt)
&client_instance_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

Decoded fresh `client_instance_assertion`:

~~~ json
{
  "iss":         "https://workload.app.example.com",
  "sub":         "https://workload.app.example.com/inst-01",
  "aud":         "https://as.example.com",
  "client_id":   "https://app.example.com/agent",
  "sub_profile": "client_instance",
  "iat":         1770001700,
  "exp":         1770002000,
  "jti":         "rf-1a2b3c",
  "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
}
~~~

AS validation per {{refresh}}:

1. Authenticate the client (`private_key_jwt`).
2. Verify the refresh token belongs to this client and is bound to
   the presented DPoP key.
3. Validate the fresh assertion per {{as-processing}}; in particular
   verify that its `(iss, sub)` match those recorded at original
   issuance and its `cnf` matches the refresh-token binding key.
4. Inherit the original grant's classification (delegation), per
   {{access-token-classification}}.
5. Issue a new sender-constrained access token with the same
   `act` chain.

The refreshed access token is identical in shape to the original
({{appendix-examples-auth-code}}), with updated `iat` and `exp`.

A second variant of this flow omits the fresh assertion entirely:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to inst-01's key>

grant_type=refresh_token
&refresh_token=tGzv3JOkF0XG5Qx2TlKWIA
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

Without a fresh `client_instance_assertion`, the AS still
inherits the original delegation classification and the original
`act` chain (sender-constrained to the same DPoP key, since the
refresh token was bound to it). This is the common case when
instance identity has not changed since issuance; the issued
access token's `act` claim is unchanged from
{{appendix-examples-auth-code}} (with updated `iat` and `exp`).
Refresh does not introduce a new instance identity.

## Client Authenticated via Instance Assertion {#appendix-examples-instance-auth}
{:numbered="false"}

A workload's OAuth client is registered with
`token_endpoint_auth_method` = `client_instance_assertion`
({{instance-assertion-auth}}). The workload presents no separate
client credential; the Client Instance Assertion authenticates
both the client (through the registered endorsement of its
issuer) and the instance.

Token request:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to inst-04's key>

grant_type=client_credentials
&scope=repo.write
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_instance_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

Decoded `client_instance_assertion`:

~~~ json
{
  "iss":         "https://workload.app.example.com",
  "sub":         "https://workload.app.example.com/inst-04",
  "aud":         "https://as.example.com",
  "client_id":   "https://app.example.com/agent",
  "sub_profile": "client_instance",
  "iat":         1770000100,
  "exp":         1770000400,
  "jti":         "ia-4d5e6f",
  "cnf":         { "jkt": "QrS...789" }
}
~~~

AS validation per {{instance-assertion-auth-validation}}:

1. Resolve the registered metadata for `client_id`
   (`token_endpoint_auth_method` is `client_instance_assertion`,
   so no separate client credential is expected and none is
   accepted on this request).
2. Validate the assertion using the descriptor lookup, signature
   verification, and JWT claim validation rules in
   {{as-processing}} (token-type matching does not apply on
   `client_credentials`).
3. Verify the assertion's `client_id` claim equals the request's
   `client_id` parameter.
4. Verify the assertion contains a `cnf` claim.
5. Verify possession of the `cnf` key against the DPoP proof per
   {{sender-constrained}}.
6. Apply the replay check ({{security-replay}}).
7. Treat the client as authenticated. The validated assertion
   represents the instance for {{access-token}}.

Any failure in steps 1-6 above is returned as `invalid_client` per
{{errors}}; the assertion is the sole credential, so failures that
would otherwise be returned as `invalid_grant` or `invalid_request`
are reclassified.

Self-acting access token issued by the AS:

~~~ json
{
  "iss":         "https://as.example.com",
  "aud":         "https://api.example.com",
  "sub":         "https://workload.app.example.com/inst-04",
  "sub_profile": "client_instance",
  "client_id":   "https://app.example.com/agent",
  "scope":       "repo.write",
  "iat":         1770000105,
  "exp":         1770001905,
  "cnf":         { "jkt": "QrS...789" }
}
~~~

## SPIFFE Workload (Self-Acting, JWT-SVID Reuse with X.509-SVID Binding) {#appendix-examples-spiffe}
{:numbered="false"}

A SPIFFE workload makes a `client_credentials` request. The workload
holds both a JWT-SVID and an X.509-SVID issued by its SPIFFE trust
domain. The workload presents the JWT-SVID directly as the
`client_instance_assertion` under raw JWT-SVID compatibility
({{spiffe-client-id-omission}}) and presents the X.509-SVID at TLS,
so the certificate supplies the sender-constraint binding
({{RFC8705}}). Because the presented assertion is a raw JWT-SVID,
its JOSE header follows SPIFFE conventions and is not required to
carry `typ`=`client-instance+jwt`.

The descriptor uses `subject_syntax`="spiffe" and the access token
is mTLS-bound, in place of the preamble's URI-syntax descriptor and
DPoP binding.

Instance issuer descriptor:

~~~ json
{
  "issuer": "spiffe://example.com",
  "spiffe_bundle_endpoint": "https://example.com/spiffe/bundle",
  "subject_syntax": "spiffe",
  "trust_domain": "example.com",
  "spiffe_id": "spiffe://example.com/agent/*",
  "signing_alg_values_supported": ["ES256"]
}
~~~

Token request (TLS presents the workload's X.509-SVID; client
authentication uses {{SPIFFE-CLIENT-AUTH}} X.509 mode, so
`client_assertion` is omitted):

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&scope=repo.read
&client_id=https%3A%2F%2Fapp.example.com%2Fagent
&client_instance_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

Decoded `client_instance_assertion`:

~~~ json
{
  "iss":         "spiffe://example.com",
  "sub":         "spiffe://example.com/agent/inst-04",
  "aud":         "https://as.example.com",
  "iat":         1770000000,
  "exp":         1770000300
}
~~~

The AS verifies the JWT-SVID signature against the trust bundle,
that `sub` falls under the descriptor's `spiffe_id` prefix, that the
TLS-presented X.509-SVID has SAN URI exactly equal to the JWT-SVID's
`sub`, and binds the issued access token via `cnf.x5t#S256` set to
the certificate's SHA-256 thumbprint. Issued access token
(self-acting; TTL kept short relative to the X.509-SVID rotation
cycle):

~~~ json
{
  "iss":         "https://as.example.com",
  "aud":         "https://api.example.com",
  "sub":         "spiffe://example.com/agent/inst-04",
  "sub_profile": "client_instance",
  "client_id":   "https://app.example.com/agent",
  "scope":       "repo.read",
  "iat":         1770000005,
  "exp":         1770001805,
  "cnf":         { "x5t#S256": "AbCdE...xyz" }
}
~~~

At the resource server, the workload connects over mTLS with the
same X.509-SVID; the RS verifies that the certificate thumbprint
matches the access token's `cnf.x5t#S256`.

# Document History
{:numbered="false"}

*RFC EDITOR: please remove this section before publication.*

## -01 {#history-01}
{:numbered="false"}

* **Wire surface.** Introduced the
  `client_instance_assertion` request parameter on
  `authorization_code`, `client_credentials`, `refresh_token`, and
  JWT bearer grants, and the JOSE `typ` value `client-instance+jwt`.
  Token-exchange continues to present the assertion as
  `actor_token` with the registered token type
  `urn:ietf:params:oauth:token-type:client-instance-jwt`.
  Dropped the previous "actor token grant extension" framing and
  the generalization over arbitrary actor-token profiles.
* **Access token surfacing.** §access-token specifies how a
  validated Client Instance Assertion surfaces in the issued
  access token: `act` (delegation case) or top-level `sub`
  (self-acting case), with `sub_profile` ({{ACTOR-PROFILE}})
  signalling the kind of subject, and sender-constraint binding
  per §sender-constrained. The generic JWT access-token contract
  is inherited from {{RFC9068}}; this profile does not restate
  the {{RFC9068}} claim set. Added §rs-processing-introspection
  requiring opaque tokens to surface the same set of claims via
  introspection.
* **Validation procedure.** Specified the
  `client_instance_assertion` token-endpoint authentication
  method ({{instance-assertion-auth}}) with its validation
  procedure and `invalid_client` re-coding. Ordered
  §as-processing so PoP verification precedes replay checking
  (enabling the cnf-bound reusable-mode optimization). Specified
  octet-equality for `iss`/`sub`/`client_id`/`aud`/`spiffe_id`
  comparisons. Specified `(iss, jti)` replay-cache scope.
* **SPIFFE.** Added §spiffe-compatibility for raw JWT-SVID
  presentation without re-minting, with sender-constraint
  established via an independent binding key per
  §spiffe-binding.
* **Security additions.** New sections on multi-tenancy under a
  single `client_id` ({{security-multi-tenancy}}) and the AS's
  inability to verify issuer-side compliance with the per-client
  minting rule.
  Softened §trust-model-as on AS-side issuer configuration from
  prescriptive to advisory. Added trust-root-collapse
  considerations for the auth-method mode.
* **Signing.** Declared `ES256` mandatory-to-implement; `RS256`
  SHOULD-support.
* **IANA.** Established the "OAuth Client Instance Subject
  Syntaxes" sub-registry (Specification Required) seeded with
  `uri` and `spiffe`. Added the `client_instance_assertion`
  token-endpoint-authentication-method registration.
* **Metadata.** Defined `instance_issuers` client metadata and the
  `client_instance_assertion_supported` AS metadata parameter.
* **Editorial.** Retitled to "OAuth 2.0 Client Instance Assertion".
  Added worked examples for authorization-code,
  client-credentials, token-exchange, refresh (with and without a
  fresh CIA), the `client_instance_assertion` auth method, and
  SPIFFE JWT-SVID reuse. Inverted and expanded §Design Rationale.
  Trimmed operational/deployment content not in scope for an
  OAuth protocol spec: removed the cross-instance-session-continuity
  recipes in §refresh; dropped the specific TTL "recommended
  defaults" in §security-trust-withdrawal-latency; removed the
  "Defer adoption" bullet from §Adoption; generalized
  §Introduction use-case language; trimmed §rs-processing's
  restatement of {{ACTOR-PROFILE}} to just the three additions
  this profile makes. Aligned the §instance-issuers example with
  the worked examples (`app.example.com/agent`).

## -00 {#history-00}
{:numbered="false"}

* Initial version.

# Acknowledgments
{:numbered="false"}

The author thanks participants in the OAuth Working Group for
discussions on client instance identity, workload identity, and
actor-based delegation that informed this document.
