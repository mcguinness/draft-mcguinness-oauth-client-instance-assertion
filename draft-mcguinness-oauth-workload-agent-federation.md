---
title: "OAuth 2.0 Workload Agent Federation"
abbrev: "Workload Agent Federation"
category: std

docname: draft-mcguinness-oauth-workload-agent-federation-latest
submissiontype: IETF
stand_alone: yes
date: 2026-09-11
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
keyword:
 - OAuth
 - agent federation
 - workload identity
 - agent registry
 - token exchange

venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "mcguinness/draft-mcguinness-oauth-client-instance-assertion"
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-workload-agent-federation.html"

author:
 - fullname: Karl McGuinness
   organization: Independent
   email: public@karlmcguinness.com

normative:
  RFC6749:
  RFC7515:
  RFC7518:
  RFC7519:
  RFC7523:
  RFC7662:
  RFC8414:
  RFC8693:
  RFC8707:
  RFC8725:
  RFC9449:
  CIA: I-D.mcguinness-oauth-client-instance-assertion
  AGENT: I-D.mcguinness-oauth-ai-agent-instance
  WAG: I-D.carleton-workload-authz-grant

informative:
  ID-JAG: I-D.ietf-oauth-identity-assertion-authz-grant
  SCIM-AGENT: I-D.wzdk-scim-agent-resource

--- abstract

This specification profiles OAuth 2.0 Token Exchange to let an
agent instance obtain a Workload Authorization Grant from an
identity provider and redeem it at a resource authorization
server. The identity provider maintains an agent registry,
federates instance evidence from agent platforms, and authorizes
access for agents acting as themselves. The resource authorization
server trusts the identity provider as grant issuer and retains
control over resource access. The profile defines a mandatory
instance-evidence input, registry resolution, discovery, grant
issuance and redemption, and proof-of-possession requirements.

--- middle

# Introduction

An enterprise can use an identity provider (IdP) to manage agents
from multiple platforms and authorize their access to applications.
Platforms supply authenticated runtime evidence; the IdP resolves
that evidence to a registered agent and issues an application-bound
Workload Authorization Grant (WAG). Downstream applications need
trust in the IdP rather than a separate federation integration with
every agent platform.

This document defines the complete exchange for an agent acting as
itself. Access on behalf of a user remains a distinct authorization
case, addressed by {{ID-JAG}} and applicable delegation profiles.
A user who owns or administers an agent is not thereby the subject
on whose behalf it acts.

{{CIA}} supplies instance evidence and client binding. {{AGENT}}
defines agent and runtime identity and provenance claims. {{WAG}}
supplies the authorization grant. This document selects a common
input and binding mechanism and defines the registry and policy
processing that connects them. It does not define a registry API,
agent discovery protocol, or permission language.

# Conventions and Roles

{::boilerplate bcp14-tagged}

Registered Agent:
: An agent principal with an IdP-managed identifier, administrative
  status, federation bindings, and application assignments. It may
  have several concurrent or successive Agent Instances.

Agent Instance:
: A concrete execution of an agent, as defined by {{AGENT}}. Each
  instance holds its own proof-of-possession key.

Agent Platform:
: The system operating agent instances and provisioning or
  synchronizing their registered identities. Its trusted Agent
  Attester issues instance evidence, possibly using a separate
  workload identity service.

IdP:
: The authorization server that maintains the agent registry,
  validates federated evidence, and issues WAGs. It acts as WAG
  issuer for one tenancy under each issuer identifier.

Resource Authorization Server (RAS):
: The authorization server that accepts WAGs from trusted IdPs and
  issues access tokens for its Resource Servers (RSes).

# Deployment and Trust {#deployment}

~~~ ascii-art
 Agent Platform       Agent Instance        IdP              RAS
       |                     |               |                |
       |-- registry synchronization -------->|                |
       |-- CIA ------------->|               |                |
       |                     |               |                |
       |                     |-- exchange -->|                |
       |                     |   CIA + DPoP  |                |
       |                     |<-- WAG -------|                |
       |                     |               |                |
       |                     |-- WAG + DPoP ------------------>|
       |                     |<-- resource access token ------|
