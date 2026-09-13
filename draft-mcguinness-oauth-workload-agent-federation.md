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
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  WIT: I-D.ietf-wimse-workload-creds
  ATTEST: I-D.ietf-oauth-attestation-based-client-auth
  ACTOR-PROFILE: I-D.mcguinness-oauth-actor-profile
  ENTITY-PROFILES: I-D.mora-oauth-entity-profiles
  ID-JAG: I-D.ietf-oauth-identity-assertion-authz-grant
  IDENTITY-CHAINING: I-D.ietf-oauth-identity-chaining
  WAG: I-D.carleton-workload-authz-grant
  RFC6749:
  RFC6838:
  RFC7518:
  RFC7519:
  RFC7523:
  RFC7638:
  RFC7800:
  RFC8414:
  RFC8693:
  RFC8707:
  RFC8725:
  RFC9068:
  RFC9449:
informative:
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  JWT-DPOP: I-D.parecki-oauth-jwt-dpop-grant
  RFC2046:
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
--- abstract

This specification defines how an identity provider binds a
platform-authenticated agent to a registered agent principal and
issues authorization grants for that principal. It profiles
Attestation-Based Client Authentication, SPIFFE X.509-SVID, or
WIT-SVID client authentication together with the client credentials
grant and OAuth 2.0 Token Exchange. Stable instance identification is
an optional extension. The resulting Workload Authorization Grant
identifies a self-acting agent as subject; an Identity Assertion JWT
Authorization Grant identifies an agent acting for a user through the
OAuth Actor Profile.

--- middle

# Introduction

An agent's identity in OAuth has three independent dimensions. The
agent principal is the non-human identity an identity provider (IdP)
governs, with status, owner, and assignments. The acting relationship
is whether the agent acts for itself or on behalf of a user. The
instance is the installation or execution presenting a request.
Conflating these dimensions causes most agent authorization errors: a
client identifier is treated as a principal, an execution is treated
as an agent, or a self-acting agent is given a user's delegation.

This document specifies both acting relationships end to end. An
agent acting for itself obtains a Workload Authorization Grant
{{WAG}} naming the agent as subject. An agent acting on behalf of a
user obtains an Identity Assertion JWT Authorization Grant {{ID-JAG}}
naming the user as subject and the agent as actor under
{{ACTOR-PROFILE}}. Both grants are issued by the IdP, bound to a key
the agent proves, and redeemed at a Resource Authorization Server
(RAS) for a sender-constrained access token.

The agent authenticates with a credential its platform can produce.
An agent can have its own OAuth client identity, or a shared OAuth
client can host several independently governed agents. In the first
case, `client_id` identifies the agent; in the second, an additional
`agent_id` distinguishes agents within the shared client. The IdP
binds that authenticated identity to a Registered Agent in its own
namespace. Optional instance context identifies the installation or
execution presenting the request.

Issuance has two steps:

1. The agent authenticates with an approved credential and proves
   possession of a key to obtain a short-lived IdP-issued access
   token, unless it already holds one.
2. That access token is exchanged for a WAG when the agent acts for
   itself, or is supplied as actor evidence alongside a user
   credential to obtain an ID-JAG.

The IdP-issued access token exists because {{RFC8693}} exchanges
tokens, not client authentications. It gives the self-acting exchange
a `subject_token` and the delegated exchange an `actor_token` that
the IdP has already validated, so the exchange step is identical for
every authentication input and the agent principal is established
once, at one validation point, however the platform authenticated it.

The normative scope is agent evidence, identity resolution,
access-token acquisition, grant issuance, and the redemption
requirements both grants share. ID-JAG's format and downstream
processing come from {{ID-JAG}} and {{ACTOR-PROFILE}}. WAG defines
the grant concept and its RFC 7523 redemption; this document defines
the token type, JWT type, issuer model, audience, key binding, and
claims needed to issue a WAG from an IdP ({{self-exchange}},
{{grant}}). This document does not define another downstream grant
profile.

Existing client-based delegation, including MCP Enterprise-Managed
Authorization, does not require this flow. Model selection is described in
{{models}} and compatibility guidance in {{deployment}}.
End-to-end deployment examples appear in {{flows}}.

This document, together with {{INSTANCE}}, is intended to replace
draft-mcguinness-oauth-ai-agent-instance. Agent identity binding and
grant issuance are specified here; instance identification is
specified in {{INSTANCE}}.

## Relationship to Client Attestation and Actor Profile

{{ATTEST}} supplies one authentication binding. {{SPIFFE-OAUTH}}
supplies native X.509-SVID and WIT-SVID bindings. WIT-SVID uses a
Workload Identity Token {{WIT}} directly in the ATTEST header with
its key-possession proof; no additional attestation wraps the WIT.
All inputs resolve to an IdP agent principal and establish a DPoP key.
{{INSTANCE}} optionally adds
stable instance context to ATTEST; it is not a prerequisite for
agent authentication or token exchange. The ATTEST binding retains
`sub=client_id` and adds `agent_id` only for shared clients.

The Client Attestation or SVID is authentication evidence. The IdP-issued
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
| Agent with its own client identity | The IdP governs a Registered Agent and that agent can authenticate as its own OAuth client | ATTEST or SPIFFE authenticates `client_id`; map to Registered Agent and exchange an eligible IdP access token | Simplest federation binding; requires managing a client identity for each independently identified agent |
| Agents behind a shared client | The IdP governs agents individually but the platform authenticates through a common OAuth client | ATTEST `sub=client_id` plus `agent_id`; map to Registered Agent, then use the same acquisition and exchange flow | Avoids separate client identities for hosted agents; requires trusting the attester to distinguish agents and authorize their runtimes |

Use the existing client-based path when its identity and policy
semantics are sufficient. When a Registered Agent identity is needed,
prefer the agent's own client identity if available. Use `agent_id`
to distinguish agents behind a shared client, rather than duplicating
an identity already supplied by `client_id`. These choices do not
depend on whether the implementation is an MCP client or uses CIMD.

A client identifier metadata document {{CIMD}} can give every hosted
agent its own `client_id` without registration, which appears to
remove the need for a shared client. It does not remove the need for
an authority that vouches for which agent is running. A CIMD client
identifier is asserted by whoever controls its URL; the IdP still
needs an approved attester or SVID issuer to bind it to a Registered
Agent. The shared-client model places that authority where it already
exists, in the platform's registered client and its attester, and
uses `agent_id` to name the agent the attester verified. The cost is
that the attester's authority spans every agent behind the client;
{{security}} states the resulting requirements.

The acting relationship is a separate choice. In either federation
model, self-acting access produces WAG with the Registered Agent as
`sub`; user-delegated access produces ID-JAG with the user as `sub`
and the Registered Agent as `act`. An agent can therefore be both
an OAuth client and a delegated actor. Mapping its client identity
to an IdP principal does not create another actor hop.

