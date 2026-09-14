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
  RFC7519:
  RFC7662:
  RFC8725:
informative:
  AAUTH: I-D.hardt-oauth-aauth-protocol
  ACTOR-PROFILE: I-D.mcguinness-oauth-actor-profile
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  AGENT-FEDERATION:
    title: "OAuth 2.0 Profile for Agent Federation"
    target: https://mcguinness.github.io/draft-mcguinness-oauth-workload-agent-federation/draft-mcguinness-oauth-workload-agent-federation.html
    author:
      - fullname: Karl McGuinness
    date: 2026-09-11
    seriesinfo:
      Internet-Draft: draft-mcguinness-oauth-workload-agent-federation-latest
--- abstract

This specification defines an optional claims profile of OAuth 2.0
Attestation-Based Client Authentication for deployments that need a
common instance identifier across attestations and key changes. It
specifies an issuer-qualified identifier, continuity and privacy rules,
and optional instance context in tokens and introspection responses.
Authentication, proof of possession, and token binding remain governed
by the base specification. Deployments needing only client instance
authentication do not require this profile.

--- middle

# Introduction

Attestation-Based Client Authentication {{ATTEST}} already authenticates
a deployed client instance using a Client Attestation and proof of
possession of its Client Instance Key. It defines the authentication
methods, proof processing, and binding of OAuth artifacts to that key.
This profile is optional; it is not needed to authenticate an instance.

An OAuth client identifier identifies the Logical Client. An
authorization profile determines the principal whose authority is
represented and, where applicable, the delegated actor. This
specification identifies a particular installation or execution of
client software. Several instances can operate for the same principal;
replacing an instance need not change that principal.

The additional interoperability need is a common identifier that
independent attesters, Receivers, and downstream systems can use across
attestations and key changes. For example, an application installation
replaces key K1 with K2 and obtains a new attestation. An audit system
needs to recognize the same installation, while a clone must receive a
different identity. The new key and attestation alone do not express
that continuity. The attester must establish it before reusing an
identifier.

This document profiles the additional claims permitted by {{ATTEST}}
under its profiling rules in {{ATTEST, Section 13}}. It defines:

* `client_instance_id`, an attester-assigned identifier scoped by `iss`,
  with rules for continuity, non-reassignment, and privacy; and
* `client_instance`, an optional reference conveyed in tokens or
  introspection responses to recipients that need validated instance
  context without receiving the original attestation.

Use this profile when those parties need to exchange and interpret a
common instance identity. When one IdP can satisfy its correlation
needs through internal mappings, or correlation need only last for the
current key, ATTEST alone is sufficient. A stable identifier also
creates a correlation risk, so it should be released only where needed.

All authentication and proof requirements come from ATTEST and the
selected OAuth mechanisms. This profile does not define a key-rotation
protocol or transfer existing grants, sessions, or refresh tokens to a
new key. Stable identity records continuity; it does not prove possession
of either key or authorize that transfer.

An IdP can act solely as a Receiver, relying on an attester capable of
establishing the required instance continuity. Registry import alone
does not supply that evidence. Authorization profiles, such as
{{AGENT-FEDERATION}}, separately determine the principal and acting
relationship; instance identification does not establish delegation.
Actor representation is separately addressed by {{ACTOR-PROFILE}}.
Instance evidence does not establish that delegation occurred or
select an actor. A consuming authorization profile determines whether
the instance operates as the subject, as a delegated actor, or in
another explicitly defined relationship. This profile can be used
without implementing Actor Profile.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

The terms Client Attestation, Client Attester, Client Instance,
and Client Instance Key are used as defined in {{ATTEST}}.

Logical Client:
: The OAuth client {{RFC6749}} identified by `client_id`. Several Client
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

The Receiver and client MUST establish use of this
profile through administrative configuration before processing
requests. That configuration MUST identify the Logical Client,
its authentication method, and the attesters authorized to
identify its instances. A resource relying on instance context
MUST likewise establish that requirement through trusted
configuration. Receiving an instance claim MUST NOT select this
profile or alter the client's authentication method. This
document defines no new discovery or client metadata parameters.

The attester and Receiver MUST establish the identified granularity
and its continuity rules through trusted configuration. This document
distinguishes an application installation from a process or container
execution; profiles MAY define other granularities. Receivers MUST
NOT assume that an installation identifier distinguishes its individual
processes. A change of granularity MUST create a new identifier; it
MUST NOT silently change the meaning of an existing identifier.

The Receiver MUST associate the exact Attester Issuer with an authority
trusted to assign instance identifiers for the Logical Client. Signature
or MAC validation under ATTEST MUST establish that association; a JWT's
`iss` or possession of a key alone MUST NOT establish this authority.
Trust management and verification-key resolution follow ATTEST and the
deployment's trusted configuration. Issuer and client identifiers are
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

