---
title: "Client Instance Identification for Attestation-Based Client Authentication"
abbrev: "Client Instance Identification"
category: std
docname: draft-mcguinness-oauth-client-instance-id-latest
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
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-id.html"
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
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  RFC7591:
  ACTOR-PROFILE: I-D.mcguinness-oauth-actor-profile
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  AGENT-FEDERATION:
    title: "OAuth 2.0 Profile for Agent Federation"
    target: https://mcguinness.github.io/draft-mcguinness-oauth-workload-agent-federation/draft-mcguinness-oauth-workload-agent-federation.html
    author:
      - fullname: Karl McGuinness
    date: 2026-09-11
--- abstract

This specification defines an optional claims profile of OAuth 2.0
Attestation-Based Client Authentication. It adds an issuer-qualified
client instance identifier, continuity and privacy rules, and optional
instance context in tokens and introspection responses. The profile
supports correlation across attestations and verified key changes;
authentication, proof of possession, and token binding follow the base
specification.

--- middle

# Introduction

Attestation-Based Client Authentication {{ATTEST}} authenticates a
Client Instance through an attestation and proof of possession of its
key. A replacement key and attestation do not, by themselves, tell a
Receiver that this is the same installation or execution. Independent
systems need a common identifier to correlate that instance while
distinguishing clones and new executions.

This document profiles the additional claims permitted by
{{ATTEST, Section 13}}:

* `client_instance_id` identifies an instance within an attester's
  namespace, independently of its current key.
* `client_instance` optionally conveys validated instance context to
  downstream recipients without forwarding the original attestation.

Use this profile when parties need to exchange instance identity across
attestations or verified key changes. ATTEST alone is sufficient when
correlation need only last for the current key or an identity provider
(IdP) can satisfy its needs through internal enrollment mappings.

## Identity and Authorization

The following identities serve different purposes:

| Identity | Purpose |
|---|---|
| Logical Client (`client_id`) | Identifies the OAuth client |
| Authorization principal | Identifies the subject or delegated actor under the applicable authorization profile |
| Client Instance | Identifies an installation or execution of client software |

Several instances can operate for one principal. Replacing an instance
need not change that principal or create a delegation relationship.
{{AGENT-FEDERATION}} defines agent identity and grant issuance;
{{ACTOR-PROFILE}} addresses actor representation. Neither is required
to implement this profile.

## Scope

This profile inherits ATTEST authentication, proof, and token-binding
requirements. It defines no enrollment or key-rotation protocol and
does not authorize transferring existing grants, sessions, or tokens
to a replacement key.

An IdP can act solely as a Receiver of attestations. Registry import
alone does not establish instance continuity. Credentials other than
Client Attestations, including platform-issued JWTs, require a separate
carrier profile; none is defined here.

Together with Agent Federation, this document replaces the relevant
parts of draft-mcguinness-oauth-client-instance-assertion and
draft-mcguinness-oauth-ai-agent-instance, which are not being progressed.
It is not wire-compatible with either.

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
: A reference to an instance whose participation was validated for token
  issuance. It conveys identity, not authorization or proof of current
  possession.

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

## Configuration {#profile-configuration}

The client and Receiver MUST establish use of this profile through
administrative configuration before processing requests. The
configuration MUST identify:

* the Logical Client and its authentication method;
* the attesters authorized to identify that client's instances; and
* the instance granularity and continuity rules agreed with those
  attesters ({{lifetime}}).

A recipient requiring Instance Context MUST establish that requirement
through trusted configuration. An instance claim MUST NOT select this
profile or change the client's authentication method. This document
adds no discovery or client metadata parameters.

## Attester Authority

The Receiver's configuration is the sole source of attester authority
for a Logical Client. The Receiver MUST associate each approved
Attester Issuer with the keys used for ATTEST validation and compare
issuer and client identifiers as exact strings, without URI
normalization.

The Receiver MUST NOT establish attester authority solely from:

* a credential's `iss` or proof of key possession; or
* client-published metadata, including attester lists supplied through
  dynamic registration {{RFC7591}} or a client identifier metadata
  document {{CIMD}}.