Instance identity is another dimension: one agent can run in several
installations or executions. `client_instance_id` distinguishes the
configured unit for audit and risk; it does not choose the agent
principal or acting relationship.
Instance identification is optional in this federation flow and in
existing client-based flows. Key possession remains required here
whether or not a stable instance identifier is available.

# Conventions and Scope

{::boilerplate bcp14-tagged}

OAuth terms follow {{RFC6749}} and {{RFC8693}}. Client Attestation,
Client Attester, and Client Instance follow {{ATTEST}}. Instance
Identifier and Instance Context follow {{INSTANCE}}.

Registered Agent:
: A non-human principal represented at the IdP with a stable,
  non-reassignable identifier, status, and authorized platform bindings.

Federation Binding:
: An approved association between a credential authority, external
  identity, OAuth client, tenant, and Registered Agent. An ATTEST
  binding includes the platform agent identifier for a shared client.

Source Tenant:
: The IdP tenant that governs the Registered Agent and issues the
  access token and grant.

Target Tenant:
: The tenant at the RAS in which the agent or user is authorized,
  identified by the IdP's configuration for the approved RAS and
  resource.

Agent Status:
: The IdP's current lifecycle state for a Registered Agent, at
  minimum active or disabled. Only an active agent is eligible for
  issuance.

A client or IdP claiming this profile MUST implement at least one
input binding in {{inputs}}, acquisition in {{bootstrap}}, and the
exchange requirements for its role and supported outputs. Acquisition
is skipped when an eligible access token is already available.
The parties MUST establish a common input and supported outputs
through trusted configuration and existing metadata. The delegated
output additionally requires {{ACTOR-PROFILE}}. WAG defines the grant
concept; {{wag-profile}} defines its issuance by an IdP. Until {{WAG}}
adopts or references those definitions they are specific to this
document, and {{coordination}} lists the open items.
Task authority, delegation chains, and other native input bindings
are outside this profile.

# Profile Selection and Identity Binding {#identity}

The IdP MUST configure the client's input binding, credential
verification authorities and keys, identity model, tenant, and
permitted outputs. Configuration MUST also identify approved RAS
issuers, resources, target tenants, and subject and client mappings.
An unsigned request hint or discovered client metadata MUST NOT
establish this authority or switch the configured input binding.

| Input and client model | Federation Binding lookup |
|---|---|
| ATTEST, agent is the client | Exact attestation `(iss, sub)`; no `agent_id` |
| ATTEST, shared client | Exact attestation `(iss, sub, agent_id)` |
| SPIFFE X.509-SVID, agent is the client | Approved trust domain and exact SPIFFE ID; `client_id` equals that ID |
| SPIFFE WIT-SVID, agent is the client | Approved trust domain and exact WIT `sub`; `client_id` equals that SPIFFE ID |

The IdP MUST resolve this lookup to one Registered Agent. Missing,
ambiguous, or disabled bindings MUST cause rejection. In ATTEST,
it MUST reject `agent_id` for an agent's own client and require it
for a shared client. Claim presence MUST NOT select the model.
Multiple approved bindings MAY identify one Registered Agent;
display names or unqualified strings MUST NOT establish equivalence.
The Registered Agent identifier need not equal the external identifier.

The Registered Agent identifier MUST be unique and non-reassignable
within the IdP issuer's namespace. Source and target tenants MUST
be unambiguous. A new installation, execution, or key does not by
itself create a new Registered Agent. A required binding MUST NOT
be bypassed by omitting evidence or falling back to shared-client
credentials. Other client flows retain their own requirements.

Each item of evidence establishes one thing. Client authentication
establishes the client; the Federation Binding establishes the agent;
the DPoP proof establishes the key; an audience value or
caller-supplied claim establishes nothing by itself. The IdP MUST
require every element its configuration demands and MUST NOT infer
one from another.

## Authentication Inputs {#inputs}

Every acquisition and exchange request MUST authenticate using its
configured input and include a fresh DPoP proof under {{RFC9449}}.
Implementations MUST support `ES256` for DPoP. The IdP MUST bind the
resolved agent, authenticated client, source tenant, and proven key
to the same request.

Every input yields one Registered Agent resolved under {{identity}},
one authenticated logical client, and one proven DPoP key. The
following apply to every input; the input sections add only
input-specific processing.

* The IdP MUST record the input method and external binding with
  the issued access token and match both at exchange under
  {{idp-processing}}.
* Unless the input is a Client Attestation for a shared client,
  the request MUST NOT supply `agent_id` through any parameter or
  credential. The IdP MUST reject it, using
  `invalid_client_attestation` when it is carried in a Client
  Attestation and `invalid_request` otherwise.
* No input establishes stable instance context. The IdP MUST NOT
  derive `client_instance` from an input identifier, key,
  certificate, or claim, and MUST NOT copy unvalidated instance
  claims into issued tokens. {{instance-identification}} is the
  only source of instance context.
* Input credentials MUST NOT be presented as `subject_token`,
  `actor_token`, or `client_assertion`; {{exchange}} uses the
  IdP-issued access token.
* Renewal or reissuance of an input credential does not rebind an
  existing access token to a different DPoP key. A changed key
  requires new issuance.

### Client Attestation {#agent-evidence}

The client MUST use `attest_jwt_client_auth_dpop` under {{ATTEST}}.
The Client Attestation MUST include nonempty strings for `iss` and
`sub=client_id`, and `iat` as a NumericDate. It MUST use an approved
asymmetric algorithm with a `kid`
resolvable through trusted attester configuration. Implementations
MUST support `ES256`. Its lifetime MUST NOT exceed 300 seconds.
The IdP MUST reject missing or incorrectly typed required claims or
`iat` not preceding `exp` using `invalid_client_attestation`, and
MUST reject an attestation whose lifetime exceeds this limit as not
fresh enough using `use_fresh_attestation`, both under {{ATTEST}}.

When the client represents the agent, the attestation MUST omit
`agent_id`. A shared client MUST include `agent_id`, a nonempty
StringOrURI {{RFC7519}} naming the agent in the attester's namespace.
The attester MUST verify authorized execution of that agent and
possession of the key in `cnf.jwk`. The IdP MUST validate the
attestation and combined-mode proof under ATTEST, including the
match between the DPoP key and `cnf.jwk`, before resolving the binding.

### SPIFFE X.509-SVID {#spiffe-input}

The client MUST authenticate using `spiffe_x509` under
{{SPIFFE-OAUTH, Section 3.2}}, with `client_id` equal to the exact
SPIFFE ID in the certificate's URI SAN. The IdP MUST validate the
SVID and trust bundle under that specification and resolve the
approved trust-domain and identity binding in {{identity}}. This
input represents the agent as client.

A separate DPoP proof establishes the token-binding key. This key
MAY differ from the SVID's TLS key. Both proofs MUST be validated
in the same authenticated token request. At exchange, a renewed SVID
MAY authenticate the same SPIFFE ID under the same approved binding;
the DPoP key MUST still match the access token.

WIT-SVID uses the separate binding in {{wit-input}}; JWT-SVID is
outside this profile.