The remaining claims, JWT protection, and proof requirements follow
ATTEST unchanged. In particular, `exp` and `cnf` remain required, and
`iat` remains optional. This profile adds no algorithm, key-selection,
clock-skew, or attestation-lifetime requirements.

Example decoded attestation payload, including the optional `iat`:

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

The client and Receiver MUST use the presentation and proof processing
of {{ATTEST}} for their configured method. This profile does not require
DPoP combined mode or change any method's token-binding rules.

After successful ATTEST validation, the Receiver MUST:

1. Determine that this profile applies under {{configuration}}.
2. Validate the additional claims and attester authority in {{claims}}.
3. Establish the instance identity as `(iss, client_instance_id)` and
   associate it with the Logical Client and validated Client Instance
   Key. The identifier MUST NOT substitute for proof of key possession.
4. Apply any configured policy associated with that instance identity.

An additional token-binding key remains subject to the selected OAuth
mechanism. Instance context records the instance whose attestation and
proof were validated; it does not change the binding of issued tokens.

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

When an attester suspends or retires an instance, it MUST cease issuing
attestations for it. A Receiver MAY use the identifier for local risk
or lifecycle decisions and MUST reject an instance disallowed by its
current policy. A Receiver that suspends an instance SHOULD revoke the
tokens it issued to that instance or report them inactive through
introspection {{RFC7662}}. A stable identifier does not notify other
parties or invalidate outstanding attestations or tokens. Status
propagation and revocation mechanisms are outside this profile.

Attestation renewal and key rotation within a continuing instance MUST
preserve each identifier the attester has assigned to that instance. A
new key requires a new attestation and authenticated proof of its
binding to that instance. Possession of an instance identifier, an
expired attestation, or a former public key alone MUST NOT establish
continuity. A Receiver MUST NOT use a key thumbprint, certificate
serial number, or JWT `jti` as a substitute for the identifier.

Different Attester Issuers define different instance namespaces.
Receivers MUST NOT infer continuity across an issuer change from equal
identifier strings or a shared key. Preserving an association across
authorities requires a separately specified procedure establishing
trust in both authorities and authenticated evidence of continuity;
this profile does not define that procedure.

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

The object MUST identify the instance whose participation and key
possession were validated for issuance. It records that validated
participation; its presence does not independently authenticate the
current presenter of the enclosing token. Authentication and proof of
possession remain governed by that token and its applicable protocol.
Before using this context,
a recipient MUST validate the enclosing token or authenticated
introspection response. It MUST reject a `client_instance` whose
`iss` is neither that token's issuer nor a pass-through Instance
Authority explicitly configured for that token issuer and recipient.
A mapped identifier needs no direct attester trust; pass-through
context does not authorize fetching keys from its `iss`. If context is
required, rejection MUST prevent accepting the token for that request.
The tuple takes one of two forms. In the mapped form, which is RECOMMENDED,
`iss` is the Receiver's own issuer identifier and `id` an identifier
the Receiver assigned through an authenticated, unambiguous mapping
it maintains.

The Receiver MUST NOT assign the same mapped `(iss, id)` pair to
different instances or reassign it after an instance is retired. It
MUST preserve the existing mapping for a recipient across attestation
renewal and attester-verified key replacement within a continuing
instance. Distinct source identities MUST remain distinct unless
their continuity has been established by a separately specified
procedure as described in {{lifetime}}. Recipient-scoped mappings
limit correlation as described in {{privacy}}.

In the pass-through form, `iss` and `id` are copied from the validated
attestation; this form requires the recipient to trust the Attester
Issuer's namespace directly and MUST be used only with recipients
configured for it. A consuming profile MAY likewise preserve context
from a validated upstream token, but MUST define the trusted upstream
Instance Authority and the association being preserved. The issuer
MUST NOT copy unvalidated client-supplied context. The `iss` and `id`
members MUST be nonempty strings. Additional members MAY be defined by
other profiles. A recipient MUST ignore members it does not recognize. A profile
defining additional members MUST specify their processing for
recipients implementing that profile and MUST NOT change the meaning
of `iss` or `id`.

A recipient MAY correlate activity using the opaque `(iss, id)` pair
without knowing whether it identifies an installation or an execution.
If its processing depends on that distinction, it MUST establish the
granularity and continuity rules through trusted configuration or a
consuming profile before applying that processing. It MUST NOT infer
those rules by parsing the identifier.

