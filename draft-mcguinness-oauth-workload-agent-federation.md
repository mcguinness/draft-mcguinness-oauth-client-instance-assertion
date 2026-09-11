---
title: "OAuth 2.0 Profile for Agent Federation"
abbrev: "Agent Federation"
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
  INSTANCE:
    title: "Client Instance Identification for Attestation-Based Client Authentication"
    target: https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-identification.html
    author:
      - fullname: Karl McGuinness
    date: 2026-09-11
    seriesinfo:
      Internet-Draft: draft-mcguinness-oauth-client-instance-identification-latest
  ATTEST: I-D.ietf-oauth-attestation-based-client-auth
  ACTOR-PROFILE: I-D.mcguinness-oauth-actor-profile
  ENTITY-PROFILES: I-D.mora-oauth-entity-profiles
  ID-JAG: I-D.ietf-oauth-identity-assertion-authz-grant
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  WAG: I-D.carleton-workload-authz-grant
  RFC6749:
  RFC7515:
  RFC7518:
  RFC7519:
  RFC7523:
  RFC7638:
  RFC7662:
  RFC8414:
  RFC8693:
  RFC8707:
  RFC8725:
  RFC9068:
  RFC9449:
informative:
  EMA:
    title: "MCP Enterprise-Managed Authorization"
    target: https://github.com/modelcontextprotocol/ext-auth/blob/main/specification/stable/enterprise-managed-authorization.mdx
    author:
      - org: Model Context Protocol
    date: 2026
  RFC6755:
  SCIM-AGENT: I-D.wzdk-scim-agent-resource
  RFC7643:
  RFC7644:
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  JWT-DPOP: I-D.parecki-oauth-jwt-dpop-grant
--- abstract

This specification profiles OAuth 2.0 for agent access through
an identity provider. It preserves client-based user delegation
using Identity Assertion JWT Authorization Grants, specifies
explicit actor delegation using the OAuth Actor Profile, and
profiles Workload Authorization Grants for agents acting for
themselves. Separate agent credentials and instance evidence are
required only for deployments that identify agents independently
of their OAuth clients.

--- middle

# Introduction

An identity provider (IdP) can authorize an agent application
to access resources for a user, or govern agent principals
independently of the platforms hosting them. A Resource
Authorization Server (RAS) trusts the IdP's authorization grant;
the Resource Server (RS) accepts the RAS's access token.

This document supports three cases:

| Case | Grant | Subject | Actor representation |
|---|---|---|---|
| Client-based delegation | ID-JAG | User | Client identity; no `act` required |
| Explicit actor delegation | ID-JAG | User | Client or Registered Agent in `act` |
| Self-acting agent | WAG | Registered Agent | No `act` |

Client-based delegation reuses {{ID-JAG}}, including deployments
such as MCP Enterprise-Managed Authorization {{EMA}}. Here,
"implicit delegation" describes actor representation: access
is still authorized by user or administrator policy. Absence
of `act` does not imply self-acting access or a human presenter.

Implementations MUST support at least one case and its applicable
requirements. {{client-delegation}} defines the existing ID-JAG
path. The protocol requirements in {{bootstrap}}, {{exchange}},
{{grant}}, {{redemption}}, and {{access-tokens}} apply to the
self-acting and explicit actor cases; they do not add bootstrap,
actor, or sender-constraint requirements to client-based delegation.
Task-specific authority and multi-agent chains are outside this
profile. These cases are alternatives, not migration stages.

## Relationship to the OAuth Actor Profile {#actor-relationship}

Explicit actor delegation MUST implement {{ACTOR-PROFILE}} for
actor construction, authorization, preservation, and resource
processing. The actor is established from a JWT client assertion
when the client itself acts, or from an Agent Token when a
Registered Agent acts. An instance identifier never supplies
the actor identity. RAS redemption preserves the actor without
adding another hop. Opaque-token introspection uses Actor
Profile's compatibility path as specified in {{access-tokens}}.

ID-JAG's RAS issuer audience applies; see {{coordination}}.
Client-based delegation, self-acting access, and instance
identification alone do not require Actor Profile. Client
Instance Identification {{INSTANCE}} can provide audit or risk
context in any case without requiring explicit actor representation.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

OAuth terms are used as defined in {{RFC6749}} and {{RFC8693}}.
Client Attester and Client Instance are defined by {{ATTEST}};
Instance Identifier and Instance Context are defined by {{INSTANCE}}.

Agent Principal:
: A non-human principal whose identity can persist across
  runtime restarts, key changes, and platform migration.

Registered Agent:
: An Agent Principal represented in the IdP registry, with
  current status and authorized external identity bindings.

Agent Platform:
: A system that creates or operates agent instances. It can
  serve as, or authorize, a Client Attester. The platform can
  act as an OAuth client itself or host separately identified agents.

Agent Token:
: A short-lived, sender-constrained JWT access token issued by
  the IdP for this profile's exchange service. It identifies
  a Registered Agent and its authenticated instance.

Federation Binding:
: An administratively authorized mapping from a trusted
  attester, logical client, and platform agent identifier to
  a Registered Agent.

# Identity and Deployment {#identity}