### SPIFFE WIT-SVID {#wit-input}

The client MUST authenticate using `spiffe_wit` under
{{SPIFFE-OAUTH, Section 3.3}}. It MUST send the WIT-SVID directly in
`OAuth-Client-Attestation` and a fresh Client Attestation PoP JWT in
`OAuth-Client-Attestation-PoP`, with `client_id` equal to the exact
SPIFFE ID in the WIT's `sub`. This input represents the agent as
client. The requirements specific to {{agent-evidence}} do not apply
to this input.

The IdP MUST validate the WIT under {{WIT}}, including `typ=wit+jwt`,
expiration, signature, and the public key and proof algorithm in
`cnf.jwk`. It MUST use trust anchors configured for the trust domain
in `sub` and resolve the exact binding in {{identity}}. The optional
`iss` claim MUST NOT select trust anchors or replace that lookup;
its absence alone MUST NOT cause rejection.

The IdP MUST validate the Client Attestation PoP JWT under {{ATTEST}},
including the IdP issuer as audience, freshness, and any required
challenge. The request MUST also include the DPoP proof required by
{{inputs}}. Both proofs MUST use the WIT's `cnf.jwk` key and its
`alg` value. The IdP MUST compare keys using their {{RFC7638}}
thumbprints and reject a mismatch. Implementations MUST support
`ES256`. The separate proofs authenticate the client and establish
the token binding respectively; DPoP alone MUST NOT replace the
Client Attestation PoP JWT in this input. Validation errors use
the applicable ATTEST or DPoP errors.

A renewed WIT-SVID MAY authenticate an exchange using an existing
eligible token only if its identity binding and proof key remain the
same. Changing the WIT key requires a new IdP access token. Because
{{WIT}} recommends a fresh key for each WIT, reuse across renewal is
expected only where a deployment retains the key. The issuance
lifetime limit in {{idp-access-token}} applies to the access token,
not to the WIT's original lifetime.

## Optional Instance Identification {#instance-identification}

An ATTEST deployment MAY configure {{INSTANCE}} when it needs
installation or execution correlation. If configured, the IdP MUST
validate that profile, its lifecycle granularity, and any applicable
instance status before accepting the request. If instance context
is carried in the IdP access token, subsequent exchange MUST validate
matching context from current evidence. Missing required or conflicting
context MUST cause rejection. Without this extension, no stable
instance identifier is required and unvalidated instance claims
MUST NOT be copied into issued tokens.

# Obtaining an IdP Access Token {#bootstrap}

An unexpired access token that this IdP issued under this section to
the same client, Registered Agent, input method, and DPoP key MAY be
reused for exchange. No other access token is eligible; a matching
audience or a caller-supplied claim does not make one eligible. The
IdP MUST NOT require reacquisition of a token that remains
eligible.

Otherwise the client obtains a token using the request below. This
step establishes a portable IdP principal for use as the WAG exchange
subject or ID-JAG actor evidence. It does not replace authentication
or current authorization checks on subsequent requests.

Example decoded Client Attestation payload for an agent with its
own client identity. The IdP maps this client to `agent-42`; the
subsequent requests and grants use that binding.