Trust management and verification-key resolution otherwise follow
ATTEST. Withdrawal of attester trust MUST take effect on subsequent
authentication.

# Client Attestation Claims {#claims}

All ATTEST requirements apply. This profile retains
`typ=oauth-client-attestation+jwt` and `sub=client_id`.
The claims `exp` and `cnf` remain required; `iat` remains optional.

## Additional Claims

`iss`:
: REQUIRED. String exactly matching an approved Attester Issuer in
  {{configuration}}.

`client_instance_id`:
: REQUIRED. Nonempty StringOrURI {{RFC7519}}, no longer than 256
  characters, identifying the instance within the attester's namespace.
  The instance identity is `(iss, client_instance_id)`.

The Client Attester MUST:

* generate unpredictable identifiers with at least 128 bits of
  randomness;
* exclude hostnames, user identifiers, and other identifying data; and
* preserve uniqueness and continuity as specified in {{lifetime}}.

Receivers MUST treat identifiers as opaque, accept conforming values
up to 256 characters, and reject longer values. They MUST NOT derive
permissions by parsing an identifier. Errors follow {{errors}}.

## Example

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

## Validation

For a request configured to use this profile, the Receiver MUST:

1. Validate the Client Attestation and proof using the configured
   ATTEST method.
2. Validate the additional claims in {{claims}} and the attester's
   authority for the Logical Client under {{configuration}}.
3. Associate `(iss, client_instance_id)` with the Logical Client and
   validated Client Instance Key.
4. Apply configured instance policy, rejecting a disallowed instance.

An identifier MUST NOT substitute for proof of key possession. Token
binding follows ATTEST and the selected OAuth mechanism. This profile
does not require DPoP combined mode or change token-binding rules.

## Authorization

A Receiver MUST NOT set an access token's `sub`, add `act`, or extend
an actor chain solely because it accepted instance evidence. A
consuming authorization profile MUST define any relationship between
the instance and the token's subject, actor, or other presenter.

## Errors {#errors}

Invalid instance claims or missing required claims result in
`invalid_client_attestation` as defined by ATTEST. Authentication
failures and freshness challenges retain ATTEST error processing.
A failed profile check MUST NOT trigger fallback to processing without
the required instance evidence.

# Instance Lifetime and Key Continuity {#lifetime}

## Assignment and Granularity

The attester MUST assign a distinct identifier to each new instance
at the configured granularity and MUST NOT reassign it, including
after retirement. The following rules apply:

* **Installation:** an identifier can survive process restarts when
  the attester verifies installation continuity. It does not distinguish
  processes within that installation.
* **Execution:** a process or container restart creates a new instance
  and requires a new identifier.
* **Clone:** a cloned installation or independently created execution
  requires a distinct identifier.
* **Granularity change:** changing what an identifier represents
  requires a new identifier.

Other profiles can define additional granularities. A Receiver MUST
NOT treat an installation identifier as identifying its individual
processes.

After suspend/resume or restore, an attester MUST NOT retain an
identifier unless it verifies continuity and prevents independently
restored copies from sharing that identity. Otherwise, it assigns a
new one.

## Renewal and Key Replacement

Within a continuing instance, attestation renewal and verified key
replacement MUST preserve each assigned identifier. A replacement key
requires a new attestation and authenticated evidence binding that
key to the instance.

The following do not establish continuity:

* possession of an identifier, expired attestation, or former public
  key alone; or
* equal identifier strings or a shared key across different Attester
  Issuers.

Receivers MUST NOT infer continuity from those conditions or use a
key thumbprint, certificate serial number, or JWT `jti` as the instance
identifier. Migration across attester authorities requires a separately
specified procedure establishing trust in both authorities and
validated continuity evidence.

Stable identity does not relax refresh-token binding under ATTEST.
Existing grants, sessions, or tokens can move to a replacement key
only through a separately specified authorization procedure.

## Suspension and Retirement

An attester MUST cease issuing attestations for a suspended or retired
instance. A Receiver suspending an instance SHOULD revoke tokens it
issued to that instance or report them inactive through introspection
{{RFC7662}}.