The IdP and RAS MUST establish trust binding issuer, target tenant,
resources, permitted cases, subject mappings, signing keys, and
policy. An issuer MAY serve several tenants, but source and target
tenants MUST be unambiguous. Discovery and client metadata do not
establish authorization. User SSO trust does not by itself permit
self-acting access.

The trust configuration MUST identify contexts requiring explicit
actors, separate agent identity, instance evidence, or sender
constraints. Missing required evidence MUST cause rejection.
Absence of `act` or `actor_token` MUST NOT select client-based
processing when the configured resource or client requires an
explicit actor. Invalid or unsupported actor input MUST NOT be
ignored or retried as client-based delegation. No new case-selection
parameter is defined.

Clients MAY use {{CIMD}} with the authentication method established
by its validated metadata and server policy. A common CIMD
identifier accepted by both servers removes the need to translate
client IDs. Otherwise, the IdP MUST resolve an approved downstream
client mapping under {{ID-JAG}}. Metadata retrieval alone does not
approve client access or authorize delegation.

When a client is itself the authorized actor, its identity can
also identify that actor under {{client-actor}}. No separate agent
record is required. When several independently governed agents
share a client, client authentication alone cannot distinguish
them; {{bootstrap}} establishes the Registered Agent instead.
That path uses {{INSTANCE}} with `attest_jwt_client_auth_dpop`.
Individual agents and instances need no separate client registration.

For Registered Agents, the IdP MUST maintain stable,
non-reassignable, issuer-qualified identifiers and approved
Federation Bindings. Display names or unqualified subjects MUST
NOT merge agents. Several approved bindings MAY identify one
agent. A runtime restart or key rotation does not change its
principal or create an actor.

Self-acting access does not require a client registration at the
RAS. A deployment MAY require client authentication by agreement;
it MUST NOT manufacture a client identifier from the agent subject
to satisfy a token-format requirement. Both delegation cases use
client identification and authentication under {{ID-JAG}}.

# Client-Based Delegation {#client-delegation}

This case uses {{ID-JAG}} without requiring separate actor identity.
The client presents a user credential accepted by ID-JAG, requests
an ID-JAG for the target RAS, and redeems it under {{RFC7523}}.
Subject validation, client authentication and binding, resource
and scope processing, authorization details, response parameters,
errors, lifetimes, and replay handling follow ID-JAG. MCP clients
using {{EMA}} additionally follow that extension.

The IdP evaluates authorization for the user, client, target, and
requested access. Administrator policy can establish this authority
without a per-resource user consent prompt. This case requires no
Agent Token, `actor_token`, `act`, `agent_id`, or agent directory
record. The ID-JAG identifies the user in `sub` and the downstream
client in `client_id`.

Example request using an existing confidential client:

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=mcp-client-at-idp
&client_secret=EXAMPLE-CLIENT-SECRET
&requested_token_type=urn:ietf:params:oauth:token-type:id-jag
&subject_token=eyJ...user-id-token...
&subject_token_type=urn:ietf:params:oauth:token-type:id_token
&audience=https%3A%2F%2Fas.app.example
&resource=https%3A%2F%2Fapi.app.example
&scope=tickets.read
~~~

A CIMD client uses its established authentication method instead;
CIMD does not establish shared client secrets. Neither ATTEST nor
`private_key_jwt` is a universal requirement for existing clients.

Sender constraints follow {{ID-JAG}} and deployment policy.
Bearer access tokens remain supported where permitted. A grant
containing `cnf` MUST receive the binding checks required by ID-JAG;
missing or invalid proof MUST NOT result in bearer issuance.

The RAS and RS can authorize using user permissions, groups,
client context, and enterprise assignments. They MUST NOT infer
a distinct agent or runtime identity from a shared `client_id`.
A resource requiring a separately governed agent identity uses
explicit actor delegation.
Tokens carrying `act` MUST receive the applicable actor processing
or be rejected; this case MUST NOT erase or ignore supplied actors.

A deployment MAY add {{INSTANCE}} through configured ATTEST
client authentication. Validated `client_instance` context then
identifies the presenting client instance for audit or risk;
it does not change the user subject or require an `act` claim.
Resources relying on that context MUST reject its absence.

# Establishing an Agent Token {#bootstrap}

This section applies to self-acting agents and explicit delegation
using a Registered Agent. Client-based delegation and explicit
client actors do not require this bootstrap.

## Agent Evidence {#agent-evidence}

The Client Attestation MUST conform to {{INSTANCE}} and contain
`agent_id`, a nonempty StringOrURI identifying the agent in
the attester's namespace. Before issuance, the attester MUST
verify that the instance is an authorized execution of that
agent and possesses the key in `cnf.jwk`. A caller-supplied
identifier alone does not establish that relationship.

The attestation's `sub` remains the logical `client_id`;
`client_instance_id` identifies the runtime. The IdP MUST map
the exact tuple `(iss, sub, agent_id)` through an approved
Federation Binding. An unsigned request field MUST NOT
replace that mapping.

The IdP MUST determine the enterprise tenancy from the effective
client configuration and authenticated Federation Binding.
Ambiguous tenancy resolution MUST cause rejection; an unsigned
tenant hint MUST NOT override that resolution.

This profile defines no model or runtime provenance vocabulary.
An absent, empty, or incorrectly typed `agent_id` MUST cause
rejection. Platform-supplied groups, owners, and assignments
MUST NOT become enterprise authority unless a separate source
policy explicitly authorizes them.