~~~

The client integration at the IdP represents a logical platform
application, not a separate OAuth registration for every agent.
The IdP MUST approve its client metadata and acceptable instance
issuers under administrative policy. A client-published
`instance_issuers` entry alone MUST NOT authorize federation into
an enterprise agent or application assignment.

The RAS MUST establish an explicit trust relationship authorizing
the IdP issuer to issue workload grants for a particular local
tenancy and set of resources. Existing user SSO trust does not
implicitly grant that authority. The IdP MUST maintain a distinct
issuer identifier for each tenancy, following {{WAG}}; keys and
subject resolution MUST be scoped to that issuer. This profile
does not define a shared-issuer tenant-claim alternative.

Metadata and key locations MUST be obtained from trusted
configuration or authenticated discovery for the approved issuer.
A token's untrusted key-location headers MUST NOT establish trust.
Discovery advertises capability; registry and RAS configuration
establish authorization.

# Agent Registry Binding {#registry}

The registry MUST maintain the following logical information; this
list defines processing requirements, not a provisioning schema:

| Information | Meaning |
| --- | --- |
| Canonical agent identifier | Immutable IdP-scoped principal identifier, never reassigned |
| Administrative status | Whether the agent is enabled for new grants |
| Federation bindings | Approved input issuer, IdP client identifier, and platform agent identifier |
| Application assignments | Permitted RAS issuers, resources, and maximum scopes |
| Attribute authority | Which provisioning or attestation sources may supply each authorization or provenance attribute |

The IdP resolves the exact tuple `(CIA.iss, CIA.client_id,
CIA.agent_id)` through an approved federation binding to one
Registered Agent. This tuple MUST NOT resolve to multiple agents.
The IdP MUST reject unknown, ambiguous, or disabled identities.
It MUST NOT resolve agents by display name, model, platform
product name, key thumbprint, or an unqualified `externalId`.

The CIA's `sub` / `agent_instance_id` identifies the runtime;
its `agent_id` identifies the platform's logical agent. The
Attester MUST authenticate the runtime's relationship to that
agent before asserting those claims, per {{AGENT}}. The IdP MUST
validate that relationship under the approved binding and record
which canonical agent the runtime represents. Conflicting runtime
assignments MUST be rejected.

Provisioning MAY use {{SCIM-AGENT}}, another trusted connector, or
administrative configuration. When SCIM is used, the connector's
identity and issuer context qualify `externalId`; copying a SCIM
record does not by itself create a federation binding. Only
administratively authorized sources may establish or change
bindings and assignments. Just-in-time creation MAY occur under
such a policy before issuance; a valid signature alone does not
authorize creation, reactivation, or new application assignments.

The IdP MUST maintain an issuer-scoped, non-reassigned runtime
identifier derived from the authenticated `(CIA.iss, CIA.sub)`
identity, independently of its key. It MAY preserve the incoming
identifier when its namespace is trusted and collision-free.
The WAG uses the IdP's canonical agent and runtime identifiers;
the IdP retains the original identifiers and their mappings for
audit. Both identifiers SHOULD be URIs within controlled
namespaces. Neither is inferred from URI structure at the RS.

# Discovery and Client Configuration {#metadata}

An IdP or RAS implementing this profile MUST publish the
`workload_agent_federation` member in its OAuth authorization
server metadata ({{RFC8414}}). The member is a JSON object:

`roles`:
: REQUIRED. Nonempty array containing `issuer`,
  `resource_authorization_server`, or both.

`subject_token_types_supported`:
: REQUIRED for the `issuer` role. Array containing at least
  `urn:ietf:params:oauth:token-type:client-instance-jwt`.
  Additional types require an explicitly defined input profile
  with equivalent identity, client, registry, and key validation.

`grant_signing_alg_values_supported`:
: REQUIRED. Nonempty array of JWS algorithms supported for issuing
  or validating WAGs, according to the advertised role. If both
  roles are advertised, listed algorithms apply to both. `ES256`
  MUST be supported. Symmetric MAC algorithms and `none` MUST NOT
  be listed or accepted.