~~~ json
{
  "iss": "https://attester.example/tenant/acme",
  "sub": "https://platform.example/agents/support-agent-7",
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
equal to the IdP issuer identifier and authentication under {{inputs}}.
The example uses ATTEST without optional instance identification.

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

The IdP MUST validate the configured input and DPoP proof, resolve
the Federation Binding, and verify that the Registered Agent is
active and permitted to use this client and exchange service.

The issued access token MUST conform to {{RFC9068}} and contain:

| Claim | Required value |
|---|---|
| `iss` | IdP issuer identifier |
| `sub` | Resolved Registered Agent identifier |
| `client_id` | Authenticated logical client identifier |
| `aud` | IdP issuer identifier, identifying the exchange service |
| `sub_profile` | `ai_agent` under {{ENTITY-PROFILES}} |
| `cnf.jkt` | SHA-256 JWK thumbprint of the proven DPoP key under {{RFC7638}} |

An eligible token MUST NOT contain `act`; a token that already
carries an actor would add a second actor hop at exchange. A token
issued by this acquisition MUST have a lifetime of at most 300
seconds, not exceeding the remaining validity of the authenticating
attestation or SVID. The short lifetime keeps the token a transient
exchange input rather than a standing credential, so no refresh token
is issued and a revoked binding takes effect at the next acquisition.
The IdP MUST associate it with the Federation Binding, input method,
source tenant, and exchange authorization through trusted issuance
policy or token state. Validated `client_instance` MAY be included
under {{instance-identification}}.

The response follows {{RFC6749}} with `token_type=DPoP` and
`expires_in`. Clients need not parse the access token. It MAY be
reused with fresh proofs until expiry; renewal or key rotation
requires new issuance. An instance identifier MUST NOT authorize
rebinding an existing token to a different key.

~~~ json
{
  "access_token": "eyJ...agent-access-token...",
  "token_type": "DPoP",
  "expires_in": 300
}
~~~

# Requesting an Authorization Grant {#exchange}

The client MUST use {{RFC8693}} at the IdP token endpoint with
the same logical client and configured authentication under {{inputs}}.
The fresh proof key MUST match the IdP-issued access token's
`cnf.jkt`. In both outputs:

* `grant_type` is `urn:ietf:params:oauth:grant-type:token-exchange`.
* `audience` MUST be exactly one target RAS issuer identifier.
* `resource` MUST be exactly one resource {{RFC8707}} at that RAS.
* `scope` MUST contain a nonempty set of requested resource scopes.

This profile does not support `authorization_details`; its presence
MUST cause `invalid_request`.

## Self-Acting Agent {#self-exchange}

`requested_token_type` MUST be `urn:ietf:params:oauth:token-type:wag`.
`subject_token` MUST be the IdP-issued access token, with
`subject_token_type=urn:ietf:params:oauth:token-type:access_token`.
Neither actor parameter is permitted. The issued WAG is specified in
{{wag-profile}} and its identifiers are registered in {{iana}}.

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

1. Validate the configured authentication input and DPoP proof and
   resolve the current Federation Binding under {{identity}}.
2. Validate the IdP-issued access token's signature, issuer,
   audience, lifetime, and eligibility under {{idp-access-token}}.
   Match its client, agent, source tenant, recorded external binding,
   input method, and key to the current request. Validate any instance
   context under {{instance-identification}}. Reject inconsistent inputs.
3. Check current agent status, credential-authority trust, external binding,
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

The IdP MUST issue a signed JWT under the selected output rules below,
with an approved asymmetric algorithm and a `kid`
resolvable through trusted issuer configuration. Implementations
MUST support `ES256` {{RFC7518}} in addition to requirements of
the underlying specifications.

The grant MUST contain the IdP's issuer in `iss`, the exact target
RAS issuer in `aud`, and the approved `resource` and `scope`.
`cnf.jkt` MUST equal the thumbprint of the validated DPoP key.
The grant lifetime MUST NOT exceed 300 seconds or the remaining
validity of the IdP-issued access token, accepted user credential,
or applicable delegation. The IdP MUST assign a unique `jti` and
MUST NOT reuse `(iss, jti)`.

For WAG, the claims and processing in {{wag-profile}} apply.

For ID-JAG, the JWT MUST conform to {{ID-JAG}}, with `sub` resolved
under its user subject-mapping rules. Actor Profile construction MUST
introduce exactly one actor, with `act.iss` equal to the IdP issuer,
`act.sub` equal to the agent identifier the IdP would place in a WAG
`sub` for that RAS, and `act.sub_profile=ai_agent`. The ID-JAG MUST
include the downstream `client_id` and other required ID-JAG claims,
including applicable tenant context. Translating a client identifier
MUST NOT rewrite the agent actor's namespace. ID-JAG's
issuer-identifier audience rule governs this output rather than Actor
Profile's generic token-endpoint audience rule.

The IdP MAY include `client_instance` for downstream audit or risk.
It MUST be omitted unless current instance evidence was validated
under {{instance-identification}}. If included, it MUST use an
unambiguous mapping, with `iss` equal to the IdP issuer and `id` an
IdP-assigned reference. It describes the subject's client instance
for WAG and the actor's client instance for ID-JAG, without changing either
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

### Workload Authorization Grant Issued by an IdP {#wag-profile}

WAG defines the grant concept, the Agent Identifier, a per-tenancy
issuer model, RFC 7523 redemption, and Agent Properties, and names
issuance by an enterprise IdP through token exchange as a composition
it leaves open. This section defines that composition. A WAG issued
under this document:

* is requested with
  `requested_token_type=urn:ietf:params:oauth:token-type:wag` and
  returned with that `issued_token_type` ({{iana}});
* carries the JOSE header `typ=oauth-wag+jwt`, which the RAS MUST
  validate under {{RFC8725}};
* has `iss` equal to the IdP's issuer identifier for the Source
  Tenant. The IdP takes WAG's per-tenancy issuer role: it MUST use a
  distinct issuer identifier per Source Tenant and publish its signing
  keys through issuer metadata. The RAS MUST resolve the signing key
  by `iss` through its issuer allowlist, not through a client
  registration, and MUST interpret `sub` and `jti` only within that
  `iss`, as WAG requires;
* has `sub` equal to the Registered Agent identifier bound to the
  IdP-issued access token, or the recipient-scoped identifier the IdP
  maintains for that agent at the target RAS under {{security}}. This
  value is WAG's Agent Identifier: opaque, unique within `iss`,
  immutable, and never reassigned. It MAY take the URI form WAG
  recommends, with an authority component under the IdP's tenant
  issuer; the RAS MUST treat it as an exact-match opaque string in
  either form;
* has `sub_profile=ai_agent` under {{ENTITY-PROFILES}};
* has `aud` equal to the RAS issuer identifier. WAG recommends
  carrying both the issuer identifier and the token endpoint URL;
  this document carries the issuer identifier alone, which every
  WAG-conformant RAS MUST accept, so WAG and ID-JAG share one
  audience rule;
* carries `scope` and `resource` with the approved values, using the
  claim definitions in {{ID-JAG}}; both are REQUIRED here;
* carries `cnf` with `jkt` ({{RFC7800}}) equal to the thumbprint of
  the proven DPoP key. This closes WAG's open proof-of-possession
  item for IdP-issued grants: the grant is not a bearer grant and
  MUST be redeemed with a DPoP proof under {{consumption}};
* MUST NOT contain `act`;
* MAY carry WAG's Agent Properties, `name`, `namespace`, `groups`,
  `roles`, and `ctx`, populated from the Registered Agent record and
  its group memberships at the IdP. `name` MUST NOT be used as a key
  for authorization or attribution. `groups` and `roles` describe the
  agent, never a user;
* carries `jti`, `iat`, and `exp` under {{grant}}.

Registration and provisioning at the RAS follow WAG: a RAS MUST NOT
require the agent to be projected into it before first issuance and
MUST accept a previously unseen `sub` under an allowlisted `iss`.
Authorization that depends on a provisioned agent record follows
{{agent-correlation}} and MAY be withheld until the record exists.

## Response and Errors

The response follows {{RFC8693}}. `issued_token_type` MUST equal
the requested output type, `token_type` MUST be `N_A`, and
`access_token` contains the grant. `expires_in` gives its remaining
lifetime and `scope` lists approved scopes. No refresh token is issued.

The client MUST verify the returned type and the grant's protected
JWT type, audience, resource, scope subset, and `cnf.jkt` for its
proven key. A mismatch MUST cause failure. These checks do not
replace cryptographic grant validation at the RAS.

Malformed requests and unsupported outputs or combinations use
`invalid_request`. Disallowed actor chains use `invalid_grant` under
Actor Profile. Invalid exchange credentials or
inconsistent bindings use `invalid_grant`; invalid targets and
scopes use `invalid_target` and `invalid_scope`. Missing or
prohibited delegation for a validated actor uses `actor_unauthorized`
under {{ACTOR-PROFILE}}. A client not permitted to use this profile
receives `unauthorized_client`. Input authentication and DPoP
freshness errors retain their base processing. A failed delegated
request MUST NOT produce a self-acting grant.

# Grant Consumption {#consumption}

Redemption uses the `urn:ietf:params:oauth:grant-type:jwt-bearer`
grant with the JWT in `assertion` under {{RFC7523}}, as both
{{ID-JAG}} and {{WAG}} require, accompanied by the DPoP proof
required below. The bound-grant checks below apply. Other processing
follows {{ID-JAG}} for delegated output and {{WAG}} as profiled in
{{wag-profile}} for self-acting output. Delegated
processing additionally follows Actor Profile, including preservation
of `act`. This document does not define a
separate redemption protocol, access-token format, or introspection
schema. Downstream access-token lifetimes and refresh behavior
follow the underlying grant and resource authorization policy.

For ID-JAG, the client MUST authenticate to the RAS using a credential
registered or otherwise trusted for the downstream `client_id` in
the grant. The RAS MUST enforce ID-JAG's client match independently
of the grant's DPoP binding. An IdP's client-ID mapping does not
provision that credential. DPoP possession alone MUST NOT be treated
as client authentication. The examples use `private_key_jwt` under
{{RFC7523}} and explain the separate credential in {{ras-auth}}.

For WAG, the redemption request MUST include `resource` equal to the
grant's `resource` claim; the RAS MUST reject a mismatch with
`invalid_target`. WAG leaves client identity unspecified. Under this
document the DPoP proof supplies the possession check, and the RAS
MAY additionally require client authentication by configuration. The
RAS MUST make any Agent Properties in the grant available to the
resource server's authorization decision and MUST NOT issue a refresh
token for a WAG, as WAG requires. A grant that fails validation,
including a missing or mismatched DPoP proof, is rejected with
`invalid_grant`; scopes beyond the grant use `invalid_scope`.

Every grant is bound to the proven DPoP key. The IdP MUST issue only
to a RAS configured to validate that binding. The client MUST
present a fresh DPoP proof at redemption. The RAS MUST validate it
under {{RFC9449}} and reject a missing or invalid proof or a key
that does not match `cnf.jkt`, using ID-JAG's bound-grant processing
for ID-JAG and the same checks for WAG. The RAS MUST issue a
sender-constrained access token, such as a DPoP-bound token under
{{RFC9449}}, when redeeming a grant issued under this profile, and
MUST NOT issue a bearer access token from it. That access token,
rather than an upstream credential or grant, is used at the resource
server.

## Agent Record Correlation {#agent-correlation}

The canonical Registered Agent identity is the exact pair of IdP
issuer and agent identifier. For a WAG issued here, the pair is
`(iss, sub)`; for delegated ID-JAG it is `(act.iss, act.sub)`. A RAS
using provisioned agent records MUST resolve both forms through
the same issuer-qualified mapping. It MUST NOT key that lookup on
bare `sub`, the OAuth client, or instance context. Missing or ambiguous
mappings MUST prevent authorization that depends on that record.

Provisioning protocols and policy rules remain deployment choices.
If SCIM `externalId` is used, the provisioning relationship MUST
associate it with the IdP issuer so another issuer's equal string
cannot resolve to the same agent accidentally. Group membership
resolved for this agent MUST NOT be attributed to an ID-JAG user,
or user membership to the agent. {{provisioning-example}} illustrates
this contract without defining new SCIM attributes.

# Metadata and Configuration {#metadata}

The IdP MUST advertise `client_credentials`, token exchange, and its
implemented input methods (`attest_jwt_client_auth_dpop`,
`spiffe_x509`, or `spiffe_wit`) through existing {{RFC8414}} and input-specification
metadata, and DPoP `ES256` support under {{RFC9449}}. Profile selection and
approved identity bindings use the configuration in {{identity}}.
Delegated implementations use Actor Profile's existing metadata for
ID Token subject input, JWT access-token actor input, and supported
entity profiles, including `ai_agent`. The IdP advertises its
supported outputs, `urn:ietf:params:oauth:token-type:id-jag` and
`urn:ietf:params:oauth:token-type:wag`, through
`identity_chaining_requested_token_types_supported`, referenced by
{{ID-JAG}} and defined in {{IDENTITY-CHAINING}}.

RAS capabilities are advertised under the selected grant and, where
applicable, Actor Profile. A RAS advertises
`urn:ietf:params:oauth:grant-type:jwt-bearer` in
`grant_types_supported` under {{RFC8414}}, as ID-JAG and WAG require,
and its DPoP support under {{RFC9449}}. The IdP MUST verify the
configured RAS supports the required grant, binding, and actor
processing before issuance. No new grant-profile identifier, metadata
parameter, bootstrap scope, or token marker is defined here. Metadata
discovery does not establish issuer trust or delegation authority.

# Security and Privacy Considerations {#security}

The security requirements of the selected input, {{RFC8693}},
{{RFC8725}}, and selected output apply; {{INSTANCE}} additionally
applies when configured. The IdP MUST bind client, agent, tenant,
and key, plus any validated instance context, to one authorized
request. Independently valid evidence for different agents or
identified instances MUST NOT be combined. A stable instance identifier does
not authorize key rebinding or establish a delegation relationship.

The IdP MUST check current status and authorization on each issuance,
including credential-authority trust, agent bindings, assignments,
and delegation.
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

The agent binding established here ends where the grant is consumed.
A bearer access token minted from a bound grant would let any holder
act as the attested agent, so {{consumption}} requires
sender-constrained downstream tokens. Sender constraint does not
replace the RAS's own authorization checks.

In the shared-client model one attester asserts `agent_id` for every
agent behind the client, and nothing in the client's own credentials
limits which `agent_id` values it can name. A compromised or
mistakenly trusted attester can therefore obtain grants for any agent
under that client, across every tenant it serves. Deployments SHOULD
use a distinct `client_id` per tenant or governance boundary, SHOULD
limit each attester's approved bindings to the agents it governs, and
MUST enforce withdrawal of attester trust on subsequent
authentication. The attester `iss` SHOULD be retained with each
issuance for audit.

Stable agent and instance identifiers can permit correlation.
The IdP SHOULD release only necessary context and retain internal
mappings for recipient-scoped instance references. Raw attestation
material and private keys MUST NOT appear in grants or audit logs.

The Registered Agent identifier is stable across every RAS. Where an
agent serves one user, such as a per-user desktop agent, `act.sub` or
the WAG `sub` becomes a cross-service identifier for that user even
where ID-JAG subject mapping is pairwise. The IdP SHOULD NOT let
per-user agent identifiers act as a cross-context user pseudonym
without a correlation requirement at the receiving RASes. It MAY
maintain a recipient-scoped Registered Agent identifier per RAS and
substitute it at grant construction under {{grant}}, provided the
identifier is stable for that RAS and identical across the WAG `sub`
and ID-JAG `act.sub` it receives, so that {{agent-correlation}} still
resolves one record. The IdP-issued access token always carries the
canonical identifier.

# IANA Considerations {#iana}

## JWT Claims Registration

This specification requests registration of `agent_id` in the
JWT Claims registry established by {{RFC7519}}, with description
"Attester-scoped agent principal identifier", reference
{{agent-evidence}}, and Change Controller IETF. Its value is a
nonempty StringOrURI. This profile uses it only for agents represented
by a shared client.

## Media Type Registration

This section registers `oauth-wag+jwt`, a new media type {{RFC2046}},
in the "Media Types" registry in the manner described in {{RFC6838}}.
It indicates that the content is a Workload Authorization Grant
issued under {{wag-profile}}.

## OAuth URI Registration

This section registers `urn:ietf:params:oauth:token-type:wag` in the
"OAuth URI" subregistry of the "OAuth Parameters" registry.

* URN: urn:ietf:params:oauth:token-type:wag
* Common Name: Token type URI for a Workload Authorization Grant
* Change Controller: IETF
* Specification Document: This document

## Other Identifiers

`client_instance` is defined by {{INSTANCE}}; `act` follows
{{ACTOR-PROFILE}}; `ai_agent` is defined by {{ENTITY-PROFILES}}.
No new actor format, access-token type, or grant-profile URI is
registered.

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

Native SPIFFE X.509-SVID and WIT-SVID authentication follow
{{spiffe-input}} and {{wit-input}}, respectively.
Other credential types need explicit binding and proof rules; support
for SPIFFE does not imply that every SVID type is accepted.
Direct WIT actor evidence under Actor Profile is a different input
path. It would need explicit external-subject mapping and proof
rules; it does not implicitly substitute for the IdP access token here.

# End-to-End Deployment Examples {#flows}
{:numbered="false"}

This appendix is informative. A harness is the software executing
the agent and making OAuth requests. These examples separate its
hosting environment, authentication evidence, and acting relationship:

| Use case | Deployment | Evidence accepted by IdP | Identity model | Grant |
|---|---|---|---|---|
| Agent acting for itself | SPIFFE workload | X.509-SVID or WIT-SVID with their required proofs | Agent is the client | WAG |
| Agent acting for itself | Managed platform | Platform Client Attestation and DPoP | Agents share a client | WAG |
| Agent acting for a user | Managed device | Enterprise Client Attestation and DPoP | Agent is the client | ID-JAG |
| Agent acting for a user | Managed platform | Platform Client Attestation and DPoP | Agents share a client | ID-JAG |

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
issues DPoP access tokens bound to that key, satisfying the
sender-constraint requirement in {{consumption}}.

## Agent Acting for Itself {#self-flow}
{:numbered="false"}

The agent is the WAG subject; the flow ends with a
sender-constrained access token for the agent alone.

### SPIFFE Workload with X.509-SVID {#spiffe-flow}
{:numbered="false"}

Use this model when the workload already has a SPIFFE identity
representing the agent. This example uses X.509-SVID client
authentication under {{spiffe-input}}, without a Client Attestation
or stable instance identifier. The WAG is specified in {{wag-profile}}.

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
3. Under {{idp-access-token}}, the IdP issues an access token with `sub=agent-42`, the SPIFFE ID as `client_id`, its own
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

The exchange request appears in {{self-exchange}} and the resulting
WAG payload in {{grant}}. The harness redeems it at the RAS:

~~~ http
POST /token HTTP/1.1
Host: as.app.example
Content-Type: application/x-www-form-urlencoded
DPoP: eyJ...grant-key-proof...

grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
&assertion=eyJ...idp-wag...
&resource=https%3A%2F%2Fapi.app.example
~~~

~~~ json
{
  "access_token": "eyJ...app-access-token...",
  "token_type": "DPoP",
  "expires_in": 600,
  "scope": "tickets.read"
}
~~~

The RAS validates `typ`, resolves the IdP's key by `iss` through its
allowlist, checks `aud`, lifetime, and `jti`, matches `resource` to
the grant, and compares the DPoP proof key to `cnf.jkt` under
{{consumption}}. It accepts `agent-42` even if it has not seen that
subject before, applies any Agent Properties and its provisioned
record under {{agent-correlation}}, and issues a DPoP-bound access
token with no refresh token. No client authentication is required
for this redemption.

A SPIFFE workload can have several instances {{SPIFFE-CONCEPTS}}.
This flow correlates key possession through `cnf.jkt`; it does not
claim a stable runtime identity. A renewed SVID can be used with an
existing eligible token when the approved SPIFFE binding and DPoP
key remain the same. An unrelated identity or replacement DPoP key
cannot use that token.

### WIT-SVID Variant
{:numbered="false"}

With {{wit-input}} configured, the harness instead obtains a WIT-SVID
for the same SPIFFE ID, binding key `K`. The following decoded payload
omits the optional `iss`; the IdP uses the configured trust anchors
for `workloads.example`. Its protected header uses `typ=wit+jwt`,
`alg=ES256`, and a `kid` selecting a key in that trusted bundle.

~~~ json
{
  "sub": "spiffe://workloads.example/agents/support",
  "iat": 1789128000,
  "exp": 1789131600,
  "cnf": {
    "jwk": {
      "kty": "EC",
      "crv": "P-256",
      "alg": "ES256",
      "x": "VcKVNBZ4IaBAYW3jxM4w3TJFVA7myeUGQyGt-g_yvpQ",
      "y": "f-E-hYE3TAWKwhVv9pej9NABs9SX9XsNO80x57jFTyU"
    }
  }
}
~~~

The harness sends this request over server-authenticated TLS. The
Client Attestation PoP JWT has `aud=https://idp.example/tenant/acme`,
a fresh `iat` and unique `jti`, and the IdP's challenge if supplied.
It uses `typ=oauth-client-attestation-pop+jwt`. Both that proof and
the DPoP proof are signed with `K` using `ES256`.

~~~ http
POST /token HTTP/1.1
Host: idp.example
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: eyJ...wit-svid...
OAuth-Client-Attestation-PoP: eyJ...attestation-pop...
DPoP: eyJ...proof-K...

grant_type=client_credentials
&client_id=spiffe%3A%2F%2Fworkloads.example%2Fagents%2Fsupport
&resource=https%3A%2F%2Fidp.example%2Ftenant%2Facme
~~~

The IdP resolves the same `agent-42` and issues a DPoP access token
with at most 300 seconds of validity and `cnf.jkt=JKT(K)`. The extra
JWK `alg` member does not change the RFC 7638 thumbprint. Steps 4
and 5 above then apply, with WIT-SVID and fresh attestation and
DPoP proofs authenticating the exchange. For user-delegated access,
the same IdP token is actor evidence under {{delegated-exchange}};
the WIT itself remains client authentication evidence at the IdP.

### Shared Client in a Managed Platform {#platform-flow}
{:numbered="false"}

Use this model when a hosting platform runs separately governed
agents through one OAuth client. The IdP approves the platform
attester `https://attester.example/tenant/acme` for shared client
`https://platform.example/oauth-client`, mapping its
`agent_id=support-agent-7` to Registered Agent `agent-42`.

The message sequence matches the SPIFFE example above, with the
platform attester supplying the Client Attestation in place of the
Workload API.

1. The control plane launches `support-agent-7`. Its harness generates
   `K`. The attester verifies the launch assignment, runtime
   isolation, and key possession, then issues an attestation with
   `sub` equal to the shared client, `agent_id=support-agent-7`,
   `client_instance_id=run-p42`, and `cnf.jwk` containing the public
   key. This deployment opts into execution-level instance tracking.
   The harness cannot select another agent merely by naming it.
2. The harness follows {{bootstrap}}, sending the shared `client_id`.
   The IdP resolves `(iss, sub, agent_id)` and returns an access token
   with `sub=agent-42`, the shared `client_id`, validated instance
   context, and `cnf.jkt=JKT(K)`.
3. For unattended ticket processing, the harness follows
   {{self-exchange}}. The IdP authorizes access using `agent-42`'s
   assignments and issues WAG with `sub=agent-42`, no `act`, and the
   same key binding. The harness redeems it and calls the API as
   described in {{app-consumption}}.

A second runtime for this agent gets a different instance identifier
and key, but the same `agent-42` principal. A different agent behind
the shared client has its own binding and permissions. The IdP
does not infer equivalent authority from the common client identity.

## Agent Acting on Behalf of a User {#delegated-flow}
{:numbered="false"}

The user is the ID-JAG subject and the Registered Agent its actor;
the flow ends with a sender-constrained access token that carries
both.

### Harness on a Managed Device {#device-flow}
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
    |                 |--- sign-in -->|           |        |       |
    |                 |               |- sign-in >|        |       |
    |                 |               |<- code ---|        |       |
    |                 |<--- code -----|           |        |       |
    |< evidence, JWK -|               |           |        |       |
    |-- attestation ->|               |           |        |       |
    |                 |------- code + PKCE ------>|        |       |
    |                 |<------- ID Token ---------|        |       |
    |                 |-- credentials + ATTEST -->|        |       |
    |                 |<-------- IdP AT ----------|        |       |
    |                 |-- user + actor exchange ->|        |       |
    |                 |<-------- ID-JAG ----------|        |       |
    |                 |---------- ID-JAG + DPoP ---------->|       |
    |                 |<------------- app AT --------------|       |
    |                 |-------------- app AT + DPoP -------------->|
    |                 |<---------------- tickets ------------------|
~~~

1. The harness generates `K` and starts sign-in in an external
   browser using an authorization code flow with PKCE under
   {{RFC8252}}. The enterprise records user or administrator approval
   for this agent to read tickets for that user. Sign-in alone is
   not delegation approval.
2. After the browser returns the code, the enterprise attester
   validates device evidence, harness and agent assignment, and key
   possession. This deployment opts into installation-level instance
   identification: the Client Attestation has the agent's client
   identifier as `sub`, `client_instance_id=install-d17`, and
   `cnf.jwk` containing `K`'s public key, without `agent_id`. The
   harness redeems the code with PKCE and fresh ATTEST authentication
   to obtain its user ID Token. Device evidence and issuance APIs
   remain deployment-specific under {{ATTEST}}.
3. The harness then obtains its IdP access token under {{bootstrap}},
   identifying `agent-17`, the client, optional installation context,
   and `JKT(K)`, or reuses an eligible token. Acquisition follows the
   interactive wait so the short token lifetime is available for
   exchange. If credentials expire before exchange, the harness
   renews the required evidence and token; it does not bypass checks.
4. The harness follows {{delegated-exchange}}, sending the user
   ID Token as `subject_token` and the IdP access token as
   `actor_token`, with fresh ATTEST authentication. The IdP validates
   both identities and the delegation, then issues ID-JAG with
   `sub=user-17`, `act={iss: IdP, sub: agent-17, sub_profile: ai_agent}`,
   and the downstream client identifier `dev-agent-at-app`.
5. The harness redeems ID-JAG and accesses the API as described in
   {{app-consumption}}, authenticating as `dev-agent-at-app` with
   the separate RAS credential described in {{ras-auth}}. The device
   attester and device record do not become actors.

The redemption request appears in {{ras-auth}} and the response has
the shape shown above, with `sub=user-17` and `act.sub=agent-17` in
the resulting access token.

If the enterprise only needs existing client-based delegation, the
harness can use the ID-JAG/EMA path in {{deployment}} without the
agent bootstrap and actor token. A desktop harness shared by several
separately governed agents instead uses the shared-client binding
illustrated in {{platform-flow}}. Device hosting does not select
the identity model automatically.

### Shared Client Variant
{:numbered="false"}

For user-delegated work in the shared-client platform deployment of
{{platform-flow}}, the harness follows {{delegated-exchange}} with an
accepted user credential and the agent access token. After checking
delegation approval, the IdP issues ID-JAG with the user as `sub` and
`agent-42` as `act`. Its downstream `client_id` is `platform-at-app`;
redemption uses the platform signing service in {{ras-auth}}. The
hosting platform is client context, not an additional actor.

## Client Authentication at the RAS {#ras-auth}
{:numbered="false"}

These examples separate the DPoP key `K` from a registered client
signing key `C`. Before delegated access, the RAS has registered
`C`'s public key for the following client; the IdP knows the client-ID
mapping. This is client credential provisioning, independent of the
agent record and of trust in the IdP as grant issuer.

| Deployment | Downstream client | Custody of client signing key C |
|---|---|---|
| Managed device | `dev-agent-at-app` | Protected storage for this managed installation; its public key is enrolled at the RAS |
| Managed platform | `platform-at-app` | Platform signing service; an authorized harness obtains a short-lived assertion without receiving the private key |

At redemption, the harness supplies a fresh `private_key_jwt`
assertion signed with `C`. Its `iss` and `sub` equal the downstream
client identifier, its `aud` is the RAS issuer, and it has a short
expiration and unique `jti`, validated under {{RFC7523}}. A separate
DPoP proof from `K` proves possession of the grant's binding key.
Neither credential substitutes for the other. The self-acting WAG
example redeems the bound grant with a DPoP proof and no client
authentication, as {{consumption}} permits for WAG.

Illustrative desktop redemption; the client assertion and ID-JAG
are different JWTs with different purposes and signing authorities:

~~~ http
POST /token HTTP/1.1
Host: as.app.example
Content-Type: application/x-www-form-urlencoded
DPoP: eyJ...grant-key-proof...

grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
&assertion=eyJ...idp-id-jag...
&client_id=dev-agent-at-app
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJ...client-key-assertion...
~~~

The RAS uses its client registration to validate the client assertion
and its IdP trust to validate ID-JAG. It does not need to accept the
enterprise or platform attester as an agent-identity authority.
If a deployment instead authenticates the client with ATTEST at the
RAS, it needs a separate, explicit RAS attester trust configuration;
trust in the IdP's grant does not create that relationship.

## Downstream Application Processing {#app-consumption}
{:numbered="false"}

Both use cases finish at the same application trust boundary:

1. The harness presents the IdP-issued grant to the RAS using the
   selected grant's redemption procedure and the client authentication
   in {{ras-auth}}, including ID-JAG's downstream client binding.
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

## One Agent Record for Self-Acting and Delegated Access {#provisioning-example}
{:numbered="false"}

The RAS has an authenticated SCIM provisioning relationship with
IdP issuer `https://idp.example/tenant/acme`. The IdP provisions the
following Agent resource using {{SCIM-AGENT}}. The RAS assigns `id`;
the IdP supplies `externalId`. The issuer association is kept with
the provisioning relationship, not encoded in a new SCIM attribute.

~~~ json
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:Agent"],
  "id": "ra-42",
  "externalId": "agent-42",
  "agentUserName": "support-agent",
  "displayName": "Support Agent",
  "active": true
}
~~~