## Request

The client uses the client credentials grant, with `resource`
equal to the IdP issuer identifier and `scope`
equal to `agent-federation`. The request MUST carry the
attestation in `OAuth-Client-Attestation` and a DPoP combined-mode
proof using the instance key. The attestation MUST NOT be
placed in `subject_token`, `actor_token`, or `client_assertion`.

Examples abbreviate cryptographic values and omit HTTP framing
headers. Line breaks in form bodies are for display only.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...attestation...
DPoP: eyJ...instance-proof...

grant_type=client_credentials
&client_id=https%3A%2F%2Fplatform.example%2Foauth-client
&resource=https%3A%2F%2Fidp.example%2Ftenant%2Facme
&scope=agent-federation
~~~

## Processing and Response {#agent-token}

The IdP MUST validate {{INSTANCE}} and {{agent-evidence}},
resolve an active Registered Agent, and check current
client-to-agent permission. The attestation lifetime MUST NOT
exceed 300 seconds. Client authentication alone MUST NOT
authorize an arbitrary agent identity.

The Agent Token MUST conform to {{RFC9068}} and use `typ=at+jwt`.
Its `iss` is the approved IdP issuer, `sub` is the Registered
Agent identifier, and `client_id` is the actual IdP client.
Its `aud` MUST equal the IdP issuer identifier and `scope`
MUST be `agent-federation`. This audience and scope identify
the IdP's exchange service; no separate resource identifier
or endpoint is defined. The token MUST contain
`sub_profile=ai_agent` as defined by {{ENTITY-PROFILES}},
`client_instance` identifying the authenticated upstream
instance, and `cnf.jkt` derived from the proven key under
{{RFC7638}}. It MUST NOT contain `act`.

The IdP MUST associate the token with its approved Federation
Binding and source tenant. The token MUST expire within
300 seconds and no later than the attestation. The response
MUST have `token_type=DPoP`, `expires_in`, and `scope`;
it MUST NOT include a refresh token.
Clients need not parse the token to use it.

~~~ json
{
  "access_token": "eyJ...agent-access-token...",
  "token_type": "DPoP",
  "expires_in": 300,
  "scope": "agent-federation"
}
~~~

This subject selection profiles a prearranged authorization
relationship in the client credentials grant. The token
permits exchange requests under current IdP policy, not API
access at a RAS or authority to act for any user. It MAY be
reused before expiry with fresh proofs. Renewal requires a
new bootstrap; key rotation requires a new token. Presenting
the same instance ID MUST NOT rebind an existing token.

## Workload Federation Inputs

An IdP MAY support native workload authentication, including
{{SPIFFE-OAUTH}}, through another input profile. That profile
MUST specify issuer trust, credential validation, logical-client
mapping, agent and instance resolution, and proof binding.
It MUST produce the Agent Token defined above and advertise
its authentication capabilities separately.

This document defines no direct token-exchange binding for
arbitrary workload JWTs, SVIDs, or Client Attestations. Such
extensions MUST NOT weaken the required ATTEST bootstrap for
implementations supporting the Registered Agent input path.
A workload identity shared by replicas MUST NOT identify one
replica without additional authenticated evidence.

# Requesting an Authorization Grant {#exchange}

This section applies to self-acting and explicit actor cases.
The client uses {{RFC8693}} at the IdP token endpoint. A request
using an Agent Token MUST use the same client and {{ATTEST}}
DPoP combined-mode authentication as its bootstrap, with a fresh
proof whose key matches the Agent Token. An explicit client actor
uses {{client-actor}} instead.

In both cases, `grant_type` MUST be
`urn:ietf:params:oauth:grant-type:token-exchange`, `audience`
MUST contain exactly one target RAS issuer identifier,
`resource` MUST contain exactly one resource {{RFC8707}}
governed by that RAS, and `scope` MUST contain a nonempty set
of requested resource scopes. The IdP MUST NOT infer resource
authority from the Agent Token's exchange-service scope.
`authorization_details` is not supported by this profile and
MUST cause `invalid_request` rather than silent omission.

## Self-Acting Mode {#self-exchange}

`requested_token_type` MUST be
`urn:ietf:params:oauth:token-type:wag`. `subject_token` MUST be
the Agent Token, with `subject_token_type` equal to
`urn:ietf:params:oauth:token-type:access_token`. Neither actor
parameter is permitted.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...attestation...
DPoP: eyJ...instance-proof...

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=https%3A%2F%2Fplatform.example%2Foauth-client
&requested_token_type=urn:ietf:params:oauth:token-type:wag
&subject_token=eyJ...agent-access-token...
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&audience=https%3A%2F%2Fas.app.example
&resource=https%3A%2F%2Fapi.app.example
&scope=tickets.read
~~~

## Explicit Actor Delegation {#delegated-exchange}

`requested_token_type` MUST be
`urn:ietf:params:oauth:token-type:id-jag`. `subject_token` MUST
be a user credential accepted under {{ID-JAG}}. Implementations
MUST support an OpenID Connect ID Token with
`subject_token_type=urn:ietf:params:oauth:token-type:id_token`.
Other subject inputs permitted by {{ID-JAG}} MAY be supported
with its validation rules and applicable {{ACTOR-PROFILE}}
subject processing.

