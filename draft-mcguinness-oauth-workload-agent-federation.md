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
  WAG: I-D.carleton-workload-authz-grant
  RFC6749:
  RFC7518:
  RFC7519:
  RFC7523:
  RFC7638:
  RFC8414:
  RFC8693:
  RFC8707:
  RFC8725:
  RFC9068:
  RFC9449:
informative:
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  RFC7662:
  RFC8252:
  SPIFFE-CONCEPTS:
    title: "SPIFFE Concepts"
    target: https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/
    author:
      - org: SPIFFE
    date: 2026
  EMA:
    title: "MCP Enterprise-Managed Authorization"
    target: https://github.com/modelcontextprotocol/ext-auth/blob/main/specification/stable/enterprise-managed-authorization.mdx
    author:
      - org: Model Context Protocol
    date: 2026
  SCIM-AGENT: I-D.wzdk-scim-agent-resource
  RFC7643:
  RFC7644:
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  JWT-DPOP: I-D.parecki-oauth-jwt-dpop-grant
--- abstract

This specification defines how an identity provider binds a
platform-authenticated agent to a registered agent principal and
issues authorization grants for that principal. It profiles
Attestation-Based Client Authentication, the client credentials
grant, and OAuth 2.0 Token Exchange. The resulting Workload
Authorization Grant identifies a self-acting agent as subject;
an Identity Assertion JWT Authorization Grant identifies an agent
acting for a user through the OAuth Actor Profile.

--- middle

# Introduction

An agent can have its own OAuth client identity, or a shared OAuth
client can host several independently governed agents. In the first
case, `client_id` identifies the agent; in the second, an additional
`agent_id` distinguishes agents within the shared client. An identity
provider (IdP) binds that authenticated identity and its executing
instance to a stable agent principal in its own namespace.

This document standardizes that binding and two exchanges:

1. A Client Attestation and instance key proof authenticate a
   request for an IdP-issued access token identifying the agent.
2. That access token is exchanged for a Workload Authorization
   Grant {{WAG}} when the agent acts for itself, or is supplied
   as actor evidence alongside a user credential to obtain an
   Identity Assertion JWT Authorization Grant {{ID-JAG}}.

The normative scope is agent evidence, identity resolution,
credential acquisition, and grant issuance. The grant formats
and their downstream processing come from WAG, ID-JAG, and
{{ACTOR-PROFILE}}, with the binding requirements in {{consumption}}.
This document does not define another downstream grant profile.

Existing client-based delegation, including MCP Enterprise-Managed
Authorization, does not require this flow. Model selection is described in
{{models}} and compatibility guidance in {{deployment}}.
End-to-end deployment examples appear in {{flows}}.

## Relationship to Client Attestation and Actor Profile

{{ATTEST}} authenticates a client instance using an attester-issued
Client Attestation and proof of possession of its key. {{INSTANCE}}
adds a stable instance identifier while retaining the base JWT type,
`sub=client_id`, and `cnf.jwk`. This document defines the authorized
agent mapping at the IdP, adding `agent_id` only for shared clients.
It uses the existing ATTEST headers and DPoP combined mode, not a
new authentication method.

The Client Attestation is authentication evidence. The IdP-issued
access token identifies the resolved agent and authorizes exchange
at the IdP. The resulting WAG or ID-JAG authorizes issuance at a
Resource Authorization Server (RAS). Those artifacts have different
purposes and are not interchangeable.

For delegation, Actor Profile supplies actor construction and
preservation rules. The registered agent is the actor; the instance
is execution context. Self-acting access and instance identification
alone do not require Actor Profile. Downstream servers trust the
IdP's grant and need not validate the platform's attestation.

## Choosing an Identity Model {#models}

This section is informative.

Choose the model according to the principal the IdP governs and
the identity the platform can authenticate:

| Model | Use when | Identity and token path | Reason and cost |
|---|---|---|---|
| Existing client-based delegation | The OAuth client is sufficient for policy and no separate registered agent identity is needed | Existing ID-JAG/EMA flow; client context is implicit, or Actor Profile represents the client explicitly | Preserves current deployments without an additional bootstrap; a shared client does not distinguish its agents |
| Agent with its own client identity | The IdP governs a Registered Agent and that agent can authenticate as its own OAuth client | ATTEST `sub=client_id`; map to Registered Agent, obtain an IdP access token, then request WAG or ID-JAG | Simplest federation binding; requires managing a client identity for each independently identified agent |
| Agents behind a shared client | The IdP governs agents individually but the platform authenticates through a common OAuth client | ATTEST `sub=client_id` plus `agent_id`; map to Registered Agent, then use the same acquisition and exchange flow | Avoids separate client identities for hosted agents; requires trusting the attester to distinguish agents and authorize their runtimes |

Use the existing client-based path when its identity and policy
semantics are sufficient. When a Registered Agent identity is needed,
prefer the agent's own client identity if available. Use `agent_id`
to distinguish agents behind a shared client, rather than duplicating
an identity already supplied by `client_id`. These choices do not
depend on whether the implementation is an MCP client or uses CIMD.