The application's directory records `ra-42` as a member of group
`support-eng`; its local policy grants that group `tickets.read`.
This is a provisioned group relationship, not a claim inferred from
the agent name or a new group schema. Both grant paths resolve the
same record under {{agent-correlation}}:

| Validated grant | Agent lookup | Record and policy input |
|---|---|---|
| WAG: `iss=https://idp.example/tenant/acme`, `sub=agent-42` | `(iss, sub)` | `ra-42`, member of `support-eng` |
| ID-JAG: `sub=user-17`, `act.iss=https://idp.example/tenant/acme`, `act.sub=agent-42` | `(act.iss, act.sub)` | The same `ra-42` and membership |

For delegated access, the application also evaluates `user-17`'s
permissions and the authorized delegation. The agent's group does
not add that user to the group. An equal `agent-42` from another
issuer does not match this record. Setting `active=false` blocks new
issuance once applied by the relevant server; already-issued tokens
follow the deployment's expiration and revocation behavior.

# Interoperability Test Cases
{:numbered="false"}

This appendix is informative; the normative requirements are in the
body. Independent platform, client, IdP, and RAS implementations can
exercise:

| Case | Expected result |
|---|---|
| ATTEST agent as client; approved binding and key proof, instance extension disabled | IdP access token without stable instance context |
| ATTEST shared client; approved `(iss, sub, agent_id)` binding and key proof | IdP access token for the Registered Agent |
| Shared client omits `agent_id` | Reject; no fallback to client-only binding |
| Agent with its own client identity supplies `agent_id` | Reject; no switch to the shared-client model |
| Missing, ambiguous, or disabled binding | Reject issuance |
| X.509-SVID client with approved exact ID and DPoP proof | IdP access token without stable instance context |
| WIT-SVID with approved exact ID, attestation PoP, and matching DPoP key; no `iss` | IdP access token for the configured agent; no stable instance context |
| WIT-SVID with missing attestation PoP, mismatched key or proof algorithm, or expired credential | Reject authentication or proof |
| WIT-SVID with unapproved trust domain or mismatched `client_id` | Reject; `iss` cannot select another trust anchor |
| Renewed X.509-SVID, same binding and DPoP key | Existing eligible token remains usable |
| Renewed WIT-SVID, same binding and unchanged `cnf.jwk` | Existing eligible token remains usable |
| Renewed WIT-SVID with a new `cnf.jwk` | Reject exchange with the old token; new IdP access token required |
| Unexpired token from this document's acquisition; same client, agent, input method, and key | Reused without reacquisition |
| Access token from any other issuance, even with a matching audience | Not eligible; acquisition required |
| Same agent in a second execution | Same agent subject; distinct context if execution tracking is configured |
| Unrelated client, agent, instance, or key at exchange | Reject inconsistent evidence |
| Agent acting for itself | WAG subject is the agent; no `act` |
| Agent acting for a user | User subject; Registered Agent `act` |
| Valid user and agent credentials without delegation | `actor_unauthorized` |
| Unsupported requested output | `invalid_request`; no fallback |
| Optional downstream instance context | Same principal and binding semantics |
| Configured instance extension, missing or mismatched evidence | Reject; no fallback to key-only processing |
| Grant redemption with missing or mismatched proof | Reject under the bound-grant rules |
| WAG redemption without `resource`, or with `resource` not matching the grant | `invalid_target` |
| WAG with a previously unseen `sub` under an allowlisted `iss` | Access token issued; record-dependent authorization withheld until correlated |
| ID-JAG redemption with DPoP but no required client authentication | Reject; DPoP is not the registered client credential |
| WAG subject and ID-JAG actor name the same IdP agent | Resolve the same provisioned record |
| Same bare agent identifier from another issuer | No match to the original issuer's record |