Implementations MUST support at least one of the two actor inputs
below and MUST advertise the input types they accept. Requests
MUST contain one `actor_token` and its matching `actor_token_type`.
A configured requirement for a Registered Agent MUST NOT be
satisfied by a client assertion naming only the shared client.

### Registered Agent Input

`actor_token` is the Agent Token and `actor_token_type` is
`urn:ietf:params:oauth:token-type:access_token`. The IdP MUST
apply Actor Profile's JWT access token input processing. Its
`(iss, sub)` identifies the agent; its runtime claim does not
supply `act.sub`.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...attestation...
DPoP: eyJ...instance-proof...

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=https%3A%2F%2Fplatform.example%2Foauth-client
&requested_token_type=urn:ietf:params:oauth:token-type:id-jag
&subject_token=eyJ...user-id-token...
&subject_token_type=urn:ietf:params:oauth:token-type:id_token
&actor_token=eyJ...agent-access-token...
&actor_token_type=urn:ietf:params:oauth:token-type:access_token
&audience=https%3A%2F%2Fas.app.example
&resource=https%3A%2F%2Fapi.app.example
&scope=tickets.read
~~~

### Client Actor Input {#client-actor}

This input identifies the OAuth client itself as the actor.
The client MUST authenticate using `private_key_jwt` and present
the same signed JWT as both `client_assertion` and `actor_token`,
with `actor_token_type=urn:ietf:params:oauth:token-type:jwt`.
The JWT MUST satisfy {{RFC7523}} and Actor Profile's JWT client
assertion input rules, including `iss = sub = client_id`.
It MUST NOT name an agent subordinate to that client.

The IdP MUST validate the established client keys, audience,
lifetime, and replay controls. Shared validation is performed
once for this request's two uses of the JWT. The IdP MUST also
verify policy permitting that client to act for the user and
requested target. CIMD discovery establishes client metadata,
not delegation approval. No Agent Token or ATTEST is required.

A fresh DPoP proof MUST accompany the request. The IdP MUST
bind the resulting grant to that proven key. The DPoP key MAY
differ from the client assertion signing key; it is bound by
the authenticated, authorized exchange and need not identify
an attested runtime.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
DPoP: eyJ...client-proof...

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=https%3A%2F%2Fclient.example%2Fclient.json
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJ...client-assertion...
&requested_token_type=urn:ietf:params:oauth:token-type:id-jag
&subject_token=eyJ...user-id-token...
&subject_token_type=urn:ietf:params:oauth:token-type:id_token
&actor_token=eyJ...client-assertion...
&actor_token_type=urn:ietf:params:oauth:token-type:jwt
&audience=https%3A%2F%2Fas.app.example
&resource=https%3A%2F%2Fapi.app.example
&scope=tickets.read
~~~

## IdP Processing {#idp-processing}

Before issuing a self-acting or explicit actor grant, the IdP MUST:

1. Validate the selected credential path. For an Agent Token,
   match the client, agent, instance, tenant, and key to current
   authenticated evidence and verify the token's issuer, audience,
   purpose, and expiration. For a client actor, apply
   {{client-actor}}. Another IdP access token MUST NOT substitute
   for an Agent Token.
2. Check current client or agent status, applicable trust and
   bindings, application assignment, and permitted case under
   {{lifecycle}}. Resolve tenant context through validated evidence
   and trusted configuration, never an unsigned override.
3. Validate the RAS/resource association and requested scopes.
   Determine a permitted, nonempty subset without broadening access.
4. For explicit delegation, validate the user credential under
   {{ID-JAG}}, including audience/client checks and scope ceilings.
   Resolve the user and downstream client. Verify user-approved
   or administrator-authorized delegation for the established
   actor, user, client context, resource, and scope. Valid
   credentials alone MUST NOT establish that authorization.
5. Construct the grant under {{grant}}. Explicit delegation uses
   Actor Profile to introduce the validated actor and binds the
   output to the proven key. Redemption preserves that actor.

Approval can be established by policy or a consent record; its
acquisition is outside this profile. Its scope MUST unambiguously
identify the acting principal and authorized access. A shared
client MUST NOT let one Registered Agent use another's approval.

Only one current actor is supported. Inputs with an existing
`act` chain MUST be rejected, not erased or extended. This
includes both actor credential types and user subject inputs.
The grant lifetime MUST NOT exceed 300 seconds or the remaining
validity of its actor or agent credential, accepted user
credential, or applicable delegation. An Agent Token's bootstrap
scope is not a downstream scope ceiling. User authorization-state
inputs retain the scope ceiling required by their input profile.

## Response and Errors {#exchange-response}

The response follows {{RFC8693}}. `issued_token_type` MUST
equal the requested WAG or ID-JAG token type; `token_type` MUST
be `N_A`. `access_token` contains the grant, `expires_in` gives
its remaining lifetime, and `scope` lists the issued scopes.
No refresh token is issued.

The client MUST check that the response's issued type matches
the requested type and that the grant has the expected protected
type, audience, resource, scope subset, and `cnf.jkt` for its
proven key. Missing or inconsistent binding MUST cause failure.
These checks do not replace the RAS's
cryptographic grant validation.