The IdP MUST advertise the RFC 8693 token-exchange grant and
`client_instance_assertion` client authentication method. The RAS
MUST advertise the RFC 7523 JWT bearer grant. Both MUST advertise
DPoP support using `dpop_signing_alg_values_supported` and MUST
support `ES256` DPoP proofs. Other asymmetric algorithms MAY be
used by agreement through these metadata values.

The instance MUST verify issuer-role support at the IdP and
redemption-role support at the RAS before depending on this
profile. Missing metadata means this profile is not advertised;
a generic JWT or bearer fallback MUST NOT be attempted. Supported
algorithms remain subject to issuer-specific trust configuration.

The mandatory input uses approved CIA client metadata, including
`instance_issuers`, `ai_agent_instance_profile: true`, and
`token_endpoint_auth_method: client_instance_assertion`. Other
client authentication methods MAY be supported; a CIA MUST NOT
replace a separately registered method without agreement.
A registration or grant-support flag does not confer application
assignments. Client registration at the RAS is not required by
this profile.

# Obtaining a WAG {#issuance}

## Request {#exchange-request}

The instance sends an RFC 8693 token request to the IdP with a
resource indicator per {{RFC8707}} and the following parameters:

| Parameter | Required value or meaning |
| --- | --- |
| `grant_type` | `urn:ietf:params:oauth:grant-type:token-exchange` |
| `requested_token_type` | `urn:ietf:params:oauth:token-type:wag` |
| `subject_token` | Agent-profiled CIA issued for this IdP |
| `subject_token_type` | `urn:ietf:params:oauth:token-type:client-instance-jwt` |
| `client_id` | Approved client integration at the IdP |
| `audience` | Exactly one target RAS issuer identifier |
| `resource` | Exactly one target API resource URI |
| `scope` | Nonempty requested scope string for that resource |

The request MUST contain a DPoP proof made with the key in the
CIA's `cnf.jkt`. The CIA MUST contain `client_id`, `agent_id`,
`agent_instance_id`, and `cnf.jkt`, and its `sub` MUST equal
`agent_instance_id`. Its `aud` MUST be the IdP issuer identifier.
The CIA lifetime MUST NOT exceed 300 seconds. Raw bearer workload
credentials without the required agent claims and key binding
are not a conforming input; a trusted workload identity adapter
can issue the required CIA after authenticating the workload.

For this specifically requested output profile, CIA is subject
identity evidence in `subject_token`. This document profiles its
validation and, where configured, client authentication, without
using CIA's delegated access-token representation. The request
MUST NOT contain `actor_token`, `actor_token_type`, or
`client_instance_assertion`. The CIA is not a user authorization
grant and the request does not require a preliminary IdP access
token. Ordinary CIA token exchanges retain their actor-token
presentation and delegation rules.

## IdP Processing {#idp-processing}

The IdP MUST perform the following checks before issuing a WAG:

1. Validate request syntax, supported types, and approved client
   configuration. Validate the CIA's signature, issuer descriptor,
   JWT type, time claims, exact audience and `client_id` binding,
   and agent claims per {{CIA}} and {{AGENT}}. Reject an `act`
   claim in the CIA; this profile does not accept delegated input.
2. Validate the DPoP proof for this token endpoint per {{RFC9449}}
   and match its JWK thumbprint to `cnf.jkt`. Use the CIA
   instance-assertion authentication procedure when that method
   is registered, substituting `subject_token` for its normal
   presentation slot. All authentication checks still apply.
   Otherwise, independently authenticate the registered client.
3. Resolve the Registered Agent and runtime under {{registry}}.
   Evaluate current administrative status, attestation freshness,
   and authorization to execute as that agent. Resolve requested
   RAS and resource against approved application assignments.
4. Compute granted scope as a nonempty subset of the requested
   scopes permitted by IdP policy for that agent and resource.
   The IdP MUST NOT import requester-supplied roles or groups as
   authority. Attribute sources follow the registry's policy.
