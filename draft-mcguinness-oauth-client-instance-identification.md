---
title: "Client Instance Identification for Attestation-Based Client Authentication"
abbrev: "Client Instance Identification"
category: std
docname: draft-mcguinness-oauth-client-instance-identification-latest
submissiontype: IETF
stand_alone: yes
date: 2026-09-11
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
keyword:
 - OAuth
 - client attestation
 - instance identity
venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "mcguinness/draft-mcguinness-oauth-client-instance-assertion"
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-identification.html"
author:
 - fullname: Karl McGuinness
   organization: Independent
   email: public@karlmcguinness.com
normative:
  ATTEST: I-D.ietf-oauth-attestation-based-client-auth
  RFC6749:
  RFC7518:
  RFC7519:
  RFC7638:
  RFC7662:
  RFC7800:
  RFC8725:
  RFC9449:
informative:
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  AGENT-FEDERATION:
    title: "OAuth 2.0 Profile for Agent Federation"
    target: https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-workload-agent-federation.html
    author:
      - fullname: Karl McGuinness
    date: 2026-09-11
    seriesinfo:
      Internet-Draft: draft-mcguinness-oauth-workload-agent-federation-latest
--- abstract

This specification profiles OAuth 2.0 Attestation-Based Client
Authentication to identify a particular deployed instance of a
logical OAuth client. It defines an issuer-qualified instance
identifier, attester configuration, and processing requirements
for instance identity and key continuity. It also defines a claim
for conveying validated instance context in issued tokens.
Instance identification does not determine the authorization
subject or establish delegation.

--- middle

# Introduction

An OAuth client identifier can represent software executing in
many concurrent instances. Attestation-Based Client Authentication
{{ATTEST}} authenticates a client instance through a key-bound
Client Attestation and proof of possession. A stable identifier
for that instance additionally supports audit correlation,
instance-specific risk evaluation, and lifecycle response across
attestation reissuance and key rotation.

The Client Instance Key alone cannot serve this purpose. Key
rotation breaks any correlation keyed on a thumbprint, suspension
and revocation need to target an installation or execution rather
than a key, and the per-receiver keys that {{ATTEST, Section 11.1}}
recommends for unlinkability make the key useless as an identifier
across requests to different Receivers. A stable identifier
assigned by the attester, scoped to the attester's issuer, supplies
what the key cannot while leaving key possession as the proof of
presence.

This document defines that identifier and its relationship to an
OAuth client {{RFC6749}} as a profile under {{ATTEST, Section 13}}.
It retains the Client Attestation JWT, HTTP headers, authentication
methods, and client subject semantics of ATTEST. It adds a stable
instance identifier and its processing rules; it does not define
an alternative assertion format or grant type. Other ATTEST
deployments do not require this instance identification profile.

The identity of a client instance is distinct from the identity of the
principal whose authority it exercises. Authorization profiles,
such as {{AGENT-FEDERATION}}, determine whether that principal is
the token subject or an actor. Implementing this document does
not require implementing an actor profile or producing `act`.

An IdP can act solely as a Receiver; it need not issue attestations.
Use of this profile requires an available, trusted attester capable
of establishing the configured instance granularity. Registry import
alone does not provide that evidence. Platform JWT and native SVID
inputs to agent federation do not provide this instance context
unless an attester separately issues a conforming Client Attestation.
Deployments that need no stable instance correlation can use ATTEST
without this profile.

The proposed replacement for draft-mcguinness-oauth-ai-agent-instance
is the pair draft-mcguinness-oauth-workload-agent-federation and
draft-mcguinness-oauth-client-instance-identification. The former
specifies governed agent identity and grant issuance; the latter
specifies optional instance identification using ATTEST.
draft-mcguinness-oauth-client-instance-assertion remains a separate
proposal for a standalone assertion alongside other client
authentication methods. These individual drafts do not require
adoption of one another except where explicitly profiled.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

The terms Client Attestation, Client Attester, Client Instance,
and Client Instance Key are used as defined in {{ATTEST}}.

Logical Client:
: The OAuth client identified by `client_id`. Several Client
  Instances can authenticate as the same Logical Client.

Instance Identifier:
: An opaque identifier assigned by a Client Attester to one
  Client Instance at the configured lifecycle granularity. Its
  identity is the ordered pair of the Attester Issuer and the
  Instance Identifier.