~~~ json
{
  "access_token": "eyJ...workload-authorization-grant...",
  "issued_token_type": "urn:ietf:params:oauth:token-type:wag",
  "token_type": "N_A",
  "expires_in": 240,
  "scope": "tickets.read"
}
~~~

Malformed requests, unsupported combinations, and actor depth
violations use `invalid_request`. Failed shared client-assertion
validation uses `invalid_client` under {{ACTOR-PROFILE}}; later
actor-input policy failures use `invalid_grant`. Other invalid
credentials or inconsistent identity/key bindings use `invalid_grant`.
Unacceptable targets use `invalid_target`; impermissible scopes
use `invalid_scope`. For a validated actor whose required
delegation cannot be established or is prohibited, the IdP
MUST use `actor_unauthorized` from {{ACTOR-PROFILE}}. It MUST
NOT issue a self-acting grant in response to that failure.
Clients not allowed to use this profile receive
`unauthorized_client`. Authentication and freshness challenges
retain the selected authentication method and {{RFC9449}} errors.

# Authorization Grants {#grant}

This section defines self-acting and explicit actor grants.
Client-based grants follow {{client-delegation}}.

Grants MUST be signed JWTs in JWS Compact Serialization
{{RFC7515}} under the approved IdP issuer. The protected
header MUST contain an approved asymmetric `alg` and a `kid`
resolvable through trusted issuer key configuration.
Implementations MUST support `ES256` {{RFC7518}} and reject
`none` and symmetric MAC algorithms.

Self-acting grants follow {{WAG}} with
`typ=oauth-wag+jwt`; explicit actor grants follow {{ID-JAG}} with
`typ=oauth-id-jag+jwt`. See {{coordination}} for the proposed
WAG identifiers and IdP deployment.

The following claims are REQUIRED in both cases:

`iss`:
: The approved IdP issuer.

`aud`:
: A string containing the exact RAS issuer identifier.

`sub`:
: The Registered Agent identifier from the Agent Token in
  self-acting mode; the downstream-mapped user identifier in
  explicit delegation. It MUST be nonempty and non-reassignable
  within the grant issuer's namespace.

`iat`, `exp`, `jti`:
: Issue time, expiration time, and unique grant identifier.
  `exp` MUST exceed `iat` by at most 300 seconds, subject to
  {{idp-processing}}. The IdP MUST NOT reuse `(iss, jti)`.

`resource`, `scope`:
: The single approved resource and nonempty, space-delimited
  approved scopes.

`cnf`:
: An object containing `jkt`, the JWK SHA-256 thumbprint of the
  proven presenter public key. The IdP MUST derive it from the
  validated key, not an unsigned request value.

Self-acting grants MUST have `sub_profile=ai_agent` and MUST
NOT contain `act`. Explicit delegation MUST contain an Actor
Profile `act` constructed from the validated actor input:

* Agent Token: copy its `iss` and `sub`; set `sub_profile=ai_agent`.
* Client assertion: set `act.sub` to its `sub` (the IdP-side
  `client_id`) and `act.iss` to the IdP issuer as the configured
  actor namespace. Classification follows {{ACTOR-PROFILE}} and
  {{ENTITY-PROFILES}}; CIMD alone does not establish `ai_agent`.

The client actor's `act.sub` can equal the ID-JAG's `client_id`
when both servers use the same CIMD identifier. When downstream
client IDs differ, translate only `client_id`; preserve the
actor's namespace and subject. Client assertion evidence MUST
NOT be mapped into a subordinate Registered Agent identity.

Explicit ID-JAGs MUST include the downstream `client_id` and
other claims required by {{ID-JAG}}, including applicable tenant
context. User classification is supplied only when authoritative.
User and actor identities MUST resolve to distinct principals.

The IdP MAY include `client_instance` as defined by {{INSTANCE}}
for downstream audit or risk evaluation only when instance
evidence has been validated under {{INSTANCE}} or an approved
workload input profile. If included, its `iss`
MUST equal the grant issuer and its `id` MUST be an IdP-assigned
reference to the authenticated upstream instance. The IdP MUST
retain that mapping and SHOULD scope it to the downstream trust
relationship. It describes execution of the subject in
self-acting mode and of the current actor in explicit delegation;
it MUST NOT add an actor or change the subject. Omitting this
context does not relax agent authentication or key binding.

`agent_id` is not required in a grant: `sub` or `act` already
identifies the agent. Optional `groups` describe only the
subject and follow {{attributes}}.

Example self-acting grant payload:

~~~ json
{
  "iss": "https://idp.example/tenant/acme",
  "sub": "agent-42",
  "sub_profile": "ai_agent",
  "aud": "https://as.app.example",
  "resource": "https://api.app.example",
  "scope": "tickets.read",
  "cnf": { "jkt": "Ak20Cf62SpTybasujYXbaI-Ms655MyvOZCtnnf8y1QU" },
  "iat": 1789128000,
  "exp": 1789128240,
  "jti": "grant-f194"
}
~~~

Example explicit grant using a Registered Agent:

~~~ json
{
  "iss": "https://idp.example/tenant/acme",
  "sub": "user-17",
  "act": {
    "iss": "https://idp.example/tenant/acme",
    "sub": "agent-42",
    "sub_profile": "ai_agent"
  },
  "client_id": "platform-at-app",
  "aud": "https://as.app.example",
  "resource": "https://api.app.example",
  "scope": "tickets.read",
  "cnf": { "jkt": "Ak20Cf62SpTybasujYXbaI-Ms655MyvOZCtnnf8y1QU" },
  "iat": 1789128000,
  "exp": 1789128240,
  "jti": "grant-f195"
}
~~~

# Redeeming a Grant {#redemption}

This section applies to self-acting and explicit actor grants.
Client-based redemption follows {{client-delegation}}.

The client sends the grant in `assertion` with
`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`
to the RAS token endpoint, accompanied by a fresh DPoP proof
using the bound key. An optional `resource` MUST equal the
grant's resource; optional `scope` MUST be a nonempty subset
of its scopes. If omitted, the grant's values apply.
`audience`, actor inputs, and `authorization_details` are
not permitted. Explicit actor requests MUST authenticate as the
grant's downstream client using its registered method.

~~~ http
POST /token HTTP/1.1
Host: as.app.example
Content-Type: application/x-www-form-urlencoded
DPoP: eyJ...instance-proof-for-ras...

grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
&assertion=eyJ...workload-authorization-grant...
~~~

The RAS MUST:

1. Select this profile through the approved trust configuration
   in {{identity}} and validate signature, protected type,
   required claims, audience, and lifetime. Reject mode/type
   mismatches.
2. Validate the DPoP proof for its token endpoint under
   {{RFC9449}}. Compute its public-key thumbprint and compare
   it to `cnf.jkt`. Missing or mismatched proof MUST fail.
3. Enforce delegated client authentication and exact downstream
   `client_id` matching under {{ID-JAG}}. Apply Actor Profile
   grant validation and presenter-continuation processing.
4. Resolve the subject and, for explicit delegation, the actor
   under {{provisioning}}. Check current local status and policy.
   A suspended client actor or Registered Agent MUST be rejected.
5. Apply the requested scope subset and local policy without
   exceeding the grant. For delegated access, evaluate user
   permissions, permitted actor behavior, and delegation bounds
   together. Their permissions MUST NOT be unioned.
6. Atomically consume `(iss, jti)` upon successful issuance.
   A grant MUST produce at most one successful issuance across
   all RAS nodes. Replay state MUST be retained through grant
   expiration plus accepted clock skew.

A lost successful response requires a new grant. Consumed grants
fail with `invalid_grant`. Malformed requests and invalid scope
use `invalid_request` and `invalid_scope`. Explicit actor
structure, identity, depth, and policy errors follow
{{ACTOR-PROFILE}}, including `actor_unauthorized` for a prohibited
or unconfirmed relationship. Other grant validation failures
use `invalid_grant`; authentication and nonce challenges retain
their base errors. No failure permits bearer issuance or retry
under a less restrictive grant profile.

# Access Tokens and Resource Processing {#access-tokens}

This section applies to self-acting and explicit actor grants.
Client-based access tokens follow {{client-delegation}}, including
its existing authentication and sender-constraint choices.

The RAS MUST issue an access token for the approved resource,
bound to the grant's confirmation key, with `token_type=DPoP`,
`expires_in`, and `scope`.
It MUST NOT be accompanied by a refresh token. The RAS MUST
set its lifetime according to resource authorization and
revocation policy, including any explicit delegation expiration.
Grant expiration limits redemption; it does not by itself limit
the resulting access token's lifetime. The client MUST reject
another token type or scopes broader than those in the grant.

The RAS and RS select the access-token format and validation
mechanism for their deployment. The RS MUST obtain the validated
subject, resource, expiration, scopes, and confirmation key, and
the actor in explicit delegation. Subject mapping MUST preserve
the underlying principal. In explicit delegation the RAS MUST preserve
the validated `act` unchanged under {{ACTOR-PROFILE}}; resolving
a local actor record does not permit rewriting its namespace or
adding a runtime actor. Self-acting tokens MUST NOT introduce `act`.

When {{RFC7662}} introspection is used, active results MUST
include `sub`, `aud`, `exp`, `scope`, and `cnf.jkt`. Explicit
actor results MUST also include the unchanged `act` and applicable
subject classification under Actor Profile's introspection
compatibility path. An established logical client MUST be
reported as `client_id`. Inactive results MUST NOT disclose
this context. Explicit actor JWT access tokens MUST follow Actor
Profile's access-token output rules. A token claiming {{RFC9068}}
conformance MUST include its required `client_id`; a clientless
self-acting deployment MUST use another token format.

The RAS MAY propagate a grant's validated `client_instance`
unchanged in the access token or introspection response when
needed by the RS. A resource requiring instance context MUST
have that requirement configured throughout the issuance path;
missing required context MUST cause rejection. Other deployments
need not propagate it.

The RS MUST enforce audience, expiry, scope, and local policy,
and verify DPoP against the token's validated confirmation key,
including the access-token hash required by {{RFC9449}}.
It MUST NOT accept grants or Agent Tokens as API access tokens.
Explicit actor processing MUST follow {{ACTOR-PROFILE}}, including
actor policy and errors, without reducing access to user-only
authorization.

The RS needs no upstream platform attestation support.
Instance context supports audit and risk restrictions; an
instance identifier does not itself grant permissions.

# Provisioning and Attributes {#provisioning}