The acting relationship is a separate choice. In either federation
model, self-acting access produces WAG with the Registered Agent as
`sub`; user-delegated access produces ID-JAG with the user as `sub`
and the Registered Agent as `act`. An agent can therefore be both
an OAuth client and a delegated actor. Mapping its client identity
to an IdP principal does not create another actor hop.

Runtime identity is another dimension: one agent can run several
instances. `client_instance_id` distinguishes executions for audit
and risk; it does not choose the agent principal or acting relationship.
The federation flow specified here requires instance identification;
existing client-based flows can use it independently when needed.

# Conventions and Scope

{::boilerplate bcp14-tagged}

OAuth terms follow {{RFC6749}} and {{RFC8693}}. Client Attestation,
Client Attester, and Client Instance follow {{ATTEST}}. Instance
Identifier and Instance Context follow {{INSTANCE}}.

Registered Agent:
: A non-human principal represented at the IdP with a stable,
  non-reassignable identifier, status, and authorized platform bindings.

Federation Binding:
: An approved association between a Client Attester, logical OAuth
  client, tenant, and Registered Agent, including a platform agent
  identifier when the client is shared.

A client or IdP claiming this profile MUST implement the bootstrap
in {{bootstrap}} and the exchange requirements for its role and
each output it supports. The IdP and client MUST establish supported
outputs before exchange through trusted configuration and existing
metadata.
The delegated output additionally requires {{ACTOR-PROFILE}}.
This profile supports one agent actor; task authority, delegation
chains, and direct native workload inputs are outside its scope.

# Profile Selection and Identity Binding {#identity}

The IdP MUST configure use of this profile for the logical client,
its approved attesters, and permitted output grants. The attester
trust and key configuration follow {{INSTANCE}}. Configuration MUST
also identify approved RAS issuers, resources, target tenants, and
applicable subject and client mappings. An unsigned request hint
or discovered client metadata MUST NOT establish this authority.

The IdP MUST configure which identity model applies to each client:

| Client represents | Required attestation identity | Federation Binding lookup |
|---|---|---|
| One agent | `sub=client_id`; no `agent_id` | Exact `(iss, sub)` |
| Several agents | `sub=client_id` and `agent_id` | Exact `(iss, sub, agent_id)` |

For an agent with its own client identity, the IdP MUST resolve
the attestation's `(iss, sub)` to its Registered Agent. No separate
agent identifier is required from the platform. For a shared client,
`agent_id` identifies the platform's agent principal and MUST be
included in the lookup. The IdP MUST reject `agent_id` in the first
model and require it in the second; claim presence or absence MUST
NOT select or change the configured model.

Missing or ambiguous bindings MUST cause rejection. Multiple approved
bindings MAY identify the same Registered Agent; display names or
unqualified subject strings MUST NOT establish equivalence. The IdP's
Registered Agent identifier need not equal the source `client_id`
or `agent_id`.

The Registered Agent identifier MUST be unique and non-reassignable
within the IdP issuer's namespace. Source and target tenant context
MUST be unambiguous, including when an issuer serves several tenants.
A new runtime or key does not by itself create a new Registered Agent.

A client required to use this profile MUST NOT obtain equivalent
authority by omitting required agent evidence or substituting
credentials that identify only the shared client. Failed validation MUST NOT
fall back to a less restrictive path. Other configured client flows
remain governed by their own specifications.

# Obtaining an IdP Access Token {#bootstrap}

The client obtains a JWT access token for exchange at the IdP.
This section fixes the request, evidence, identity, and key binding;
it does not introduce a new token type or scope value.

## Agent Evidence {#agent-evidence}

The Client Attestation MUST conform to {{INSTANCE}}. When the client
represents the agent, its `sub` supplies the agent identity and the
attestation MUST omit `agent_id`. For a shared client, the attestation
MUST include `agent_id`, a nonempty StringOrURI {{RFC7519}} identifying
the platform's agent principal in the attester's namespace.

In either model, the attester MUST verify that the instance is an
authorized execution of the identified agent and possesses the key
in `cnf.jwk`. A caller-supplied identifier alone is insufficient.

The attestation's `sub` remains `client_id`; `client_instance_id`
identifies the runtime. The attestation lifetime MUST NOT exceed
300 seconds. Missing required claims, empty identifiers, or incorrectly
typed agent evidence MUST cause rejection. No model or runtime
provenance claims are defined here.

Example decoded Client Attestation payload for an agent with its
own client identity. The IdP maps this client to `agent-42`; the
subsequent requests and grants use that binding.