5. Atomically reject reuse of an accepted CIA `(iss, jti)` through
   its expiry, including accepted clock skew. Perform this replay
   check once for a successful request, even when the same CIA
   authenticates the client and supplies subject evidence.
6. Issue a WAG per {{grant}} and record the canonical agent,
   originating runtime identity, key, target, authorization
   decision, and grant `jti` for audit.

A DPoP proof establishes key possession, not the key's authority
to represent an agent. That authority comes from validated
instance evidence and registry binding. The IdP MUST NOT bind a
WAG to an arbitrary requester-selected key.

## WAG Contents {#grant}

The WAG is a signed JWT ({{RFC7519}}) conforming to {{WAG}} and
the following additional requirements. JWS signing follows
{{RFC7515}} and {{RFC7518}}. The IdP MUST sign it with an approved
asymmetric key published for its tenancy issuer. Its protected
`typ` header MUST be `oauth-wag+jwt`.

| Claim | Requirement |
| --- | --- |
| `iss` | Exact trusted IdP tenancy issuer |
| `sub` | Canonical Registered Agent identifier |
| `agent_id` | Equal to `sub` |
| `agent_instance_id` | Canonical identifier of the validated runtime |
| `aud` | Single string equal to the approved RAS issuer identifier |
| `resource` | Single string equal to the approved target API URI |
| `scope` | Nonempty scope string approved by the IdP |
| `cnf` | Contains `jkt` equal to the validated instance key thumbprint |
| `iat`, `exp`, `jti` | Issuance time, expiration time, and fresh unique grant identifier |

The WAG MUST NOT contain `act`. A runtime implementing a
Registered Agent does not create delegation from that agent to
itself. The identifiers and provenance semantics are defined by
{{AGENT}}; `sub` need not equal `agent_instance_id`.

The time claims are NumericDate values; `exp` MUST be later than
`iat` and no more than 300 seconds after it. The grant's expiration
MUST NOT exceed the CIA expiration. The IdP MUST include only
validated, sufficiently fresh provenance it is authorized to
reassert. Optional WAG properties retain their issuer-scoped
meaning and cannot expand the scope ceiling. Raw `agent_runtime`
evidence MUST NOT be included in this profile's WAG; the IdP
consumes it when evaluating issuance policy.

The IdP MUST retain authority over canonical identity, status,
and assignments even when another system attests runtime facts.
Issuer trust does not imply that the IdP independently measured
the runtime or model.

## Response {#exchange-response}

The successful RFC 8693 response MUST include:

* `access_token`: the WAG JWT;
* `issued_token_type`: `urn:ietf:params:oauth:token-type:wag`;
* `token_type`: `N_A`;
* `expires_in`: the WAG's remaining lifetime in seconds; and
* `scope`: the scope approved in the WAG.

The IdP MUST NOT issue a refresh token in this response. The
instance MUST verify that the returned token type is WAG and that
the grant's target and binding agree with its request and key.
A mismatch or absent binding is an error, not permission to retry
without proof. Further WAGs require fresh evidence and another
policy evaluation.

# Redeeming a WAG {#redemption}

The instance presents the WAG in `assertion` with
`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`, exactly
one `resource`, and a fresh DPoP proof for the RAS token endpoint
made with the same instance key. `scope` MAY request a subset of
the WAG's scopes; omission requests the WAG's granted scopes.
The request MUST NOT include `client_instance_assertion`,
`actor_token`, or `actor_token_type`. Client authentication is
not required at the RAS by this profile: the IdP grant and bound
instance key establish the presenting principal. Separate client
authentication, if required
by deployment policy, MUST NOT alter that identity or relax the
grant's restrictions.

The RAS MUST:

1. Validate the JWT signature, protected `typ`, allowed algorithm,
   exact trusted issuer, required claim types, and time claims.
   Enforce the lifetime bound in {{grant}} and reject future `iat`
   values beyond the configured clock-skew allowance.
   Resolve signing keys only within that issuer's trust record.