For requests using an Agent Token, the IdP MUST resolve an active
Registered Agent before issuing tokens or grants. Records MAY be
synchronized from platforms or admitted just in time under explicit
policy. Each source
MUST be restricted to approved namespaces and writable
attributes. Changes to bindings and assignments, including
platform migration, MUST be authenticated and audited.

## Downstream Correlation

Client-based delegation uses ID-JAG's user and client mappings.
An explicit client actor is resolved using its qualified actor
identity and an approved client association. Neither case requires
separate agent provisioning. Different client and actor identifiers
MUST NOT be assumed equivalent without that association.

For Registered Agents, the following requirements apply.

The RAS MUST resolve the issuer-qualified agent identity to the
same local principal in self-acting and explicit actor cases, within
the authorized target tenant. Provisioning and grant processing
MUST use a consistent mapping. User mapping follows {{ID-JAG}}.
A valid grant MUST NOT implicitly reactivate a disabled agent.

Provisioning is a deployment choice. SCIM Agent resources
{{SCIM-AGENT}} with {{RFC7644}}, JIT admission, and administrative
configuration are possible mechanisms. A SCIM deployment can
use `externalId` {{RFC7643}} for the IdP's agent identifier,
with the issuer and tenant established by its authenticated
provisioning relationship. An unqualified identifier is
insufficient for correlation. Synchronization and conflict
resolution procedures are outside this profile. Per-instance
directory records are not required.

## Groups and Ownership {#attributes}

The RAS MUST correlate membership references to the appropriate
local user, client, or agent records, retaining their distinct
principal identities. Ownership
MUST NOT implicitly confer the owner's data privileges.

In grants under this profile, optional `groups` MUST be an
array of nonempty strings identifying groups in the grant
issuer's namespace. These are exact identifiers, not display
names. The RAS MUST map them through tenant trust before use
in policy. They describe the subject: the agent in WAG and
the user in ID-JAG. Actor memberships in explicit delegation
MUST come from trusted actor state at the RAS; this profile
does not define group authorization claims inside `act`.

Grant groups are audience-filtered assertions, not a complete
directory snapshot. Absence MUST NOT imply an empty membership
set, nor may a truncated array be treated as complete. Missing
required membership evidence MUST cause the affected authorization
to fail. The trust relationship MUST designate local
state or grant claims as authoritative for each membership
policy and bound its age. Conflicting sources MUST NOT be
unioned to broaden authority.

Assignments, user resource permissions, and delegation bounds
MUST be evaluated separately. Groups and ownership are policy
inputs, not self-executing permissions.

# Authorization Server Metadata {#metadata}

Use existing {{RFC8414}}, {{ID-JAG}}, and authentication-method
metadata. Client-based delegation advertises ID-JAG support using
`urn:ietf:params:oauth:grant-profile:id-jag`; it does not require
Actor Profile or this document's grant-profile identifier.

A RAS implementing the self-acting or explicit actor requirements
MUST advertise `urn:ietf:params:oauth:grant-profile:agent-federation`
in `authorization_grant_profiles_supported`. An explicit actor
RAS MUST additionally advertise ID-JAG and Actor Profile support.
This advertisement does not make every ID-JAG require an actor;
trusted configuration selects the requirements for each context.

Servers MUST advertise the grant types and authentication methods
for their implemented paths. An IdP supporting Agent Tokens MUST
advertise `client_credentials`, token exchange, and
`attest_jwt_client_auth_dpop`. An IdP supporting client actor input
MUST advertise token exchange and `private_key_jwt`. Instance
profile selection is administratively configured. Explicit actor
IdPs MUST advertise the corresponding Actor Profile input and
output types; entity-profile metadata lists supported actor types.
Self-acting and explicit actor servers MUST advertise DPoP `ES256`
support. An introspection endpoint is advertised when used.

Clients advertise applicable grant profiles and grant types under
their base specifications. CIMD processing follows {{CIMD}}.
No new capability object, case parameter, or token marker is defined.
Metadata does not establish issuer trust or delegation authority.

Example RAS metadata for existing client-based delegation:

~~~ json
{
  "issuer": "https://as.app.example",
  "token_endpoint": "https://as.app.example/token",
  "grant_types_supported": [
    "urn:ietf:params:oauth:grant-type:jwt-bearer"
  ],
  "authorization_grant_profiles_supported": [
    "urn:ietf:params:oauth:grant-profile:id-jag"
  ]
}
~~~

# Security Considerations

The requirements of each referenced specification apply to the
paths using it. Client-based delegation follows {{ID-JAG}};
explicit actor processing additionally follows {{ACTOR-PROFILE}}.
{{ATTEST}} and {{INSTANCE}} apply when instance evidence is used.

## Binding and Substitution

For the Agent Token path, the IdP MUST bind agent, instance,
client, tenant, and proof key together. Client actor input MUST
bind the authenticated client, authorized actor, and proven key
to the same request. Independently valid credentials do not
establish their delegation relationship.

Self-acting and explicit actor grants require proof at issuance
and redemption, with fresh proofs for each endpoint and DPoP
nonce and replay handling under {{RFC9449}}. Binding only the
access token does not protect a bearer grant. The separate grant
type in {{JWT-DPOP}} is not implicitly selected. Existing
client-based delegation retains ID-JAG's sender-constraint rules.