~~~ json
{
  "client_instance": {
    "iss": "https://idp.example/tenant/acme",
    "id": "m-f61783ea4cb24d098851d34960a274be"
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

# Security and Privacy Considerations {#privacy}

The considerations of {{ATTEST}} and {{RFC8725}} apply. Compromise of
an attester can allow impersonation of any instance within its approved
client associations. Receivers MUST
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
Receiver, freshness, and key possession under the selected ATTEST
proof method. An instance identifier, including a per-Receiver
identifier, MUST NOT
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
| Container orchestrator or workload runtime | Execution | Runtime-assigned identity for one container execution; a restart yields a new identifier | Processes within that container execution |
| Function or job scheduler | Execution | Per-invocation or per-job environment identity | Retries that the platform treats as the same job |

An installation attester that cannot verify continuity across a
restore or clone MUST issue a new identifier, as {{lifetime}}
requires. An execution attester that reuses a key across restarts
still issues a new identifier for each execution; the key is not
the identifier. A shared signing key across replicas prevents
instance identification at any granularity finer than the key.

## Managed Application
{:numbered="false"}

Two installations of a managed mobile application use the same OAuth
`client_id`. An enterprise attester validates installation evidence and
possession of each installation's key, then assigns distinct
`client_instance_id` values. Each installation presents its attestation
and proof to the IdP, which uses the issuer-qualified identifier for
audit correlation. When the attester verifies continuity across key
replacement, it retains that installation's identifier; a clone or new
installation receives a different identifier.

## Workload Replicas
{:numbered="false"}

Two container replicas share a SPIFFE workload identity but hold
separate Client Instance Keys. A runtime attester validates the workload
identity, authenticated evidence identifying each container execution,
and possession of its key. It assigns each execution a distinct
`client_instance_id` and issues a Client Attestation for the configured
Logical Client. The IdP validates the attestation and proof to correlate
requests from each execution. Renewal within that execution preserves
its identifier; a new execution receives another. The shared workload
identity alone cannot establish this distinction.

## Downstream Audit Correlation
{:numbered="false"}

After validating an attestation and proof, an IdP maps the instance to
a recipient-scoped identifier and includes `client_instance` in a token
or introspection response. Its `iss` identifies the IdP and its `id`
identifies the instance in that recipient's namespace. The recipient
validates the token or authenticated response and uses the pair for
local audit correlation without receiving the original attestation.
The IdP preserves the mapping across attester-verified key changes and
uses different mappings for other recipients to limit correlation.
The token issuer authenticates this context; it conveys no additional
authorization or proof of possession.

An IdP needing only local correlation can instead use its internal
enrollment mapping and ATTEST alone, without this profile.

## AAuth Agent Provider
{:numbered="false"}

An AAuth Agent Provider {{AAUTH}} could also act as a Client Attester
for OAuth deployments. When its enrollment records and validated
evidence establish installation continuity and key possession, it can
issue a Client Attestation using the approved OAuth `client_id` as
`sub` and an opaque `client_instance_id` for that installation. The
client presents this credential using ATTEST's proof mechanism.
Native AAuth agent tokens and HTTP signature processing retain their
own semantics; this example defines no token conversion or enrollment
binding and introduces no AAuth requirement for this profile.

# Interoperability Checklist
{:numbered="false"}

This informative checklist summarizes expected behavior under the
normative requirements above. Each case assumes successful ATTEST
validation except where the stated condition prevents acceptance.

| Input or event | Expected result |
|---|---|
| Renewed attestation for the same instance | Same instance identity and existing recipient mapping |
| Attester-verified replacement key | Same identity and mapping; existing token bindings remain unchanged |
| Cloned installation, or new execution at execution granularity | New instance identity and distinct downstream mapping |
| Equal identifier strings from different Attester Issuers | Distinct identities; equality alone does not establish continuity |
| Context with an unapproved Instance Authority | Reject context; reject the request when context is required |
| Different recipients when recipient-scoped mapping is used | Different mapped identifiers, each stable within its recipient scope |
| Valid instance evidence without delegation authorization | No actor relationship inferred |

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

This document preserves the key-independent instance identity,
continuity, and audit-correlation concerns explored in
draft-mcguinness-oauth-client-instance-assertion and
draft-mcguinness-oauth-ai-agent-instance. It replaces that part of
those proposals with an optional claims profile of ATTEST; it is not
a wire-compatible replacement for either draft. It does not retain
their standalone assertion protocol or automatic representation of
instances as token subjects or actors.

The proposed division of responsibilities places governed agent
identity and grant issuance in
draft-mcguinness-oauth-workload-agent-federation, actor representation
in {{ACTOR-PROFILE}}, and optional runtime identification here.
Consuming authorization profiles define the relationships between
those identities; this profile does not require their adoption.

* Defined issuer-qualified instance identity, continuity and privacy
  rules, and optional `client_instance` context with `iss` and `id`.
* Scoped the document to an optional claims profile, stated when ATTEST
  alone is sufficient, and inherited its authentication, proof,
  algorithm, freshness, and token-binding requirements unchanged.
* Distinguished client, principal, and instance identities; clarified
  issuance context, mapped identifier continuity, and issuer changes;
  added an informative interoperability checklist.
