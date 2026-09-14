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
  RFC6750:
  RFC7519:
  RFC7662:
  RFC8693:
  RFC8725:
informative:
  AAUTH: I-D.hardt-oauth-aauth-protocol
  RFC2104:
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  RFC7591:
  RFC7636:
  RFC8252:
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
Client Instance to an authorization server or resource server through
an attestation and proof of possession of its key. A replacement key
and attestation do not, by themselves, tell a Receiver that this is the
same installation or execution. Independent systems need a common
identifier to correlate that instance while distinguishing clones and
new executions.

This document profiles the additional claims permitted by
{{ATTEST, Section 13}}:

* `client_instance_id` identifies an instance within an attester's
  namespace, independently of its current key.
* `client_instance` optionally conveys validated instance context to
  downstream recipients without forwarding the original attestation.

Use this profile when parties need to exchange instance identity across
attestations or verified key changes. ATTEST alone is sufficient when
correlation need only last for the current key or a Receiver can
satisfy its needs through internal enrollment mappings.

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

A Receiver can rely on a separate attester to establish instance
continuity. Direct resource-server presentation follows
{{ATTEST, Section 1.1}}, the audience requirement in
{{ATTEST, Section 5.1}}, and the validation rules in
{{ATTEST, Section 4}} and {{ATTEST, Section 7}}. Credentials other than
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
: A party that validates a Client Attestation under this profile,
  such as an authorization server or resource server. A Receiver that
  issues tokens carrying Instance Context also acts as a token issuer.

Recipient:
: A party that consumes Instance Context from a token or introspection
  response. It need not receive the original Client Attestation.

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

Missing required instance claims produce `invalid_client_attestation`
({{errors}}). That shared error reports rejection, not discovery of this
profile; profile selection remains an administrative agreement.

## Attester Authority

The Receiver's configuration is the sole source of attester authority
for a Logical Client. The Receiver MUST associate each approved
Attester Issuer with the keys used for ATTEST validation and compare
issuer and client identifiers as exact, case-sensitive strings, without
URI normalization.

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

## Profile Claim Requirements

`iss`:
: REQUIRED. String exactly matching an approved Attester Issuer in
  {{configuration}}.

`client_instance_id`:
: REQUIRED. Nonempty StringOrURI {{RFC7519}}, no longer than 256
  characters, identifying the instance within the attester's namespace.
  The instance identity is `(iss, client_instance_id)`.

The Client Attester MUST:

* generate identifiers unpredictable to any party other than the
  attester, using at least 128 bits of cryptographically secure randomness
  or at least 128 bits of output from a cryptographically secure keyed
  pseudorandom function;
* exclude runtime hostnames, user identifiers, and other embedded
  instance or user attributes; and
* preserve uniqueness and continuity as specified in {{lifetime}}.

A keyed derivation, such as HMAC {{RFC2104}} over an authenticated
installation identifier, MUST use an attester-held secret with at least
128 bits of entropy. Changes to derivation inputs or secrets do not
relax the continuity and non-reassignment rules in {{lifetime}}.

A URI-form identifier can name the attester's namespace, including its
authority component; the instance-specific portion remains unpredictable
and opaque. The namespace does not establish trust in the identifier.

Receivers MUST treat identifiers as opaque, compare them as exact,
case-sensitive strings without URI normalization, accept conforming
values up to 256 characters, and reject longer values. They MUST NOT
derive permissions by parsing an identifier. Errors follow {{errors}}.

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
4. Apply configured instance policy, rejecting a disallowed instance
   under {{errors}}.

An identifier MUST NOT substitute for proof of key possession. Token
binding follows ATTEST and the selected OAuth mechanism. This profile
does not require DPoP combined mode or change token-binding rules.

When the selected method permits a separate token-binding key, the token
can carry Instance Context associated with the validated Client Instance
Key even though its binding uses another key. The key-continuity rules
in {{lifetime}} concern the Client Instance Key, not that separate key.

## Authorization

A Receiver MUST NOT set an access token's `sub`, add `act`, or extend
an actor chain solely because it accepted instance evidence. A
consuming authorization profile MUST define any relationship between
the instance and the token's subject, actor, or other presenter.