The IdP MUST issue grants only to a RAS supporting the required
processing. IdP, RAS, and RS MUST enforce configured requirements
for actors, instance context, and sender constraints. They MUST
NOT downgrade after failed checks, remove `act` to obtain
client-based access, or infer a subordinate agent from a shared
client. A correctly authorized client-based flow is not a downgrade
when the resource permits it. A gateway changing the presenter
requires separately authorized credential and identity mapping.

## Lifecycle and Freshness {#lifecycle}

IdP and RAS MUST enforce current client and, where applicable,
agent status, bindings, assignments, and delegation when issuing
authority. Disabling a principal or revoking authorization MUST
prevent subsequent issuance once applied at the relevant server.
A valid credential MUST NOT override that decision.

Deployments MUST define authorization-data freshness limits,
access-token lifetimes, and revocation behavior for issued
tokens in each supported case. Data older than the configured
limits MUST NOT authorize issuance. The policy MUST account for
synchronization delays and any resource-server validation cache.

Grant expiration prevents later redemption; it does not revoke
an access token already issued from that grant. Residual access
therefore depends on access-token lifetime and the deployment's
revocation mechanism. This profile specifies no synchronization
protocol and does not promise immediate revocation.

# Privacy Considerations

Stable agent identifiers permit correlation across applications.
The IdP SHOULD scope instance references to downstream trust
relationships and MUST retain an unambiguous internal mapping.
One key across IdP, RAS, and RS also permits correlation;
instances SHOULD use separate key/evidence contexts for
unrelated trust relationships while retaining agent identity.

Only needed identity context SHOULD be released. Raw platform
evidence and owner personal data SHOULD NOT appear in grants. Audit
records SHOULD identify qualified principals, available instance
context, authorization case, target, and decision; they MUST NOT
contain raw credentials
or private keys.

# IANA Considerations

## JWT Claims

This specification requests registration of `agent_id` in the
registry established by {{RFC7519}}, with description
"Attester-scoped agent principal identifier", reference
{{agent-evidence}}, and Change Controller IETF.

`client_instance` is defined by {{INSTANCE}}; `act` uses
{{ACTOR-PROFILE}}; `ai_agent` is defined by {{ENTITY-PROFILES}}.
No new actor format or Agent Token type is registered.

## OAuth URI

Register `urn:ietf:params:oauth:grant-profile:agent-federation`
in the registry established by {{RFC6755}}, with Common Name
"Agent Federation Grant Profile", Change Controller IETF,
and reference {{metadata}}. WAG identifiers are addressed in
{{coordination}}.

--- back

# Interoperability Cases
{:numbered="false"}

An interoperability exercise should include independent client,
IdP, RAS, and RS implementations and the applicable cases below:

| Case | Required result |
|---|---|
| Existing EMA request without actor or instance evidence | ID-JAG processing; no new bootstrap requirement |
| Client-based grant without `act` | User subject and downstream client binding; no inferred agent |
| Client-based bearer flow permitted by policy | No added ATTEST, Actor Profile, or DPoP requirement |
| CIMD client assertion used in both request parameters | One validation; explicit client actor; no Agent Token |
| Different downstream client ID | Translate `client_id`; preserve canonical `act` |
| Client assertion substituted for required Registered Agent | Reject |
| Registered Agent acting for a user | User subject and Registered Agent `act` |
| Agent acting for itself | WAG subject is the agent; no `act` |
| Missing or invalid actor evidence where required | Reject without client-based fallback |
| Optional instance evidence on client-based access | Audit context; no new actor |
| Unrelated Agent Token or proof key | Reject inconsistent bindings |
| Valid credentials without required actor authorization | `actor_unauthorized` |
| Replayed self-acting or explicit actor grant | Reject |
| Disabled principal with valid credentials | No new authority |

Implementations need only exercise cases for their supported paths.

# Coordination with Related Work {#coordination}
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

The WAG token type `urn:ietf:params:oauth:token-type:wag` and
JWT type `oauth-wag+jwt` are proposed pending coordination with
{{WAG}}; their generic definitions and registrations are
expected there. WAG's platform-issued model, advance-projection
restrictions, and issuer/audience rules need alignment with
this governed IdP deployment before publication.

Actor Profile's generic JWT-grant audience guidance currently
uses a token endpoint, while ID-JAG requires the RAS issuer.
This profile selects ID-JAG's audience and needs the corresponding
grant-profile precedence clarified in Actor Profile. ID-JAG
actor processing and metadata for its specific output type
should be reviewed together with that work. This does not
change actor identity or preservation semantics.

Sender-bound grant processing also needs coordination with
the JWT authorization-grant work. SCIM Agent resources remain
an optional provisioning mechanism and are not required for
federation conformance.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Preserved existing ID-JAG/EMA client-based delegation and added
  explicit client or Registered Agent actors and self-acting WAG.
* Replaced CIA with ATTEST instance identification and folded
  in vocabulary from draft-mcguinness-oauth-ai-agent-instance.
* Applied Actor Profile to explicit actor delegation and defined
  downstream
  identity correlation, resource processing, and lifecycle rules.
* Limited the core to federation semantics; provisioning and
  access-token formats are deployment choices, downstream instance
  context is optional, and provenance vocabulary is deferred.