2. Require `aud` to equal its issuer identifier and verify the
   issuer-to-local-tenancy authorization. Require the requested
   `resource` to equal the grant's resource and belong to that
   configured tenancy and RAS. Comparisons are exact strings;
   URI normalization MUST NOT establish identity or authorization.
3. Resolve `(iss, sub)` to the registered workload principal under
   local policy. A local account MAY be created just in time under
   the trusted assignment policy; a grant MUST NOT create or
   reactivate a disabled account contrary to local policy.
4. Require `agent_id == sub`, a valid runtime identifier, no `act`,
   and an instance `cnf.jkt`. Validate the DPoP proof per
   {{RFC9449}} and require its key thumbprint to equal that value.
5. Require any requested scope to be a subset of the WAG scope.
   Apply local authorization policy, issuing only a nonempty
   subset of both that request and the IdP-approved scope.
6. Atomically reject reuse of an accepted `(iss, jti)` through the
   grant's expiration, including accepted clock skew, and issue
   a DPoP-bound access token for the approved resource and key.

The RAS MUST NOT issue a bearer access token or refresh token.
The access-token response uses `token_type: DPoP` and reports its
actual scope and lifetime. Access tokens MUST expire within 300
seconds of issuance. They can outlive the redeemed WAG; expiry of
a consumed grant is not access-token revocation.

## Resource Token Representation {#resource-token}

Access tokens and active introspection responses MUST identify
the Registered Agent as `sub`, include `sub_profile` containing
`ai_agent`, and convey `agent_instance_id` and `cnf.jkt`. The RAS
MUST use issuer-qualified subject and runtime mappings wherever
accepted IdP namespaces could collide. It MUST retain the original
IdP issuer, agent and runtime identifiers with token state. It
MUST NOT label the registered principal `client_instance` merely
because CIA authenticated one of its runtimes, or introduce `act`
for that runtime. Provenance disclosure follows {{AGENT}}.

This profile does not require a `client_id` at the RAS or in its
access tokens. An implementation MUST NOT manufacture one by
copying the grant issuer or subject. A token format that requires
a client identifier needs a separate client identity arrangement.

The RAS MUST support authenticated {{RFC7662}} introspection for
opaque tokens issued under this profile. JWT access tokens MAY
also be supported under an agreed token format. The RS MUST
validate token authenticity, audience, expiry, and DPoP binding
before authorizing access. It applies its own permissions to the
validated subject and scope; neither registry ownership nor a
platform property is a portable permission assignment.

# Lifecycle and Errors {#lifecycle}

Disabling an agent, removing an assignment, or revoking platform
issuer trust MUST prevent new WAG issuance once that change is
applied at the IdP. Registry connectors MUST have an agreed
maximum synchronization delay; exceeding it MUST prevent issuance
that depends on the stale data. Local RAS disabling MUST prevent
new access-token issuance for that principal.

These changes do not automatically invalidate an already issued
WAG or access token. With the lifetime limits above, an
outstanding grant can produce at most another 300 seconds of
access after its last valid redemption; deployments MUST account
for clock skew and synchronization delay as well. Earlier
termination requires deployment-supported revocation or status
propagation. A runtime restart receives a new instance identifier;
key rotation within the same instance retains its identifier and
requires fresh attested key binding. Retired agent identifiers
MUST NOT be reassigned.

Errors use {{RFC6749}}, {{RFC8693}}, {{CIA}}, and {{RFC9449}}:

| Condition | Error |
| --- | --- |
| Malformed request or forbidden actor/instance parameter | `invalid_request` |
| CIA validation fails when CIA is the registered client credential | `invalid_client`, per CIA |
| Invalid subject evidence with independent client authentication; unknown, disabled, or ambiguously bound agent | `invalid_request` |
| Unapproved target RAS, resource, or tenancy at the IdP | `invalid_target` |
| Invalid or wholly unauthorized requested scope | `invalid_scope` |
| Invalid, expired, replayed, mistargeted, or incorrectly bound WAG at the RAS | `invalid_grant` |
| Malformed DPoP proof or nonce challenge | DPoP error/challenge per RFC 9449, subject to CIA authentication error handling |