An identifier does not distribute status or invalidate credentials.
Revocation and status propagation beyond these local actions are
outside this profile.

# Conveying Instance Context {#instance-context}

## Claim Format {#context-claims}

An issuer MAY include `client_instance` in a token or introspection
response {{RFC7662}} when the recipient needs validated instance
context. Its value is a JSON object with these members:

`iss`:
: REQUIRED. Nonempty string identifying the Instance Authority. It is
  not necessarily the enclosing token issuer.

`id`:
: REQUIRED. Nonempty StringOrURI identifying the instance within that
  authority's namespace.

Recipients MUST ignore unrecognized members. Profiles defining
additional members MUST specify their processing without changing
the meaning of `iss` or `id`.

~~~ json
{
  "client_instance": {
    "iss": "https://idp.example/tenant/acme",
    "id": "m-f61783ea4cb24d098851d34960a274be"
  }
}
~~~

## Issuance and Mapping

The object MUST identify the instance whose participation and key
possession were validated for issuance. Issuers MUST NOT copy
unvalidated client-supplied context. Two representations are defined:

* **Mapped (RECOMMENDED):** `iss` identifies the Receiver issuing the
  token; `id` is assigned through an authenticated mapping it maintains.
* **Pass-through:** `iss` and `id` retain the attestation's `iss` and
  `client_instance_id`. This form MUST be used only with recipients
  configured to trust that attester's namespace.

A Receiver issuing mapped context MUST:

1. Keep distinct source identities separate unless continuity was
   established under {{lifetime}}.
2. Never assign a mapped `(iss, id)` pair to another instance, including
   after retirement.
3. Preserve each recipient's mapping across attestation renewal and
   verified key replacement within the same instance.

Recipient-scoped mappings limit correlation ({{privacy}}).

## Recipient Processing

Before using Instance Context, a recipient MUST:

1. Validate the enclosing token or authenticated introspection response.
2. Validate the object and required members in {{context-claims}}.
3. Verify that its Instance Authority is either:

   * the token issuer; or
   * a pass-through authority explicitly configured for that token
     issuer and recipient.

4. Reject invalid context. If context is required, also reject the
   request.

Mapped context requires no direct trust in the original attester.
An Instance Authority identifier does not authorize fetching keys from
that location.

Recipients can correlate the opaque `(iss, id)` pair without knowing
its granularity. A recipient whose processing depends on granularity
MUST establish it through trusted configuration or a consuming profile,
not by parsing the identifier.

## Authorization and Token Exchange

Instance Context records validated participation at issuance; it does
not independently authenticate the current token presenter. Proof of
possession follows the enclosing token's binding.

The object MUST NOT be interpreted as an actor, separate token, or
grant of authority. A consuming profile MUST define:

* its association with the token's subject, actor, or other presenter;
* how that association is validated and preserved during exchange; and
* any trusted upstream Instance Authority whose context is retained.

An issuer can preserve validated upstream context under those rules,
subject to the recipient trust checks above.

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

# Security Considerations

The security considerations of {{ATTEST}} and {{RFC8725}} apply.

## Attester Compromise and Assurance

A compromised attester can impersonate instances within its approved
client associations. Receivers MUST limit those associations to the
clients and evidence assurance they trust. Trust withdrawal follows
{{configuration}}; instance suspension follows {{lifetime}}.

Evidence can be self-reported, platform-verified, or hardware-rooted.
An attester MUST NOT claim stronger assurance than its evidence
supports. Receivers MUST configure the assurance required for each
Logical Client rather than infer it from an identifier or attester
name. This profile defines no assurance-level registry.

Instance identity does not prove software behavior or integrity beyond
the evaluated evidence. Runtime isolation and key custody limit what
can be distinguished: holders of a shared private key cannot be
identified individually by proof of that key.

## Attestation Forwarding

Client Attestations have no audience binding. Forwarding resistance
depends on ATTEST proof validation, including the intended Receiver,
freshness, and key possession. An instance identifier, even if scoped
to a Receiver, provides no substitute for that proof.

## Privacy {#privacy}