## Errors {#errors}

The Receiver MUST return `invalid_client_attestation` for invalid
instance claims or missing required claims, including an absent
`client_instance_id` when this profile is configured.

When instance policy rejects an unknown, suspended, retired, or otherwise
disallowed instance, the Receiver MUST return the same error and MUST
NOT disclose in the response whether the instance is known or its
lifecycle status. This does not require a registry of known instances.

This profile deliberately reuses ATTEST's validation error for instance
policy rejection, so the error code does not distinguish policy rejection
from an invalid claim. Receivers SHOULD avoid distinguishable response
timing between these failure cases.

Other authentication failures and freshness challenges retain ATTEST
error processing.
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

Recipients MUST compare both members as exact, case-sensitive strings
without URI normalization.

Recipients MUST ignore unrecognized members. Profiles defining
additional members MUST specify their processing without changing
the meaning of `iss` or `id`.

~~~ json
{
  "client_instance": {
    "iss": "https://as.example",
    "id": "m-f61783ea4cb24d098851d34960a274be"
  }
}
~~~

## Issuance and Mapping

The object MUST identify the instance whose participation and key
possession were validated for issuance. Issuers MUST NOT copy
unvalidated client-supplied context. Three representations are defined:

* **Mapped (RECOMMENDED):** `iss` identifies the Receiver issuing the
  token; `id` is assigned through an authenticated mapping it maintains.
* **Pass-through:** `iss` and `id` retain the attestation's `iss` and
  `client_instance_id`. This form MUST be used only with recipients
  configured to trust that attester's namespace.
* **Preserved:** `iss` and `id` retain the values from validated upstream
  token context. This form MUST be used only with recipients configured
  to trust that Instance Authority under {{context-exchange}}.

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
   * an external Instance Authority explicitly configured for that token
     issuer and recipient.

4. Reject invalid context. If context is required and is missing or
   invalid, also reject the request under {{context-errors}}.

Mapped context requires no direct trust in the original attester.
An Instance Authority identifier does not authorize fetching keys from
that location.

Recipients can correlate the opaque `(iss, id)` pair without knowing
its granularity. A recipient whose processing depends on granularity
MUST establish it through trusted configuration or a consuming profile,
not by parsing the identifier.

## Errors {#context-errors}

When required context is missing or invalid, a recipient MUST use:

* `invalid_token` at a resource server, following {{RFC6750, Section 3.1}}
  and the applicable access-token presentation method; or
* `invalid_request` when rejecting a subject or actor token in an
  RFC 8693 exchange, as required by {{RFC8693, Section 2.2.2}}.

Other consuming profiles MUST specify their error mapping. These
errors concern token context; failures validating a directly presented
Client Attestation follow {{errors}}.

## Authorization and Token Exchange {#context-exchange}

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

# Instance Lifecycle Example {#lifecycle-example}
{:numbered="false"}

This example is informative. An attester identifies application
installations under one Logical Client. `I1` and `I2` are symbolic
labels for distinct opaque identifiers; `K1`, `K2`, and `K3` denote
Client Instance Keys.

| Event | Attester-validated result | Identifier | Key |
|---|---|---|---|
| Initial enrollment | New installation | `I1` | `K1` |
| Attestation renewal | Same installation | `I1` | `K1` |
| Verified key replacement | Same installation, new key | `I1` | `K2` |
| Clone enrolled separately | Different installation | `I2` | `K3` |

Existing recipient mappings for `I1` remain stable across renewal and
verified key replacement. A refresh token bound to `K1` cannot be used
with `K2` merely because the instance identifier is unchanged.

# AAuth Agent Provider Example {#aauth-example}
{:numbered="false"}

This informative example shows an Agent Provider (AP) from {{AAUTH}}
also acting as an OAuth Client Attester for a managed agent harness.
The AP supports both credential formats; its native AAuth agent token
(`typ=aa-agent+jwt`) is not a Client Attestation. This example defines
no conversion or enrollment protocol.

The OAuth authorization server (AS) is configured to trust the AP as
an attester for Logical Client `C1` and to permit that client to use the
client credentials grant for the target resource. AAuth metadata alone
does not establish this trust. `I1`, `K1`, and `M1` below are symbolic
labels for an instance identifier, its key, and a recipient-scoped
identifier, respectively.