The IdP and RAS MUST NOT fall back to a different grant profile
or bearer processing after a profile validation failure. Error
responses SHOULD avoid exposing whether unrelated agents exist.

# Security and Privacy Considerations {#security}

The security considerations of {{CIA}}, {{AGENT}}, {{WAG}},
{{RFC8693}}, {{RFC8725}}, and {{RFC9449}} apply. Registry writers
and federation-binding administrators control who can obtain
authority as an agent. The IdP MUST authenticate these operations,
limit each source to its approved namespace and attributes, and
audit changes. Syncing an agent from another platform MUST NOT
merge identities based on names or overwrite enterprise policy.

Keys MUST be instance-specific. Sharing a platform credential
cannot substitute for runtime proof. Replay caches must cover all
accepting nodes for each issuer and endpoint service. DPoP proofs
are fresh for each endpoint; proof for the IdP cannot be reused at
the RAS or RS. Logs MUST NOT record raw grants, credentials, or
private keys. Audits should retain issuer-qualified identities and
policy decisions while minimizing model and runtime disclosure.

The IdP MUST evaluate current registry state at each issuance.
Valid signatures alone do not establish current model state,
platform membership, or application assignment. Registry polling,
evidence lifetime, WAG lifetime, and access-token lifetime each
contribute separately to the stale-authorization window.

# Conformance {#conformance}

An IdP conforms by implementing the CIA subject-token input and
DPoP baseline, registry checks, discovery, WAG issuance, errors,
and lifecycle rules above. A RAS conforms by implementing the
advertised WAG validation, DPoP token issuance, subject resolution,
and resource-token rules. An instance conforms by implementing
the baseline exchange and redemption, verifying the output type
and key binding, and supporting DPoP nonce challenges.

Implementations MUST pass at least these interoperability cases:

| Case | Required result |
| --- | --- |
| Trusted CIA, active bound agent, approved target, matching key | WAG, then DPoP-bound resource token |
| Two runtimes for one registered agent | Same grant subject, distinct runtime identifiers and keys |
| Key rotation with fresh evidence | Same agent/runtime identifiers, new key binding |
| Same platform agent ID from a different unapproved issuer | Reject registry resolution |
| Disabled agent or removed application assignment | Reject new WAG issuance |
| Requester tries to substitute another agent or binding key | Reject |
| CIA or WAG replay | Reject second accepted use |
| Wrong RAS, resource, local tenancy, or broadened scope | Reject |
| User/delegated evidence or actor-token request | Reject |
| Missing profile capability or grant confirmation | No bearer or generic-JWT fallback |

# IANA Considerations {#iana}

## Authorization Server Metadata

IANA is requested to register `workload_agent_federation` in the
"OAuth Authorization Server Metadata" registry:

Metadata Name:
: `workload_agent_federation`

Metadata Description:
: Workload Agent Federation roles, input token types, and WAG
  signing algorithms supported by an authorization server

Change Controller:
: IETF

Specification Document(s):
: {{metadata}} of this document

## Coordination with WAG {#wag-coordination}

**Editor's note:** `urn:ietf:params:oauth:token-type:wag` and
`oauth-wag+jwt` are proposed, unassigned identifiers used here to
make the draft exchange precise. Their generic definitions and
OAuth URI and media-type registrations belong in {{WAG}} and
must be coordinated there before publication. This document does
not claim that those registrations already exist. The required
`resource` and `scope` processing is a constraint of this
federation profile. The agent claims are registered by {{AGENT}},
and the CIA token type by {{CIA}}.

--- back

# Example {#example}
{:numbered="false"}

The IdP `https://idp.example/tenants/acme` has approved client
`https://platform.example/client`, whose instance issuer is
`https://runtime.platform.example`. An active registry entry
maps that issuer, client, and platform agent ID
`urn:platform:agent:support` to `urn:acme:agent:42`. The entry
permits `issues.read` at resource `https://support.example/api`
through RAS `https://as.support.example`.