Instance Context:
: A validated reference to the client instance presenting a request.
  It is evidence about execution, not an authorization grant.

Receiver:
: The authorization server or other party that validates a Client
  Attestation under this profile. Where it issues tokens carrying
  Instance Context it is also the token issuer.

Attester Issuer:
: The value of `iss` in the Client Attestation, identifying the
  Client Attester.

Instance Authority:
: The namespace authority identified by `iss` in a `client_instance`
  object. It can be the token issuer, an attester, or an upstream
  issuer whose validated context is preserved under a consuming
  profile.

# Profile Selection and Trust {#configuration}

The authorization server and client MUST establish use of this
profile through administrative configuration before processing
requests. That configuration MUST identify the Logical Client,
its authentication method, and the attesters authorized to
identify its instances. A resource relying on instance context
MUST likewise establish that requirement through trusted
configuration. Receiving an instance claim MUST NOT select this
profile or alter the client's authentication method. This
document defines no new discovery or client metadata parameters.

The configuration MUST define the identified unit and its continuity
rules. This document defines two units: `installation`, one
application installation, and `execution`, one process or container
execution. Profiles MAY define others. Receivers MUST NOT assume that
an installation identifier distinguishes its individual processes. A
change of granularity MUST create a new identifier; it MUST NOT
silently change the meaning of an existing identifier.

For each approved attester, the server MUST configure its exact
issuer identifier, verification keys or a trusted source for
those keys, permitted asymmetric signature algorithms, and
attestation age and lifetime limits. Client-published information
or possession of a signing key alone MUST NOT establish an
attester's authority for a client.

The Receiver MUST resolve keys using that configuration and the
JWT's `kid`. It MUST NOT obtain authority or replacement keys
from an unapproved JWT-supplied URL or embedded public key.
Changes to issuer authority and key configuration MUST be
authenticated and audited. Issuer and client identifiers are
compared as exact strings, without URI normalization.

# Client Attestation Claims {#claims}

All requirements of {{ATTEST}} apply. This profile retains
`typ=oauth-client-attestation+jwt` and `sub=client_id`; it does
not exercise the base specification's subject override.

In addition to the requirements of {{ATTEST}}, the following apply:

`iss`:
: REQUIRED by this profile. It MUST equal the exact issuer identifier of
  an approved Client Attester in {{configuration}}.

`client_instance_id`:
: REQUIRED. A nonempty StringOrURI {{RFC7519}} identifying the Client
  Instance within the issuer's namespace. The identifier MUST be
  opaque to Receivers and MUST NOT be reassigned to another instance.
  Receivers MUST NOT derive permissions by parsing it. Attesters
  MUST generate unpredictable identifiers with at least 128 bits of
  randomness and MUST NOT embed hostnames, user identifiers, or other
  identifying data. Identifiers MUST NOT exceed 256 characters.
  Receivers MUST accept conforming identifiers up to that length and
  reject longer values with `invalid_client_attestation`.

`iat`:
: REQUIRED. The time at which the attestation was issued, as a
  NumericDate. It MUST precede `exp`. Receivers MUST reject
  attestations outside their configured age and lifetime limits.
  Configured clock skew MUST NOT exceed 30 seconds.

`exp`:
: REQUIRED by ATTEST. The expiration time as a NumericDate.
  Receivers MUST reject missing or incorrectly typed `iat` or `exp`.

The protected header MUST contain `kid`. Attestations MUST use
an asymmetric signature algorithm permitted by the trust
configuration. Implementations MUST support `ES256` {{RFC7518}};
`none` and symmetric MAC algorithms MUST NOT be used.

The base `cnf` claim contains the public instance key using the
`jwk` representation {{RFC7800}}. Private key members MUST NOT
be included. The attester MUST authenticate the instance and
verify its possession of that key before issuing an attestation.
Any additional identity or provenance claims require processing
rules in the profile that uses them.

Example decoded attestation payload:

~~~ json
{
  "iss": "https://attester.example/tenant/acme",
  "sub": "https://platform.example/oauth-client",
  "client_instance_id": "i-7f3d9a2e6c8145b0a923d47e18f602cd",
  "iat": 1789128000,
  "exp": 1789128300,
  "cnf": {
    "jwk": {
      "kty": "EC",
      "crv": "P-256",
      "x": "VcKVNBZ4IaBAYW3jxM4w3TJFVA7myeUGQyGt-g_yvpQ",
      "y": "f-E-hYE3TAWKwhVv9pej9NABs9SX9XsNO80x57jFTyU"
    }
  }
}
~~~