A stable identifier permits correlation across key changes. Using the
same identifier across Receivers also defeats the unlinkability gained
by using different keys for each Receiver. To limit disclosure:

* Attesters SHOULD assign distinct identifiers per Receiver when
  cross-Receiver correlation is unnecessary, retaining an internal
  mapping. This requires separate attestations, as recommended by
  {{ATTEST, Section 11.1}}.
* Receivers MUST NOT assume identifiers seen by different Receivers
  are comparable.
* Receivers issuing context SHOULD use recipient-scoped mappings when
  broader correlation is unnecessary, retain internal audit mappings,
  and disclose only needed provenance.
* Error responses SHOULD avoid revealing unrelated instance identities.
  Logs MUST NOT contain raw credentials or private keys.

Deployments sharing one identifier across Receivers accept that
correlation as an explicit privacy trade-off.

# IANA Considerations

## JSON Web Token Claims

This document requests the following registrations in the "JSON Web
Token Claims" registry established by {{RFC7519}}. The Change Controller
for both entries is IETF.

| Claim Name | Claim Description | Specification Document(s) |
|---|---|---|
| `client_instance_id` | Issuer-scoped client instance identifier | {{claims}} of this document |
| `client_instance` | Validated client instance context | {{instance-context}} of this document |

## OAuth Token Introspection Response

This document requests the following registration in the "OAuth Token
Introspection Response" registry established by {{RFC7662}}:

* Parameter Name: `client_instance`
* Parameter Description: Validated client instance context
* Change Controller: IETF
* Specification Document(s): {{instance-context}} of this document

These registrations define claims and a response parameter, not subject
or actor profile values.

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

The lifecycle rules in {{lifetime}} apply to each pattern. A device key
alone does not establish installation continuity; a workload identity
alone does not distinguish replicas. Assurance depends on the evidence
actually evaluated, as described in the Security Considerations.

## Managed Application
{:numbered="false"}

Two installations of a managed mobile application share an OAuth
`client_id`:

1. An enterprise attester validates installation evidence and key
   possession, then assigns each installation a distinct identifier.
2. Each installation presents its attestation and proof to the IdP,
   which uses the issuer-qualified identifier for audit correlation.
3. Verified key replacement preserves the identifier; a clone or new
   installation receives another.

## Workload Replicas
{:numbered="false"}

Two container replicas share a SPIFFE workload identity but hold
separate Client Instance Keys:

1. A runtime attester validates workload identity, authenticated
   evidence identifying each execution, and possession of its key.
2. It issues each execution a Client Attestation for the configured
   Logical Client with a distinct `client_instance_id`.
3. The IdP validates the attestation and proof to correlate requests.
   Renewal preserves the identifier; a new execution receives another.

The shared workload identity alone cannot distinguish the replicas.

## Downstream Audit Correlation
{:numbered="false"}

An IdP conveys instance context to a downstream recipient:

1. After validating an attestation and proof, it assigns a
   recipient-scoped identifier and includes `client_instance` in a
   token or introspection response: `iss` identifies the IdP and `id`
   contains the mapped identifier.
2. The recipient validates the token or authenticated response and
   uses the pair for audit correlation without the original attestation.
3. The IdP preserves the mapping across verified key changes and uses
   different mappings for other recipients.

An IdP needing only local correlation can instead use its internal
enrollment mapping and ATTEST alone, without this profile.

## AAuth Agent Provider
{:numbered="false"}

An AAuth Agent Provider {{AAUTH}} can also act as an OAuth Client Attester:

1. Its enrollment records and validated evidence establish installation
   continuity and key possession.
2. It issues a separate Client Attestation with the approved OAuth
   `client_id` as `sub` and an opaque `client_instance_id`.
3. The client presents that credential using ATTEST proof processing.

Native AAuth tokens and HTTP signatures retain their own semantics.
This example defines no token conversion or enrollment binding.

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

# Document History {#history}
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
* Clarified predecessor status, non-ATTEST scope, Receiver-controlled
  attester authority, and evidence assurance.
* Consolidated normative processing, separated lifecycle and context
  rules, and aligned security and IANA sections with RFC conventions.