The platform authenticates runtime `run-7`, verifies its agent
membership, and issues this CIA. Signature and key values are
abbreviated throughout; line breaks in forms are for display.

~~~ json
{
  "iss": "https://runtime.platform.example",
  "sub": "https://runtime.platform.example/instances/run-7",
  "aud": "https://idp.example/tenants/acme",
  "client_id": "https://platform.example/client",
  "agent_id": "urn:platform:agent:support",
  "agent_instance_id":
    "https://runtime.platform.example/instances/run-7",
  "agent_platform": "urn:example:orchestrator:v5",
  "agent_model": { "id": "urn:example:model:atlas", "version": "7.3" },
  "cnf": { "jkt": "0ZcOCORZNYy...iguA4I" },
  "iat": 1789135200,
  "exp": 1789135500,
  "jti": "cia-run-7-1"
}
~~~

The client is registered for instance-assertion authentication,
so the CIA and DPoP proof also authenticate the client at the IdP:

~~~ http-message
POST /tenants/acme/token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
DPoP: <proof for the IdP endpoint signed by the instance key>

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&requested_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Awag
&subject_token=eyJ...agent-profiled-cia...
&subject_token_type=
  urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aclient-instance-jwt
&client_id=https%3A%2F%2Fplatform.example%2Fclient
&audience=https%3A%2F%2Fas.support.example
&resource=https%3A%2F%2Fsupport.example%2Fapi
&scope=issues.read
~~~

After registry and authorization checks, the IdP returns:

~~~ json
{
  "access_token": "eyJ...workload-authorization-grant...",
  "issued_token_type": "urn:ietf:params:oauth:token-type:wag",
  "token_type": "N_A",
  "expires_in": 290,
  "scope": "issues.read"
}
~~~

The decoded WAG uses the IdP's canonical identities and a protected
header with `typ: oauth-wag+jwt` and `alg: ES256`:

~~~ json
{
  "iss": "https://idp.example/tenants/acme",
  "sub": "urn:acme:agent:42",
  "agent_id": "urn:acme:agent:42",
  "agent_instance_id": "urn:acme:instance:run-7",
  "aud": "https://as.support.example",
  "resource": "https://support.example/api",
  "scope": "issues.read",
  "agent_platform": "urn:example:orchestrator:v5",
  "agent_model": { "id": "urn:example:model:atlas", "version": "7.3" },
  "cnf": { "jkt": "0ZcOCORZNYy...iguA4I" },
  "iat": 1789135210,
  "exp": 1789135500,
  "jti": "wag-agent-42-1"
}
~~~

The instance redeems it at the RAS without a downstream client
registration or another CIA:

~~~ http-message
POST /token HTTP/1.1
Host: as.support.example
Content-Type: application/x-www-form-urlencoded
DPoP: <fresh proof for the RAS signed by the same instance key>

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer
&assertion=eyJ...workload-authorization-grant...
&resource=https%3A%2F%2Fsupport.example%2Fapi
&scope=issues.read
~~~

The RAS returns a DPoP access token. An illustrative active
introspection response is below; the RAS's mapping gives the
registered agent and runtime unambiguous local identifiers:

~~~ json
{
  "active": true,
  "sub": "acme-agent-42",
  "sub_profile": "ai_agent",
  "agent_instance_id": "acme-instance-run-7",
  "aud": "https://support.example/api",
  "scope": "issues.read",
  "token_type": "DPoP",
  "cnf": { "jkt": "0ZcOCORZNYy...iguA4I" },
  "iat": 1789135220,
  "exp": 1789135520
}
~~~

There is no `act`: the registered agent is acting as itself through
one authenticated runtime. A second runtime maps to the same
registered subject with a different instance identifier and key.

# Document History
{:numbered="false"}

*RFC EDITOR: please remove this section before publication.*

## -00
{:numbered="false"}

* Initial version.

# Acknowledgments
{:numbered="false"}

The author thanks participants in the OAuth, WIMSE, and SCIM
communities for work on agent identity and workload federation.