# Request Processing {#processing}

The client MUST present its attestation and proof through the
mechanisms of {{ATTEST}} and use its configured authentication
method. Implementations of this profile MUST support DPoP
combined mode and `attest_jwt_client_auth_dpop`. Other base
attestation proof methods MAY be supported by agreement.

The Receiver MUST:

1. Determine that this profile applies from {{configuration}}.
2. Validate the Client Attestation and proof according to
   {{ATTEST}}, including JWT type, signature, expiration, client
   identity, key possession, and applicable freshness checks.
3. Validate the additional claims and attester association in
   {{claims}}. The attestation's `sub` MUST equal the authenticated
   or expected Logical Client identifier.
4. Establish the instance identity as `(iss, client_instance_id)`
   and associate it with that Logical Client and the proven key.
5. Apply the instance's current status under {{lifetime}} and any
   other configured risk policy before accepting the request.

In DPoP combined mode, the proof key MUST match `cnf.jwk`. Under
any other supported proof method, a token-binding key presented
in the same request MUST also be the validated `cnf.jwk` key, and
the Receiver MUST reject a DPoP proof from a different key. This
profile deliberately narrows the base specification's allowance
for an unrelated DPoP key so that token binding, the instance
identity established in step 4, and the key-continuity rules in
{{lifetime}} all refer to one key. A Receiver MUST NOT issue a
DPoP-bound access token unless the request carried a DPoP proof
from that key under {{RFC9449}}, either in combined mode or alongside
a separate Client Attestation PoP JWT. Refresh tokens and other
protocol artifacts retain their ATTEST binding rules, including
when no DPoP proof is present. Where an issued artifact
uses `cnf.jkt`, the Receiver MUST compute the JWK SHA-256
thumbprint according to {{RFC7638}} from the validated `cnf.jwk`
key; it MUST NOT accept an unrelated requester-selected
thumbprint. DPoP nonce and replay processing follow {{RFC9449}}.
A fresh proof is required for each request; the Client Attestation
itself can be reused within its validity.

A Receiver MUST NOT substitute instance identification for grant
validation. In particular, it MUST NOT set an access token's
`sub`, add an `act` claim, or extend a delegation chain solely
because a Client Attestation was accepted. A calling profile
MUST establish any instance-to-principal relationship it needs.

Invalid or missing instance claims are reported using
`invalid_client_attestation` from {{ATTEST}}. Client
authentication failures and freshness challenges retain the
base specification's error processing. A failed profile check
MUST NOT trigger fallback to authentication without the required
instance evidence.

# Instance Lifetime and Key Continuity {#lifetime}

The attester MUST assign a new Instance Identifier for each new unit
at the granularity established in {{configuration}}. An execution
identifier changes on process or container restart. An installation
identifier MAY survive process restarts when the attester verifies
continuity of that installation. A cloned installation or independently
created execution MUST receive a distinct identifier. Multiple
processes within one identified installation are not distinguished
by its identifier.

A suspend/resume operation MAY retain the identifier only when the
attester establishes continuity and prevents independently restored
copies of the identified unit from sharing that identity.

When an attester suspends or retires an instance, it MUST cease
issuing attestations for it. This does not notify Receivers or
invalidate attestations they already hold. A Receiver MAY additionally
obtain authenticated instance status from the attester or apply its
own policy, keyed by `(iss, client_instance_id)`. It MUST reject a
request once suspended or retired status is applied locally, using
`invalid_client` {{RFC6749}} without revealing whether the instance
is known. Without such status, enforcement depends on attestation
expiration or the configured maximum age. This document defines no
status distribution protocol.
A Receiver that suspends an instance SHOULD revoke the tokens it
issued to that instance or report them inactive through
introspection {{RFC7662}}; the `client_instance` parameter in
{{instance-context}} lets a resource server apply the same status
to tokens it has already accepted. Status applied at the Receiver
does not by itself revoke tokens issued by other parties.

Attestation renewal and key rotation within a continuing instance MUST
preserve each identifier the attester has assigned to that instance. A
new key requires a new attestation and authenticated proof of its
binding to that instance. Possession of an instance identifier, an
expired attestation, or a former public key alone MUST NOT establish
continuity. A Receiver MUST NOT use a key thumbprint, certificate
serial number, or JWT `jti` as a substitute for the identifier.