~~~ ascii-art
Agent harness       AP / Attester       OAuth AS          Resource
     |                    |                 |                 |
     |-(1) Enrollment----->                 |                 |
     <-(2) Attestation----|                 |                 |
     |                    |                 |                 |
     |-(3) Grant + attestation + proof------>                 |
     <-(4) Token carrying instance context--|                 |
     |                    |                 |                 |
     |-(5) Resource request + access token + DPoP proof------->
     <-Resource response--------------------------------------|
~~~

1. The harness proves possession of `K1` and supplies enrollment
   evidence. The AP validates the managed installation and assigns
   `I1`. An AAuth agent identifier or a new signing key alone does not
   establish installation continuity.
2. The AP issues a separate Client Attestation with
   `typ=oauth-client-attestation+jwt`, `iss` identifying the AP,
   `sub=C1`, `client_instance_id=I1`, `cnf.jwk` containing the public
   part of `K1`, and `exp` bounding its lifetime.
3. The harness sends `grant_type=client_credentials` and `client_id=C1`
   to the AS token endpoint, presenting the attestation and proof as
   specified by {{ATTEST}}. This example uses its combined DPoP mode
   with `K1`; native AAuth HTTP Message Signatures are not substituted
   for the OAuth proof.
4. The AS validates the attestation, proof, and instance policy, and
   independently authorizes the grant. It issues a DPoP-bound access
   token and includes `client_instance` with `iss` identifying the AS
   and `id=M1`, mapped from the AP's `(iss, I1)` for this resource.
5. The resource validates the access token and DPoP proof, applies its
   authorization policy, and processes the context under
   {{instance-context}}. It can record `M1` for audit without receiving
   the original attestation or trusting the AP directly.

After verified replacement of `K1`, the AP retains `I1` and the AS
retains `M1`, as in {{lifecycle-example}}. Neither identifier determines
the token's subject or creates an `act` claim; delegated access would
require a separate authorization grant and its delegation semantics.

# SPIFFE Workload Example {#spiffe-example}
{:numbered="false"}

This informative example adds execution-level identification to a
SPIFFE deployment where replicas share the SPIFFE ID
`spiffe://example.org/agent-worker`. Direct OAuth authentication using
SVIDs follows {{SPIFFE-OAUTH}} and remains sufficient when that workload
identity meets the deployment's needs. Here, a workload attester issues
a separate Client Attestation to distinguish executions; this is a
deployment pattern, not an additional requirement on SPIFFE clients.

The workload obtains an X.509-SVID through the SPIFFE Workload API.
The attester trusts its SPIFFE trust domain, maps the authorized SPIFFE
ID to Logical Client `C1`, and can verify execution evidence from the
managed runtime. The OAuth AS separately trusts the attester for `C1`
and permits the client credentials grant for the target resource.
`I1`, `K1`, and `M1` are symbolic instance, key, and mapped-identifier
labels as in {{aauth-example}}.

~~~ ascii-art
Workload            Workload attester   OAuth AS          Resource
     |                    |                 |                 |
     |-(1) mTLS enrollment>                 |                 |
     <-(2) Attestation----|                 |                 |
     |                    |                 |                 |
     |-(3) Grant + attestation + proof------>                 |
     <-(4) Token carrying instance context--|                 |
     |                    |                 |                 |
     |-(5) Resource request + access token + DPoP proof------->
     <-Resource response--------------------------------------|
~~~

1. The workload authenticates to the attester using its X.509-SVID
   over mutual TLS and proves possession of a separate Client Instance
   Key `K1`. The attester validates the SVID and correlates the request
   and `K1` with authenticated runtime evidence identifying this
   execution, then assigns `I1`. The shared SPIFFE ID or an unverified
   container identifier alone cannot distinguish replicas. The
   enrollment and runtime-evidence mechanisms are deployment-specific.
2. The attester issues a Client Attestation with
   `typ=oauth-client-attestation+jwt`, its own `iss`, `sub=C1`,
   `client_instance_id=I1`, `cnf.jwk` containing the public part of
   `K1`, and `exp`. The SPIFFE trust domain and OAuth attester issuer
   remain separate trust relationships.