Only cases for the implemented input and output are applicable.
Existing client-based deployments are compatibility context, not an additional
conformance path for this specification.

# Coordination with Related Work {#coordination}
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

WAG-00 names IdP issuance through token exchange as an open
composition and leaves proof of possession, JWT type, token type,
error responses, Agent Properties, and IANA actions undefined, while
requiring jwt-bearer redemption with `resource`. {{wag-profile}} and
{{consumption}} fill those gaps for IdP-issued grants, and {{iana}}
registers the token type and media type because WAG registers
nothing. Items that need WAG's agreement: whether WAG references
these registrations or registers equivalents that this document then
adopts; `aud` carrying the issuer identifier alone; `cnf.jkt` as the
proof-of-possession answer for IdP-issued grants; the Agent
Properties claim names once WAG's Section 8 settles; and WAG's
Informational status against this document's normative reference.
Advertising WAG output through
`identity_chaining_requested_token_types_supported` also needs
confirmation with identity chaining.

Actor Profile's generic JWT-grant audience guidance uses a token
endpoint, while ID-JAG uses the RAS issuer. This document selects
ID-JAG's audience and needs grant-profile precedence clarified in
Actor Profile. ID-JAG and WAG both redeem with
`urn:ietf:params:oauth:grant-type:jwt-bearer`, while ID-JAG's
bound-grant example and {{JWT-DPOP}} use
`urn:ietf:params:oauth:grant-type:jwt-dpop` for DPoP-bound JWTs. This
document follows the normative text of ID-JAG and WAG, sending a DPoP
proof with the jwt-bearer grant, and will follow ID-JAG if it adopts
the jwt-dpop grant type. This document does not register a competing
redemption mechanism.