This profile does not override refresh-token binding in
{{ATTEST}}. In particular, a stable identifier does not permit
use of a key-bound refresh token with a new key. Transferring
existing grants, tokens, or sessions to a replacement key
requires a separately specified authorization procedure.

# Conveying Instance Context {#instance-context}

An issuer MAY include a `client_instance` claim in a token or
introspection response {{RFC7662}} when the recipient needs
validated instance context. Its value is an object containing:

`iss`:
: REQUIRED. String identifying the authority for the instance
  identifier. It is not necessarily the enclosing token issuer.

`id`:
: REQUIRED. Nonempty StringOrURI identifying the instance in
  that authority's namespace.

`unit`:
: OPTIONAL. String naming the identified unit: `installation` or
  `execution` as established in {{configuration}}. Profiles MAY
  define additional values. Absent, the recipient MUST rely on
  its configuration for the unit.

The object MUST identify the instance whose participation and key
possession were validated for issuance. Before using this context,
a recipient MUST validate the enclosing token or authenticated
introspection response. It MUST reject a `client_instance` whose
`iss` is neither that token's issuer nor a pass-through Instance
Authority explicitly configured for that token issuer and recipient.
A mapped identifier needs no direct attester trust; pass-through context does
not authorize fetching keys from its `iss`. If context is required,
rejection MUST prevent accepting the token for that request. The tuple
takes one of two forms. In the mapped form, which is RECOMMENDED,
`iss` is the
Receiver's own issuer identifier and `id` an identifier the Receiver
assigned through an authenticated, unambiguous mapping it maintains.
In the pass-through form, `iss` and `id` are copied from the validated
attestation; this form requires the recipient to trust the Attester
Issuer's namespace directly and MUST be used only with recipients
configured for it. A consuming profile MAY likewise preserve context
from a validated upstream token, but MUST define the trusted upstream
Instance Authority and the association being preserved. The issuer
MUST NOT copy unvalidated client-supplied context. The `iss` and `id`
members MUST be nonempty
strings. Additional members MAY be defined by other profiles. A
recipient MUST ignore members it does not recognize. A profile
defining additional members MUST specify their processing for
recipients implementing that profile and MUST NOT change the meaning
of `iss` or `id`.

~~~ json
{
  "client_instance": {
    "iss": "https://idp.example/tenant/acme",
    "id": "m-f61783ea4cb24d098851d34960a274be",
    "unit": "execution"
  }
}
~~~

This object conveys identity only. It MUST NOT be interpreted
as an actor, a separate token, or a grant of authority. A profile
using it MUST define its association with the token's subject,
current actor, or other presenter, and how that association is
preserved during exchange. Proof of possession is validated
against the enclosing token's binding, not this object.

# Relationship to Workload Identity

A workload identity can identify several replicas. An integration
MUST NOT assert that such an identity uniquely identifies an
instance without additional authenticated evidence. SPIFFE
OAuth authentication and its client mappings are specified in
{{SPIFFE-OAUTH}}; this document does not redefine those bindings.

A workload attester can issue the Client Attestation defined
here after validating native workload evidence. Direct use of
a credential with a different `sub` or `typ` requires a separate
profile defining replacement client-mapping checks as allowed
by {{ATTEST}}. Such a credential is not implicitly conformant
to this profile.

# Security and Privacy Considerations

The considerations of {{ATTEST}}, {{RFC8725}}, and {{RFC9449}}
apply. Compromise of an attester can allow impersonation of any
instance within its approved client associations. Receivers MUST
scope those associations and MUST enforce withdrawal of attester
trust on subsequent authentication. Runtime isolation and key
custody limit the granularity of the identity that can be proven;
a shared private key does not distinguish its individual holders.

Instance identification supports targeted risk response, but
does not prove software behavior, authorization, or integrity
beyond the evidence the attester actually evaluated. Instance
revocation reaches outstanding tokens only through the revocation
and introspection behavior in {{lifetime}}; consuming profiles
define any further consequences.

A Client Attestation has no audience binding. Resistance to
forwarding depends on validating its proof, including the intended
Receiver, freshness, and key possession under ATTEST and DPoP. An
instance identifier, including a per-Receiver identifier, MUST NOT
substitute for that proof. A copied attestation without a valid proof
for the receiving endpoint MUST be rejected.