~~~ json
{
  "iss": "https://attester.example/tenant/acme",
  "sub": "https://platform.example/agents/support-agent-7",
  "client_instance_id": "inst-7f3d9a2e",
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

For a shared client, the attestation instead uses that client's
identifier, such as `https://platform.example/oauth-client`, as
`sub` and includes `"agent_id": "support-agent-7"`. The request's
`client_id` matches that shared client identifier. The approved
binding can resolve to the same `agent-42` in either model.

## Request

The client MUST use the client credentials grant with `resource`
equal to the IdP issuer identifier. Authentication MUST use
`attest_jwt_client_auth_dpop`, with the Client Attestation in
`OAuth-Client-Attestation` and a DPoP combined-mode proof under
{{ATTEST}}. The attestation MUST NOT be supplied as `subject_token`,
`actor_token`, or `client_assertion`.

Examples abbreviate cryptographic values and omit HTTP framing
headers. Line breaks in form bodies are for display only.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...attestation...
DPoP: eyJ...instance-proof...

grant_type=client_credentials
&client_id=https%3A%2F%2Fplatform.example%2Fagents%2Fsupport-agent-7
&resource=https%3A%2F%2Fidp.example%2Ftenant%2Facme
~~~

## Processing and Response {#idp-access-token}

The IdP MUST validate the attestation and proof under {{INSTANCE}},
resolve the Federation Binding, and verify that the Registered
Agent is active and permitted to use this client and exchange
service. Successful client authentication alone is insufficient.

The issued access token MUST conform to {{RFC9068}} and contain:

| Claim | Required value |
|---|---|
| `iss` | IdP issuer identifier |
| `sub` | Resolved Registered Agent identifier |
| `client_id` | Authenticated logical client identifier |
| `aud` | IdP issuer identifier, identifying the exchange service |
| `sub_profile` | `ai_agent` under {{ENTITY-PROFILES}} |
| `client_instance` | Validated `(iss, client_instance_id)` as the `iss` and `id` members defined by {{INSTANCE}} |
| `cnf.jkt` | SHA-256 JWK thumbprint of the proven instance key under {{RFC7638}} |

The token MUST NOT contain `act`. Its lifetime MUST NOT exceed
300 seconds or the attestation's remaining lifetime. The IdP MUST
associate it with the Federation Binding, source tenant, and
exchange authorization through trusted issuance policy or token
state. Audience matching alone MUST NOT make another IdP access
token eligible for this flow.

The response follows {{RFC6749}} with `token_type=DPoP` and
`expires_in`. No refresh token is issued. Clients need not parse
the access token. It MAY be reused with fresh proofs until expiry;
renewal or key rotation requires new issuance. An instance identifier
MUST NOT authorize rebinding an existing token to a different key.

~~~ json
{
  "access_token": "eyJ...agent-access-token...",
  "token_type": "DPoP",
  "expires_in": 300
}
~~~

# Requesting an Authorization Grant {#exchange}

The client MUST use {{RFC8693}} at the IdP token endpoint with
the same logical client and ATTEST DPoP combined-mode authentication.
The fresh proof key MUST match the IdP-issued access token's
`cnf.jkt`. In both outputs:

* `grant_type` is `urn:ietf:params:oauth:grant-type:token-exchange`.
* `audience` MUST be exactly one target RAS issuer identifier.
* `resource` MUST be exactly one resource {{RFC8707}} at that RAS.
* `scope` MUST contain a nonempty set of requested resource scopes.

This profile does not support `authorization_details`; its presence
MUST cause `invalid_request`. Exchange eligibility does not itself
grant downstream resource authority.

## Self-Acting Agent {#self-exchange}

`requested_token_type` MUST be `urn:ietf:params:oauth:token-type:wag`.
`subject_token` MUST be the IdP-issued access token, with
`subject_token_type=urn:ietf:params:oauth:token-type:access_token`.
Neither actor parameter is permitted. WAG identifiers remain subject
to coordination in {{coordination}}.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...attestation...
DPoP: eyJ...instance-proof...

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=https%3A%2F%2Fplatform.example%2Fagents%2Fsupport-agent-7
&requested_token_type=urn:ietf:params:oauth:token-type:wag
&subject_token=eyJ...agent-access-token...
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&audience=https%3A%2F%2Fas.app.example
&resource=https%3A%2F%2Fapi.app.example
&scope=tickets.read
~~~

## Agent Acting for a User {#delegated-exchange}

`requested_token_type` MUST be
`urn:ietf:params:oauth:token-type:id-jag`. `actor_token` MUST be
the IdP-issued access token, with
`actor_token_type=urn:ietf:params:oauth:token-type:access_token`.
The IdP MUST apply Actor Profile's JWT access-token actor-input
processing. The token's `sub` identifies the Registered Agent;
its instance context does not supply `act.sub`.

`subject_token` MUST be a user credential accepted under {{ID-JAG}}.
Implementations MUST support an OpenID Connect ID Token with
`subject_token_type=urn:ietf:params:oauth:token-type:id_token`.
Other inputs permitted by ID-JAG MAY be supported with their
validation and authorization limits. Inputs carrying an existing
`act` chain MUST be rejected, not erased or extended.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...attestation...
DPoP: eyJ...instance-proof...

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=https%3A%2F%2Fplatform.example%2Fagents%2Fsupport-agent-7
&requested_token_type=urn:ietf:params:oauth:token-type:id-jag
&subject_token=eyJ...user-id-token...
&subject_token_type=urn:ietf:params:oauth:token-type:id_token
&actor_token=eyJ...agent-access-token...
&actor_token_type=urn:ietf:params:oauth:token-type:access_token
&audience=https%3A%2F%2Fas.app.example
&resource=https%3A%2F%2Fapi.app.example
&scope=tickets.read
~~~

## IdP Processing {#idp-processing}

Before issuance, the IdP MUST:

1. Validate the current client attestation and proof and resolve
   the Federation Binding under {{identity}}.
2. Validate the IdP-issued access token's signature, issuer,
   audience, lifetime, and eligibility under {{idp-access-token}}.
   Match its client, agent, instance, source tenant, and key to
   the current authenticated evidence. Reject inconsistent inputs.
3. Check current agent status, attester trust, external binding,
   application assignment, and permitted output. Validate the
   RAS/resource association and determine an authorized nonempty
   subset of the requested scopes.
4. For delegation, validate the user credential under {{ID-JAG}},
   including audience/client checks and applicable scope ceilings.
   Resolve the user and downstream client. Verify user-approved
   or administrator-authorized delegation for this Registered
   Agent, user, client context, resource, and scope. Two valid
   credentials alone MUST NOT establish that authorization.
5. Construct the grant under {{grant}} using the resolved principal
   and proven key, with no broader authority than authorized above.

The means of obtaining delegation approval is outside this profile.
Approval MUST identify the acting principal and authorized access
unambiguously; a shared client MUST NOT let one agent use another's
approval. Missing approval MUST prevent delegated issuance.

## Grant Construction {#grant}

The IdP MUST issue a signed JWT satisfying {{WAG}} or {{ID-JAG}},
as requested, with an approved asymmetric algorithm and a `kid`
resolvable through trusted issuer configuration. Implementations
MUST support `ES256` {{RFC7518}} in addition to requirements of
the underlying specifications.

The grant MUST contain the IdP's issuer in `iss`, the exact target
RAS issuer in `aud`, and the approved `resource` and `scope`.
`cnf.jkt` MUST equal the thumbprint of the validated instance key.
The grant lifetime MUST NOT exceed 300 seconds or the remaining
validity of the IdP-issued access token, accepted user credential,
or applicable delegation. The IdP MUST assign a unique `jti` and
MUST NOT reuse `(iss, jti)`.

For WAG, `sub` MUST equal the Registered Agent identifier in the
IdP-issued access token and `sub_profile` MUST be `ai_agent`.
The grant MUST NOT contain `act`.

For ID-JAG, `sub` is the user identifier resolved under ID-JAG's
subject-mapping rules. Actor Profile construction MUST introduce
exactly one actor, with `act.iss` and `act.sub` copied from the
IdP-issued access token and `act.sub_profile=ai_agent`. The ID-JAG
MUST include the downstream `client_id` and other required ID-JAG
claims, including applicable tenant context. Translating a client
identifier MUST NOT rewrite the agent actor's namespace.

The IdP MAY include `client_instance` for downstream audit or risk.
If included, it MUST identify the authenticated instance through an
unambiguous mapping, with `iss` equal to the IdP issuer and `id` an
IdP-assigned reference. It describes the subject's execution for
WAG and the actor's execution for ID-JAG, without changing either
principal. The IdP SHOULD scope this reference to the recipient.

Example WAG payload:

~~~ json
{
  "iss": "https://idp.example/tenant/acme",
  "sub": "agent-42",
  "sub_profile": "ai_agent",
  "aud": "https://as.app.example",
  "resource": "https://api.app.example",
  "scope": "tickets.read",
  "cnf": {
    "jkt": "Ak20Cf62SpTybasujYXbaI-Ms655MyvOZCtnnf8y1QU"
  },
  "iat": 1789128000,
  "exp": 1789128240,
  "jti": "grant-f194"
}
~~~

Example ID-JAG payload:

~~~ json
{
  "iss": "https://idp.example/tenant/acme",
  "sub": "user-17",
  "act": {
    "iss": "https://idp.example/tenant/acme",
    "sub": "agent-42",
    "sub_profile": "ai_agent"
  },
  "client_id": "support-agent-at-app",
  "aud": "https://as.app.example",
  "resource": "https://api.app.example",
  "scope": "tickets.read",
  "cnf": {
    "jkt": "Ak20Cf62SpTybasujYXbaI-Ms655MyvOZCtnnf8y1QU"
  },
  "iat": 1789128000,
  "exp": 1789128240,
  "jti": "grant-f195"
}
~~~

## Response and Errors

The response follows {{RFC8693}}. `issued_token_type` MUST equal
the requested output type, `token_type` MUST be `N_A`, and
`access_token` contains the grant. `expires_in` gives its remaining
lifetime and `scope` lists approved scopes. No refresh token is issued.

The client MUST verify the returned type and the grant's protected
JWT type, audience, resource, scope subset, and `cnf.jkt` for its
proven key. A mismatch MUST cause failure. These checks do not
replace cryptographic grant validation at the RAS.

Malformed requests, unsupported outputs or combinations, and actor
chains use `invalid_request`. Invalid exchange credentials or
inconsistent bindings use `invalid_grant`; invalid targets and
scopes use `invalid_target` and `invalid_scope`. Missing or
prohibited delegation for a validated actor uses `actor_unauthorized`
under {{ACTOR-PROFILE}}. A client not permitted to use this profile
receives `unauthorized_client`. ATTEST authentication and DPoP
freshness errors retain their base processing. A failed delegated
request MUST NOT produce a self-acting grant.

# Grant Consumption {#consumption}

Redemption, client authentication, replay handling, token responses,
and resource-server processing follow {{WAG}} or {{ID-JAG}} and
{{RFC7523}}. Delegated processing additionally follows Actor Profile,
including preservation of `act`. This document does not define a
separate redemption protocol, access-token format, or introspection
schema. Downstream access-token lifetimes and refresh behavior
follow the underlying grant and resource authorization policy.

Grants issued here are bound to the instance key. The IdP MUST issue
only to a RAS configured to validate that binding. The client MUST
present a fresh DPoP proof at redemption. The RAS MUST validate it
under {{RFC9449}} and reject a missing or invalid proof or a key
that does not match `cnf.jkt`, using ID-JAG's bound-grant processing
for ID-JAG and the same checks for WAG. WAG's binding and redemption
specification still requires the coordination described in
{{coordination}}. A valid access token
issued by the RAS, rather than an upstream credential or grant,
is used at the resource server.

# Metadata and Configuration {#metadata}

The IdP MUST advertise `client_credentials`, token exchange, and
`attest_jwt_client_auth_dpop` through existing {{RFC8414}} metadata,
and DPoP `ES256` support under {{RFC9449}}. Profile selection and
approved identity bindings use the configuration in {{identity}}.
Delegated implementations use Actor Profile's existing metadata for
ID Token subject input, JWT access-token actor input, ID-JAG output,
and supported entity profiles, including `ai_agent`.

RAS capabilities are advertised under the selected grant and, where
applicable, Actor Profile. The IdP MUST verify the configured RAS
supports the required grant, binding, and actor processing before
issuance. No new grant-profile identifier, metadata parameter,
bootstrap scope, or token marker is defined here. Metadata discovery
does not establish issuer trust or delegation authority.

# Security and Privacy Considerations

The security requirements of {{ATTEST}}, {{INSTANCE}}, {{RFC8693}},
{{RFC8725}}, and the selected output specification apply. The IdP
MUST bind client, agent, instance, tenant, and key to one authorized
request. Independently valid credentials for different agents or
instances MUST NOT be combined. A stable instance identifier does
not authorize key rebinding or establish a delegation relationship.

The IdP MUST check current status and authorization on each issuance,
including attester trust, agent bindings, assignments, and delegation.
It MUST define freshness limits for cached authorization data and
reject data exceeding those limits. A disabled agent or revoked
binding MUST prevent new issuance once applied at the IdP, even if
an earlier access token remains unexpired. This does not promise
immediate revocation of downstream access tokens.

Configured requirements for agent identity, key binding, or explicit
actors MUST NOT be bypassed by choosing an existing client-based
flow. Supplying only a shared client identity does not authenticate
an agent underneath it. Successful grant redemption does not justify
adding an actor hop merely because a runtime or server participated.

Stable agent and instance identifiers can permit correlation.
The IdP SHOULD release only necessary context and retain internal
mappings for recipient-scoped instance references. Raw attestation
material and private keys MUST NOT appear in grants or audit logs.

# IANA Considerations

This specification requests registration of `agent_id` in the
JWT Claims registry established by {{RFC7519}}, with description
"Attester-scoped agent principal identifier", reference
{{agent-evidence}}, and Change Controller IETF. Its value is a
nonempty StringOrURI. This profile uses it only for agents represented
by a shared client.

`client_instance` is defined by {{INSTANCE}}; `act` follows
{{ACTOR-PROFILE}}; `ai_agent` is defined by {{ENTITY-PROFILES}}.
No new actor format, access-token type, or grant-profile URI is
registered. WAG identifiers are addressed in {{coordination}}.

--- back

# Deployment and Compatibility {#deployment}
{:numbered="false"}

This appendix is informative.

Existing ID-JAG flows, including MCP
Enterprise-Managed Authorization {{EMA}}, can authorize a client
for a user without a separately represented agent. The user is the
subject and the client is identified through normal OAuth context.
Absence of `act` does not imply absence of authorization, a human
presenter, or self-acting access. Those deployments retain their
existing authentication and sender-constraint choices and need no
bootstrap from this specification.

CIMD {{CIMD}} can supply client metadata and a common client identifier
across servers. When the client itself is the explicit actor, Actor
Profile already defines JWT client assertion input, including reuse
of one JWT as `client_assertion` and `actor_token`. That path does not
require an additional IdP-issued access token or ATTEST. A shared
client identity does not distinguish separately governed agents.
Instance identification can add audit context to client-based flows
without introducing an actor.

Agent admission and provisioning can use administrative configuration,
JIT, or SCIM Agent resources {{SCIM-AGENT}} with {{RFC7644}}. A SCIM
`externalId` {{RFC7643}} can correlate a record with the IdP agent
identifier when issuer and tenant are retained. Groups, ownership,
and assignments are policy inputs; group claims about an ID-JAG user
do not describe the agent actor's memberships. Provisioning transport,
synchronization, policy engines, access-token formats, and introspection
{{RFC7662}} are deployment choices outside this profile.

Native workload mechanisms such as {{SPIFFE-OAUTH}} can support
additional input profiles. Those profiles need their own credential
validation, client and agent mapping, and proof rules. They are not
interchangeable with the Client Attestation input specified here.
The direct SPIFFE example in {{spiffe-flow}} illustrates this boundary.

# End-to-End Deployment Examples {#flows}
{:numbered="false"}

This appendix is informative. A harness is the software executing
the agent and making OAuth requests. These examples separate its
hosting environment, authentication evidence, and acting relationship:

| Deployment | Evidence accepted by IdP | Identity model | Example output |
|---|---|---|---|
| SPIFFE workload | X.509-SVID and DPoP | Agent is the client | Self-acting WAG; proposed native input extension |
| Harness on managed device | Enterprise Client Attestation and DPoP | Agent is the client | User-delegated ID-JAG |
| Harness in managed platform | Platform Client Attestation and DPoP | Agents share a client | Self-acting WAG, with delegated variant |

In each example, the IdP maintains the agent's status, owner, groups,
and application assignments. Before issuance, it establishes the
external identity binding and trusts the relevant credential issuer.
The RAS trusts the IdP at `https://idp.example/tenant/acme` as grant
issuer. Administrative configuration, JIT, or SCIM can establish
the downstream agent record, correlated by IdP issuer and agent
identifier. Receiving a grant does not by itself provision a record
or authorize every scope.

The examples request `tickets.read` at `https://api.app.example`
through the RAS `https://as.app.example`. Each harness controls its
own key, denoted `K`; `JKT(K)` denotes its thumbprint. JWKs sent to
attesters contain only public keys. IdP requests use the authentication
described in each example, with fresh proofs for the respective
endpoints. The illustrated RAS
issues DPoP access tokens bound to that key, an explicit deployment
choice under {{consumption}}. WAG issuance and redemption remain
subject to {{coordination}}.

## SPIFFE Workload to IdP {#spiffe-flow}
{:numbered="false"}

Use this model when the workload already has a SPIFFE identity
representing the agent. This example uses X.509-SVID client
authentication under {{SPIFFE-OAUTH}}. Its integration with agent
acquisition and exchange is a proposed input extension, not an
alternative conformance path defined by this document.

~~~
 Workload           Harness            IdP          RAS         API
    API
     |                 |                |            |           |
     |<-- get SVID ----|                |            |           |
     |-- X.509-SVID -->|                |            |           |
     |                 |- credentials ->|            |           |
     |                 |<--- IdP AT ----|            |           |
     |                 |--- exchange -->|            |           |
     |                 |<---- WAG ------|            |           |
     |                 |-------- WAG + DPoP -------->|           |
     |                 |<--------- app AT -----------|           |
     |                 |------------- app AT + DPoP ------------>|
     |                 |<--------------- tickets ----------------|
~~~

1. The harness obtains an X.509-SVID for
   `spiffe://workloads.example/agents/support` from its Workload API.
   The IdP has approved that exact identity and trust domain for
   Registered Agent `agent-42`; trusting the domain alone does not
   admit every workload as that agent.
2. The harness sends a client credentials request to the IdP over
   mutually authenticated TLS, with that SPIFFE ID as `client_id`
   and the IdP issuer as `resource`. A DPoP proof establishes a
   separate application key `K`. The IdP validates the SVID using
   the configured SPIFFE trust bundle and resolves the agent binding.
3. Under the proposed input extension, the IdP issues an access
   token with `sub=agent-42`, the SPIFFE ID as `client_id`, its own
   issuer as `aud`, and `cnf.jkt=JKT(K)`. The TLS credential
   authenticates the workload; `K` binds the issued token.
4. The harness requests WAG using that access token as
   `subject_token`, the target RAS as `audience`, and the API and
   scope above. It again authenticates with its SVID and proves
   possession of `K`. The IdP checks the current binding and policy
   before issuing WAG with `sub=agent-42` and no `act`.
5. The harness redeems WAG at the RAS with a fresh proof from `K`,
   receives the application access token, and calls the API. The
   downstream processing is described in {{app-consumption}}.

The illustrative bootstrap request is sent over the mutually
authenticated TLS connection established with the X.509-SVID:

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
DPoP: eyJ...workload-key-proof...

grant_type=client_credentials
&client_id=spiffe%3A%2F%2Fworkloads.example%2Fagents%2Fsupport
&resource=https%3A%2F%2Fidp.example%2Ftenant%2Facme
~~~

The missing input profile needs to replace the ATTEST-specific
checks in {{bootstrap}} and {{idp-processing}}, define native
credential renewal and exchange eligibility, and settle runtime
correlation. A SPIFFE workload can have several instances
{{SPIFFE-CONCEPTS}}; neither its SPIFFE ID nor a rotating certificate
fingerprint supplies the stable instance identifier required here.
The example therefore does not invent `client_instance_id` from
either value. A SPIFFE-backed attester could instead issue a
conforming Client Attestation after validating runtime and key
evidence, but that is a separate attestation step.

## Harness on a Managed Device {#device-flow}
{:numbered="false"}

Use this model when an enterprise governs a desktop agent as a
Registered Agent with its own client identity. The example binds
`client_id=https://desktop.example/agents/dev-17` to `agent-17`.
The IdP trusts `https://devices.example/attester` to attest this client.
The managed device, the agent, and the running harness are different
entities; device enrollment does not itself authorize user delegation.

~~~
Enterprise         Harness      User/browser     IdP      RAS     API
attester
    |                 |               |           |        |       |
    |< evidence, JWK -|               |           |        |       |
    |-- attestation ->|               |           |        |       |
    |                 |-- credentials + ATTEST -->|        |       |
    |                 |<-------- IdP AT ----------|        |       |
    |                 |--- sign-in -->|           |        |       |
    |                 |               |- sign-in >|        |       |
    |                 |               |<- code ---|        |       |
    |                 |<--- code -----|           |        |       |
    |                 |------- code + PKCE ------>|        |       |
    |                 |<------- ID Token ---------|        |       |
    |                 |-- user + actor exchange ->|        |       |
    |                 |<-------- ID-JAG ----------|        |       |
    |                 |---------- ID-JAG + DPoP ---------->|       |
    |                 |<------------- app AT --------------|       |
    |                 |-------------- app AT + DPoP -------------->|
    |                 |<---------------- tickets ------------------|
~~~

1. The harness generates `K`. The enterprise attester validates
   the managed-device evidence, permitted harness, agent assignment,
   and key possession. It issues a Client Attestation with the
   agent's client identifier as `sub`, `client_instance_id=run-d17`,
   and `cnf.jwk` containing `K`'s public key. There is no `agent_id`.
   Device identifiers stay in enterprise records. Evidence formats
   and the attestation issuance API are deployment-specific, as
   in {{ATTEST}}.
2. The harness follows {{bootstrap}} with ATTEST DPoP combined-mode
   authentication. The returned IdP access token identifies
   `agent-17`, its client and instance, and `JKT(K)`.
3. The user signs in through an external browser using an
   authorization code flow with PKCE, following {{RFC8252}}.
   Code redemption also uses the client's configured authentication.
   The resulting user ID Token is intended for this client. The
   enterprise records user or administrator approval for this agent
   to read tickets for that user; sign-in alone is not that approval.
4. The harness follows {{delegated-exchange}}, sending the user
   ID Token as `subject_token` and the IdP access token as
   `actor_token`, with fresh ATTEST authentication. The IdP validates
   both identities and the delegation, then issues ID-JAG with
   `sub=user-17`, `act={iss: IdP, sub: agent-17, sub_profile: ai_agent}`,
   and the downstream client identifier `dev-agent-at-app`.
5. The harness redeems ID-JAG and accesses the API as described in
   {{app-consumption}}. The device attester and device record do not
   become actors in that request.

If the enterprise only needs existing client-based delegation, the
harness can use the ID-JAG/EMA path in {{deployment}} without the
agent bootstrap and actor token. A desktop harness shared by several
separately governed agents instead uses the shared-client binding
illustrated in {{platform-flow}}. Device hosting does not select
the identity model automatically.

## Harness in a Managed Platform {#platform-flow}
{:numbered="false"}

Use this model when a hosting platform runs separately governed
agents through one OAuth client. The IdP approves the platform
attester `https://attester.example/tenant/acme` for shared client
`https://platform.example/oauth-client`, mapping its
`agent_id=support-agent-7` to Registered Agent `agent-42`.

~~~
 Platform           Harness            IdP          RAS         API
 attester
     |                 |                |            |           |
     |-- start agent ->|                |            |           |
     |< runtime, JWK --|                |            |           |
     |-- attestation ->|                |            |           |
     |                 |- credentials ->|            |           |
     |                 |<--- IdP AT ----|            |           |
     |                 |--- exchange -->|            |           |
     |                 |<---- WAG ------|            |           |
     |                 |-------- WAG + DPoP -------->|           |
     |                 |<--------- app AT -----------|           |
     |                 |------------- app AT + DPoP ------------>|
     |                 |<--------------- tickets ----------------|
~~~

1. The control plane launches `support-agent-7`. Its harness
   generates `K`. The attester verifies the launch assignment,
   runtime isolation, and key possession, then issues an attestation
   with `sub` equal to the shared client, `agent_id=support-agent-7`,
   `client_instance_id=run-p42`, and `cnf.jwk` containing the public
   key. The harness cannot select another agent merely by naming it.
2. The harness follows {{bootstrap}}, sending the shared `client_id`.
   The IdP resolves `(iss, sub, agent_id)` and returns an access token
   with `sub=agent-42`, the shared `client_id`, validated instance
   context, and `cnf.jkt=JKT(K)`.
3. For unattended ticket processing, the harness follows
   {{self-exchange}}. The IdP authorizes access using `agent-42`'s
   assignments and issues WAG with `sub=agent-42`, no `act`, and the
   same key binding. The harness redeems it and calls the API as
   described in {{app-consumption}}.
4. For user-delegated work, the harness instead follows
   {{delegated-exchange}} with an accepted user credential and the
   agent access token. After checking delegation approval, the IdP
   issues ID-JAG with the user as `sub` and `agent-42` as `act`.
   The hosting platform is client context, not an additional actor.

A second runtime for this agent gets a different instance identifier
and key, but the same `agent-42` principal. A different agent behind
the shared client has its own binding and permissions. The IdP
does not infer equivalent authority from the common client identity.

## Downstream Application Processing {#app-consumption}
{:numbered="false"}

All three examples finish at the same application trust boundary:

1. The harness presents the IdP-issued grant to the RAS using the
   selected grant's redemption procedure and configured client
   authentication, including ID-JAG's downstream client binding.
   Its DPoP proof uses the key named by the grant's `cnf.jkt`.
2. The RAS validates the trusted IdP signature, issuer, audience,
   lifetime, replay state, target resource, scopes, and key proof.
   It resolves the subject and any actor, applies local assignments,
   and issues an API access token. In these examples it retains
   the IdP's principal identifiers and uses a JWT access token.
3. The API receives only its access token and a fresh DPoP proof,
   including the access-token hash under {{RFC9449}}. It validates
   the token and proof, then evaluates resource policy for the agent
   or the user and agent actor. It does not consume the upstream
   SVID, device evidence, Client Attestation, WAG, or ID-JAG.

| Example | Application access-token identity | Key binding |
|---|---|---|
| SPIFFE workload, self-acting | `sub=agent-42`, no `act` | `cnf.jkt=JKT(K)` |
| Managed device, delegated | `sub=user-17`, `act.sub=agent-17` | `cnf.jkt=JKT(K)` |
| Managed platform, self-acting | `sub=agent-42`, no `act` | `cnf.jkt=JKT(K)` |
| Managed platform, delegated variant | User `sub`, `act.sub=agent-42` | `cnf.jkt=JKT(K)` |

For delegated tokens, the actor also retains its IdP `iss` and
`sub_profile=ai_agent` under Actor Profile. The RAS is the access-token
issuer and the API is its audience. Groups and owner relationships
can come from provisioned records or approved claims; user groups
do not supply an agent actor's memberships. Optional instance context
supports audit and risk without changing those principal identities.

# Interoperability Cases
{:numbered="false"}

Independent platform, client, and IdP implementations can exercise:

| Case | Required result |
|---|---|
| Agent has its own client identity; approved `(iss, sub)` binding, instance proof, and no `agent_id` | IdP access token for the Registered Agent |
| Shared client; approved `(iss, sub, agent_id)` binding and instance proof | IdP access token for the Registered Agent |
| Shared client omits `agent_id` | Reject; no fallback to client-only binding |
| Agent with its own client identity supplies `agent_id` | Reject; no switch to the shared-client model |
| Missing, ambiguous, or disabled binding | Reject issuance |
| Same agent in a second runtime | Same agent subject; distinct instance |
| Unrelated client, agent, instance, or key at exchange | Reject inconsistent evidence |
| Agent acting for itself | WAG subject is the agent; no `act` |
| Agent acting for a user | User subject; Registered Agent `act` |
| Valid user and agent credentials without delegation | `actor_unauthorized` |
| Unsupported requested output | `invalid_request`; no fallback |
| Optional downstream instance context | Same principal and binding semantics |
| Grant redemption with missing or mismatched proof | Reject under the bound-grant rules |

Only cases for the implemented output are applicable. Existing
client-based deployments are compatibility context, not an additional
conformance path for this specification.

# Coordination with Related Work {#coordination}
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

The proposed WAG token type `urn:ietf:params:oauth:token-type:wag`
and JWT type `oauth-wag+jwt` await definition and registration in
{{WAG}}. WAG's issuer model, advance-projection restrictions, and
audience rules need alignment with this IdP-issued use. WAG currently
leaves proof of possession open; the bound-grant checks selected in
{{consumption}} need alignment there before publication. They are
not an assertion that unextended WAG implementations support them.

Actor Profile's generic JWT-grant audience guidance uses a token
endpoint, while ID-JAG uses the RAS issuer. This document selects
ID-JAG's audience and needs grant-profile precedence clarified in
Actor Profile. Redemption details for sender-bound JWT grants also
need coordination with {{JWT-DPOP}} and ID-JAG. This document does
not register a competing redemption mechanism.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Focused the standards-track profile on platform-to-IdP agent
  identity binding, access-token acquisition, and grant issuance.
* Reused ATTEST instance identification and Actor Profile delegation.
* Used `client_id` as agent identity when the agent is the client;
  required `agent_id` only for agents represented by a shared client.
* Illustrated SPIFFE, managed-device, and managed-platform flows,
  including the missing native SPIFFE input integration.
* Moved existing client flows and deployment choices to informative
  guidance and inherited downstream grant processing.