3. The workload sends `grant_type=client_credentials` and `client_id=C1`
   with the attestation and combined DPoP proof using `K1` under
   {{ATTEST}}. This request uses attestation-based authentication;
   it does not also present the SVID as an OAuth client credential.
4. The AS validates the attestation, proof, and instance policy and
   authorizes the grant. It issues a DPoP-bound access token carrying
   `client_instance` with its own `iss` and recipient-scoped `id=M1`.
5. The resource validates the token, proof, and context under
   {{instance-context}}. It can correlate this execution for audit
   without validating SVIDs or trusting the workload attester directly.

SVID renewal alone neither creates a new instance nor proves continuity
for attestation renewal. Verified continuity of the same execution
preserves `I1`; a restart or another replica receives a new identifier
even when it uses the same SPIFFE ID. Instance Context does not turn
that execution into an authorization subject or delegated actor.

# Managed Device Example {#managed-device-example}
{:numbered="false"}

This informative example identifies an agent harness installation on
an enterprise-managed device. A device-management service, or an
attester it supports, verifies installation evidence and issues Client
Attestations. Device enrollment alone does not identify a particular
application installation or authorize access to a user's resources.

The device is already enrolled in management. The OAuth AS is
configured to trust the attester for the harness's Logical Client `C1`.
This example uses installation granularity and a user-authorized
authorization code grant. `I1`, `K1`, and `M1` denote the installation
identifier, Client Instance Key, and recipient-scoped identifier.

~~~ ascii-art
Agent harness       Managed attester    OAuth AS          Resource
     |                    |                 |                 |
     |-(1) App evidence--->                 |                 |
     <-(2) Attestation----|                 |                 |
     |                    |                 |                 |
     |-(3) Authorization via browser------->                 |
     <-Authorization code via redirect------|                 |
     |-(4) Code + attestation + proofs------>                 |
     <-(5) Token carrying instance context--|                 |
     |                    |                 |                 |
     |-(6) Resource request + access token + DPoP proof------->
     <-Resource response--------------------------------------|
~~~

1. The harness creates `K1` in platform-protected key storage and
   proves possession to the attester. The attester validates device
   enrollment and authenticated evidence binding `K1` to the approved
   harness installation, for example from a trusted local management
   component that verifies the calling application. It assigns `I1`.
   Key storage alone does not establish that binding; the evidence
   and enrollment mechanisms are deployment-specific.
2. The attester issues a Client Attestation with
   `typ=oauth-client-attestation+jwt`, its own `iss`, `sub=C1`,
   `client_instance_id=I1`, `cnf.jwk` containing the public part of
   `K1`, and `exp`. `I1` is opaque; it does not encode a device serial
   number, management identifier, or user account.
3. The harness initiates authorization in an external browser under
   {{RFC8252}}, using PKCE with the `S256` challenge method
   {{RFC7636}}. The AS authenticates the user and obtains authorization
   for the requested access, then returns a code through the registered
   redirect URI. The diagram abbreviates these browser interactions.
4. The harness redeems the code with `client_id=C1`, the redirect URI,
   and PKCE verifier. It also presents the Client Attestation and
   combined DPoP proof using `K1` under {{ATTEST}}. Client attestation
   does not replace PKCE or the user's authorization.
5. The AS validates the code, PKCE verifier, attestation, proof, and
   instance policy. It issues a DPoP-bound access token for the
   authorized access, with `client_instance` containing its own `iss`
   and recipient-scoped `id=M1`. The context adds no `act` claim;
   subject and delegation semantics follow the authorization profile.
6. The resource validates the access token, DPoP proof, and context
   under {{instance-context}}, and applies its authorization policy.
   It can correlate the installation for audit without receiving the
   device-management identifier or original enrollment evidence.

A process restart retains `I1` when the attester verifies installation
continuity; a separate installation or clone receives a new identifier.
Verified key replacement retains `I1` and `M1` without transferring
tokens bound to the old key. If management is withdrawn, the attester
stops issuing attestations for that installation; downstream token
handling follows {{lifetime}}, not an implied device-status signal.

# Document History {#history}
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Initial draft.