Stable identifiers and keys can correlate activity. A
`client_instance_id` that survives key rotation also links an
instance across every Receiver that trusts the same attester, which
defeats the unlinkability mitigation in {{ATTEST, Section 11.1}} of
using distinct Client Instance Keys per authorization server. Where
cross-receiver linkability is a concern, the attester SHOULD assign
a distinct `client_instance_id` per Receiver while maintaining its
internal mapping; Receivers MUST NOT assume identifiers seen by
different Receivers are comparable. A Client Attestation carries no
audience, so a per-receiver identifier requires the attester to
issue a distinct attestation for each Receiver, which is the
practice {{ATTEST, Section 11.1}} already recommends. Deployments
that require one identifier across Receivers accept that
correlation as an explicit trade-off.

Receivers issuing Instance Context SHOULD use recipient-scoped
instance mappings when broader correlation is unnecessary,
preserve their internal audit mapping, and disclose only needed
provenance. Error responses SHOULD avoid revealing unrelated
instance identities. Logs MUST NOT contain raw credentials or
private keys.

# IANA Considerations

## JWT Claims and Introspection Response Parameters

This specification requests registration of `client_instance_id`
and `client_instance` in the "JSON Web Token Claims" registry
established by {{RFC7519}}. The descriptions are, respectively,
"Issuer-scoped client instance identifier" ({{claims}})
and "Validated client runtime instance context"
({{instance-context}}). The Change Controller is IETF.

It also requests registration of `client_instance`, with the
same description and reference, in the "OAuth Token Introspection
Response" registry established by {{RFC7662}}. The Change
Controller is IETF.

The claim name `client_instance` is distinct from any Entity
Profile value of the same spelling; this document registers a JWT
claim and an introspection response parameter, not a subject or
actor profile.

--- back

# Attester Patterns {#attester-patterns}
{:numbered="false"}

This appendix is informative. It maps common attester types to the
identified unit and the continuity evidence each can supply. The
attester in every row authenticates the instance and verifies its
possession of the Client Instance Key before issuing an attestation.

| Attester | Identified unit | Continuity evidence | Not distinguished |
|---|---|---|---|
| Mobile platform app-attestation service | Installation | Platform-attested key generated at install and bound to the app identity | Concurrent processes of one installation |
| Enterprise device management for a desktop agent | Installation | Device enrollment record and a hardware-backed key held by the managed installation | Reinstallation on the same device without re-enrollment |
| Container orchestrator or workload runtime | Execution | Runtime-assigned identity for one container or pod; a restart yields a new identifier | Replicas sharing one image |
| Function or job scheduler | Execution | Per-invocation or per-job environment identity | Retries that the platform treats as the same job |

An installation attester that cannot verify continuity across a
restore or clone MUST issue a new identifier, as {{lifetime}}
requires. An execution attester that reuses a key across restarts
still issues a new identifier for each execution; the key is not
the identifier. A shared signing key across replicas prevents
instance identification at any granularity finer than the key.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Replaced the instance-authentication portions of
  draft-mcguinness-oauth-client-instance-assertion, using ATTEST as
  the sole protocol foundation and separating instance evidence from
  agent federation and actor semantics.
* Made the identified unit explicitly configured and distinguished
  installation continuity from process or container execution
  lifetime.
* Bound non-combined proof methods to the attestation key, restored
  the MUST for ignoring unknown `client_instance` members, and
  addressed cross-receiver linkability of stable instance identifiers.
* Required `iss` in this profile with an exact-match constraint,
  and clarified that per-receiver identifiers require
  per-receiver attestations.
* Argued for a stable identifier against the key alone, scoped this
  profile against the client instance assertion draft, and defined
  Receiver, Attester Issuer, and Instance Authority.
* Defined instance status handling, the `invalid_client` rejection,
  and revocation or introspection of outstanding tokens; required a
  DPoP proof for key-bound artifacts.
* Added the optional `unit` member and the mapped and pass-through
  forms of `client_instance`, an identifier length bound, a name
  disambiguation note, and an informative attester patterns
  appendix.
* Limited the DPoP issuance prerequisite to DPoP access tokens,
  preserving ATTEST's other artifact bindings, and tied suspension
  enforcement to locally applied status or attestation validity.
* Required unpredictable instance identifiers, bounded their length,
  defined recipient-side context validation and forwarding resistance,
  and aligned the predecessor and deployment scope descriptions.