SPIFFE OAuth's WIT-SVID binding and its authentication-method metadata
need alignment with the evolving ATTEST proof modes. This document
selects `spiffe_wit` with the separate Client Attestation PoP JWT
specified by SPIFFE OAuth, plus DPoP bound to the same key. It does
not infer combined-mode support from that method name. General WIT
inputs, including direct Actor Profile input, need separate agreement
on identity mapping and trust-domain validation when `iss` is absent.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Intended, with draft-mcguinness-oauth-client-instance-identification,
  to replace draft-mcguinness-oauth-ai-agent-instance.
* Focused the standards-track profile on platform-to-IdP agent
  identity binding, access-token acquisition, and grant issuance.
* Defined ATTEST and SPIFFE X.509-SVID inputs, optional instance
  identification, eligible-token reuse, and Actor Profile delegation.
* Added WIT-SVID authentication with trust-domain identity resolution,
  attestation proof, DPoP key binding, and credential renewal rules.
* Used `client_id` as agent identity when the agent is the client;
  required `agent_id` only for agents represented by a shared client.
* Completed deployment examples with downstream client authentication,
  credential timing, and issuer-qualified provisioning correlation.
* Defined IdP issuance of WAG: token type, JWT type, issuer model,
  audience, key binding, claims, Agent Properties, redemption, and
  errors; registered the token type and media type.
* Moved existing client flows and deployment choices to informative
  guidance and inherited downstream grant processing.
* Consolidated cross-input rules into one contract in the inputs
  section and recorded the input method with issued tokens.
* Limited access-token reuse to tokens issued under this document's
  acquisition, selected `use_fresh_attestation` for over-long
  attestations, and split the SVID renewal interoperability case.
* Required sender-constrained downstream access tokens, kept
  jwt-bearer redemption with a DPoP proof, and added shared-client
  and agent-identifier privacy considerations.
* Cited identity-chaining metadata for ID-JAG and WAG output.
* Led the Introduction with the three identity dimensions and both
  acting relationships, and stated why the IdP-issued access token
  exists.
* Defined Source Tenant, Target Tenant, and Agent Status;
  consolidated evidence-combination rules; explained the shared-client
  model against CIMD per-agent identifiers.
* Reorganized the end-to-end examples around the agent acting for
  itself and on behalf of a user, adding WAG redemption at the RAS.
