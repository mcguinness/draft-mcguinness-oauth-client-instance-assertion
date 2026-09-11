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
  RFC7521:
  RFC7523:
  RFC7662:
  RFC8414:
  RFC8693:
  RFC8707:
  RFC8725:
  RFC9449:
  CIA: I-D.mcguinness-oauth-client-instance-assertion
  ACTOR-PROFILE: I-D.mcguinness-oauth-actor-profile
  AGENT: I-D.mcguinness-oauth-ai-agent-instance
  WAG: I-D.carleton-workload-authz-grant

informative:
  ID-JAG: I-D.ietf-oauth-identity-assertion-authz-grant
  SCIM-AGENT: I-D.wzdk-scim-agent-resource

--- abstract

This specification defines a profile of OAuth 2.0 Token Exchange
and the JWT Profile for OAuth 2.0 Authorization Grants that enables
an agent instance to obtain access to protected resources using an
identity provider as a Workload Authorization Grant issuer. The
identity provider authenticates the instance, resolves its identity
to a registered agent, and issues a grant for a Resource
Authorization Server. The profile specifies the assertion input,
grant contents, token endpoint processing, authorization server
metadata, and proof-of-possession requirements for an agent acting
on its own behalf.

--- middle

# Introduction

An agent platform can operate multiple instances of an agent, each
with its own runtime identity and key. An identity provider (IdP)
can maintain registered identities for agents from several platforms
and authorize their access to applications. A Resource
Authorization Server that trusts the IdP can issue access tokens
for those agents without establishing a separate trust relationship
with each platform.

This specification profiles OAuth 2.0 Token Exchange {{RFC8693}} to
exchange a Client Instance Assertion {{CIA}} for a Workload
Authorization Grant (WAG) {{WAG}}. The assertion carries the agent
identity claims defined by {{AGENT}}. The client presents the WAG
at a Resource Authorization Server using the JWT authorization
grant defined by {{RFC7523}}. Both requests use Demonstrating Proof
of Possession (DPoP) {{RFC9449}} with the instance's key.

The IdP MUST implement {{CIA}}, including its requirement to
implement {{ACTOR-PROFILE}}. This document uses CIA's
grant-issuance extension; the resulting WAG follows {{grant}}.
Actor Profile support does not require an `act` claim when no
delegated actor is represented. The RAS and RS use Actor Profile's
subject-classification rules as specified in {{resource-token}};
accepting a WAG does not require them to implement CIA assertion
processing or its client-registration requirements.

The IdP determines whether the agent is authorized to obtain a
grant for the requested resource and scope. The Resource
Authorization Server independently determines whether to accept
the grant and which permissions to include in an access token.
The registered agent is the subject of the grant and access token;
the runtime instance is identified separately. An instance can
perform multiple jobs or tasks without changing either identity.
This specification does not define task identifiers, task context,
or task-specific authorization and lifecycle rules; those can be
specified by a separate profile.

This profile applies to agents acting on their own behalf.
Authorization on behalf of an end-user, including the identity
assertion exchange defined by {{ID-JAG}}, is outside its scope.
Agent provisioning protocols and the means by which a platform
initially authenticates an instance are also outside its scope.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

OAuth terms are used as defined in {{RFC6749}}, {{RFC7521}}, and
{{RFC8693}}. JWT terms are used as defined in {{RFC7519}}. Agent
Principal, Agent Instance, Agent Platform, and Agent Attester are
used as defined in {{AGENT}}.

## Roles

Client:
: The agent instance making token requests and accessing protected
  resources. At the IdP, the instance is bound to an OAuth client
  registration as specified by {{CIA}}. This profile does not
  require a client registration at the Resource Authorization Server.

IdP Authorization Server (IdP):
: The authorization server that validates instance assertions,
  maintains registered agent identities and their authorization
  policy, and issues WAGs.

Resource Authorization Server (RAS):
: The authorization server that accepts WAGs from a trusted IdP
  and issues access tokens for its protected resources.

Resource Server (RS):
: The server hosting protected resources. It accepts access tokens
  issued by the RAS; it does not process the WAG.

## Terms

Registered Agent:
: An Agent Principal represented in the IdP's agent registry. A
  registered agent can have multiple concurrent or successive
  instances.

Federation Binding:
: An IdP-configured association between an assertion issuer,
  client identifier, and platform agent identifier and a
  registered agent, as specified in {{registry}}.

Subject Resolution:
: The process of mapping an authenticated, issuer-qualified
  identifier to a principal in the receiving authorization
  server's namespace.

# Workload Authorization Grant {#grant}

A WAG issued under this profile represents authorization for a
registered agent to request an access token at a particular RAS.
It uses the JWT authorization grant format and presentation
specified by {{WAG}} and {{RFC7523}}, with the constraints in this
section. The IdP issues the grant following the token exchange in
{{issuance}}.

The grant MUST be a signed JWT using JWS Compact Serialization
{{RFC7515}} and a key published for the IdP's issuer identifier.
The protected `typ` header parameter MUST be
`oauth-wag+jwt`. The signature algorithm MUST be asymmetric and
permitted by the issuer's trust configuration. Implementations
MUST support `ES256` {{RFC7518}}. They MUST NOT issue or accept a
grant using `none` or a symmetric MAC algorithm.

## Claims

The following claims are REQUIRED:

`iss`:
: The IdP's issuer identifier, as defined in {{RFC8414}}. The value
  identifies a single tenancy as specified in {{tenant-trust}}.

`sub`:
: A StringOrURI identifying the registered agent in the IdP's
  namespace. The identifier MUST be unique within that issuer
  and MUST NOT be reassigned to a different agent.

`aud`:
: A JSON string containing the issuer identifier of the intended
  RAS. This profile restricts the audience to one issuer identifier;
  an array or token endpoint URL MUST NOT be used.

`agent_id`:
: The Agent Principal identifier defined by {{AGENT}}. Its value
  MUST equal `sub`.

`agent_instance_id`:
: The Agent Instance identifier defined by {{AGENT}}, expressed in
  the IdP's namespace using the mapping in {{registry}}. This
  claim identifies the runtime that presented the assertion and
  need not equal `sub`.

`resource`:
: A JSON string containing the resource URI authorized by the IdP,
  using the resource identifier syntax defined in Section 2 of
  {{RFC8707}}. This profile permits exactly one resource.

`scope`:
: A nonempty JSON string containing the granted scopes in the
  format defined in Section 3.3 of {{RFC6749}}.

`cnf`:
: A JSON object containing the `jkt` confirmation method defined
  in Section 6.1 of {{RFC9449}}. Its value MUST be the thumbprint
  of the instance key validated during token exchange.

`jti`:
: A unique identifier for the grant, as defined in Section 4.1.7
  of {{RFC7519}}. The IdP MUST assign a new value to each grant.

`iat`:
: The time of issuance, expressed as a NumericDate.

`exp`:
: The expiration time, expressed as a NumericDate. The value MUST
  be later than `iat`, no more than 300 seconds after `iat`, and
  no later than the expiration of the input assertion.

This profile models the instance as an execution of the registered
agent, rather than a separate principal receiving delegated
authority. The WAG therefore MUST NOT contain `act`. The
`agent_instance_id` claim identifies that execution; `cnf`
identifies the key it must prove it holds. A separate runtime
identifier does not by itself establish delegation.

Delegation to a distinct principal uses the actor semantics in
Section 4.1 of {{RFC8693}} and is outside this profile. Issuing a
grant during a job or task does not by itself create such a
relationship, nor make the task's initiator its subject or actor.

Additional agent claims follow {{AGENT}}. The IdP MUST include only
claims obtained from validated evidence or an authorized registry
source, subject to its freshness policy. It MUST NOT include raw
`agent_runtime` evidence in the WAG. Additional authorization
properties defined by {{WAG}} do not expand the granted scope.

## Example

The following non-normative example shows the decoded header and
claims of a WAG. The signature is omitted and the key thumbprint
is abbreviated.
The IdP has authorized registered agent `urn:acme:agent:42`,
executing as instance `urn:acme:instance:run-7`, to request access
to the support API.

~~~ json
{
  "typ": "oauth-wag+jwt",
  "alg": "ES256",
  "kid": "idp-key-1"
}
~~~

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

# Protocol {#protocol}

## Overview {#deployment}

The client obtains a Client Instance Assertion from an Agent
Attester trusted by the IdP. It exchanges that assertion for a WAG,
then presents the WAG to the RAS to obtain an access token. The
same instance key is used throughout the exchange.

~~~ ascii-art
  Agent Attester       Client             IdP             RAS
        |                 |                |               |
        |-- Assertion --->|                |               |
        |                 |                |               |
        |                 |-- Token ------>|               |
        |                 |   Exchange     |               |
        |                 |<-- WAG --------|               |
        |                 |                |               |
        |                 |-- Access Token Request ------->|
        |                 |<-- Access Token ---------------|
~~~

Before the exchange, the IdP and RAS establish the trust and
subject mappings described in {{identity}}. The client determines
support for this profile using {{metadata}}. All token endpoint
requests and responses are subject to the transport security
requirements of {{RFC6749}} and {{RFC8693}}.

## Instance Assertion {#instance-assertion}

The client obtains a Client Instance Assertion conforming to
{{CIA}} and {{AGENT}}. The assertion MUST contain `client_id`,
`agent_id`, `agent_instance_id`, and `cnf.jkt`. Its `sub` MUST equal
`agent_instance_id`, and its `aud` MUST be the IdP issuer
identifier. Its lifetime MUST NOT exceed 300 seconds. The Agent
Attester MUST authenticate the instance's relationship to the
agent identified by `agent_id` before issuing the assertion.

How the client obtains the assertion is outside the scope of this
specification. For example, an Agent Attester can authenticate
native workload credentials and issue an assertion containing the
required agent claims and key confirmation.

The examples below use an assertion with the following decoded
claims. The platform's agent and instance identifiers are mapped
to the IdP identifiers shown in {{grant}}.

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

## Token Exchange {#issuance}

### Request {#exchange-request}

The client makes an HTTP POST request to the IdP token endpoint
using the request format in Section 2.1 of {{RFC8693}}. Parameters
are encoded as `application/x-www-form-urlencoded` in the request
body:

`grant_type`:
: REQUIRED. The value MUST be
  `urn:ietf:params:oauth:grant-type:token-exchange`.

`requested_token_type`:
: REQUIRED. The value MUST be
  `urn:ietf:params:oauth:token-type:wag`.

`subject_token`:
: REQUIRED. The Client Instance Assertion described in
  {{instance-assertion}}.

`subject_token_type`:
: REQUIRED. The value MUST be
  `urn:ietf:params:oauth:token-type:client-instance-jwt`.

`client_id`:
: REQUIRED. The client identifier registered at the IdP. The value
  MUST equal the assertion's `client_id` claim.

`audience`:
: REQUIRED. The issuer identifier of the intended RAS. This
  parameter MUST occur exactly once.

`resource`:
: REQUIRED. The target resource URI, as defined in Section 2 of
  {{RFC8707}}. This parameter MUST occur exactly once.

`scope`:
: REQUIRED. A nonempty scope string for the requested resource,
  using the syntax in Section 3.3 of {{RFC6749}}.

The client MUST include a DPoP proof in the `DPoP` HTTP header
field, signed with the key identified by the assertion's
`cnf.jkt`. Client authentication follows {{client-metadata}}.
The request MUST NOT contain `actor_token`, `actor_token_type`,
or `client_instance_assertion`.

This use of `subject_token` is the grant-issuance extension defined
by {{CIA}}. It supplies evidence about the agent requesting a WAG;
it does not request a delegated access token. No preliminary IdP
access token is required.

The following is a non-normative request example. Extra line
breaks and indentation in form bodies are for display only; JWTs
and DPoP proofs are abbreviated throughout the examples.

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

### Processing Rules {#idp-processing}

The IdP MUST enable this profile for the client before accepting
the request. It selects the profile using `requested_token_type`
and the approved client configuration. The request processing
requirements of {{RFC8693}}, {{CIA}}, and {{AGENT}} apply with
these additional rules:

1. The IdP MUST validate the assertion's signature, JWT type,
   issuer trust, audience, time claims, client binding, and agent
   claims. It MUST enforce {{instance-assertion}} and reject an
   assertion containing `act`.
2. The IdP MUST validate the DPoP proof under Section 4.3 of
   {{RFC9449}} and verify that its key thumbprint matches the
   assertion's `cnf.jkt`. When the registered authentication
   method is `client_instance_assertion`, the IdP MUST apply the
   authentication procedure in {{CIA}} to the assertion in
   `subject_token`. Otherwise, it MUST validate the client's
   separately registered authentication method.
3. The IdP MUST resolve the agent and instance using {{registry}}
   and verify that the agent is enabled. It MUST evaluate current
   policy for the assertion's freshness, the instance's authority
   to execute as that agent, and the requested audience and resource.
4. The IdP MUST restrict the granted scopes to a nonempty subset
   of the requested scopes permitted for that agent and resource.
   Authorization attributes MUST come from sources approved for
   those attributes in the registry.
5. The IdP MUST prevent a second successful use of the assertion's
   `(iss, jti)` pair until its expiration, including accepted clock
   skew. Replay detection and acceptance MUST be atomic. An
   assertion used for both authentication and subject evidence
   constitutes one use within the request.
6. The IdP MUST issue the WAG with the resolved agent and instance
   identifiers, approved audience, resource, scopes, and validated
   key confirmation, as specified in {{grant}}. It MUST retain the
   input identity mapping and the grant's `jti`, key, target, and
   authorization decision for audit.

### Response {#exchange-response}

On success, the IdP returns a token exchange response as defined
in Section 2.2.1 of {{RFC8693}}, with the following parameters:

`access_token`:
: REQUIRED. The WAG. This parameter carries an authorization
  grant rather than an access token in this exchange.

`issued_token_type`:
: REQUIRED. The value MUST be
  `urn:ietf:params:oauth:token-type:wag`.

`token_type`:
: REQUIRED. The value MUST be `N_A`.

`expires_in`:
: REQUIRED. The remaining lifetime of the WAG in seconds.

`scope`:
: REQUIRED. The scope string included in the WAG.

The response MUST NOT contain a `refresh_token`. The client MUST
verify the returned token type, audience, resource, and key binding
before using the grant. If they do not match the requested type,
target, and instance key, the client MUST reject the response.

For example:

~~~ http-message
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-store
Pragma: no-cache

{
  "access_token": "eyJ...workload-authorization-grant...",
  "issued_token_type": "urn:ietf:params:oauth:token-type:wag",
  "token_type": "N_A",
  "expires_in": 290,
  "scope": "issues.read"
}
~~~

### Error Response {#exchange-errors}

The IdP returns errors using Section 2.2.2 of {{RFC8693}} and
Section 5.2 of {{RFC6749}}. The following rules apply:

* `invalid_request` is returned for a malformed request, a
  prohibited actor or instance parameter, invalid subject evidence
  when independent client authentication is used, or an unknown,
  disabled, or ambiguously bound agent.
* `invalid_client` is returned for client authentication failures,
  including assertion validation failures when the assertion is
  the registered client authentication credential, per {{CIA}}.
* `invalid_target` is returned when the IdP cannot authorize the
  requested audience or resource for the agent's tenancy.
* `invalid_scope` is returned for an invalid scope request or when
  no requested scope can be granted.

DPoP proof errors and nonce challenges follow {{RFC9449}}, subject
to the authentication error handling specified by {{CIA}}.

## Access Token Request {#redemption}

The client makes an HTTP POST request to the RAS token endpoint
using Section 2.1 of {{RFC7523}}. The following parameters are
encoded as `application/x-www-form-urlencoded` in the request body:

`grant_type`:
: REQUIRED. The value MUST be
  `urn:ietf:params:oauth:grant-type:jwt-bearer`.

`assertion`:
: REQUIRED. The WAG obtained from the IdP.

`resource`:
: REQUIRED. The resource URI from the WAG. This parameter MUST
  occur exactly once and MUST equal the grant's `resource` claim.

`scope`:
: OPTIONAL. The requested scopes, which MUST be a subset of the
  WAG's scopes. If omitted, the request is for all scopes in the WAG.

The client MUST include a DPoP proof for the RAS token endpoint,
signed with the key identified by the WAG's `cnf.jkt`. The request
MUST NOT contain `client_instance_assertion`, `actor_token`, or
`actor_token_type`. Client authentication requirements are
specified in {{client-metadata}}.

For example:

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

### Processing Rules {#ras-processing}

The RAS applies Section 3.1 of {{RFC7523}} and Section 5.2 of
{{RFC7521}}, with the following additional requirements:

1. The RAS MUST validate the signature and all required headers
   and claims specified in {{grant}}. It MUST reject an expired
   grant or an `iat` value in the future, allowing only its
   configured clock skew, and enforce the maximum grant lifetime.
2. The RAS MUST verify that `iss` is authorized for this profile
   and for the target tenancy under {{tenant-trust}}. Signing keys
   MUST be resolved within that issuer's trust configuration.
3. The RAS MUST require `aud` to equal its issuer identifier and
   the requested `resource` to equal the grant's resource. The
   resource MUST belong to the tenancy authorized for that issuer.
   Identifier comparisons MUST use exact string matching;
   URI normalization MUST NOT be applied.
4. The RAS MUST resolve `(iss, sub)` under {{ras-subject}} and
   verify that local policy permits access for that principal.
5. The RAS MUST validate the DPoP proof under Section 4.3 of
   {{RFC9449}} and verify that its key thumbprint equals the
   WAG's `cnf.jkt`.
6. The RAS MUST reject requested scopes outside the WAG's scopes.
   It MUST restrict access-token scopes to a nonempty subset of
   the requested scopes permitted by local policy.
7. The RAS MUST prevent a second successful use of `(iss, jti)`
   until the grant expires, including accepted clock skew. Replay
   detection and grant acceptance MUST be atomic.

### Response {#access-token-response}

On success, the RAS returns the token response defined in
Section 5.1 of {{RFC6749}} and Section 5 of {{RFC9449}}. The
`token_type` MUST be `DPoP`. The response MUST include `scope` and
`expires_in` with the issued scope and lifetime, and MUST NOT
include `refresh_token`. The access token MUST be bound to the
verified instance key and expire within 300 seconds of issuance.

For example:

~~~ http-message
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-store
Pragma: no-cache

{
  "access_token": "2YotnFZFEjr1zCsicMWpAA",
  "token_type": "DPoP",
  "expires_in": 300,
  "scope": "issues.read"
}
~~~

To obtain another access token, the client obtains a fresh
assertion and repeats the exchange. Neither a consumed WAG nor
an assertion already accepted by the IdP can be reused.

### Error Response {#access-token-errors}

Errors follow Section 5.2 of {{RFC6749}}. The RAS MUST return
`invalid_grant` for a WAG that fails validation, including an
expired, replayed, incorrectly targeted, or incorrectly bound
grant, or a subject for which local policy prohibits issuance.
It MUST return `invalid_request` for a malformed request or a
prohibited actor or instance parameter, and `invalid_scope` for
invalid scopes or when no requested scope can be granted.

DPoP proof validation failures use `invalid_dpop_proof`; nonce
challenges use `use_dpop_nonce`, as specified in {{RFC9449}}.
A valid proof made with a key that does not match the WAG is a
grant binding failure and results in `invalid_grant`.

## Access Token Contents {#resource-token}

The RAS MUST associate the registered agent, authenticated instance,
and verified DPoP key with the access token. JWT access tokens and
active introspection responses MUST contain `sub` identifying the
registered agent, `sub_profile` including `ai_agent`,
`agent_instance_id` identifying the runtime, and `cnf.jkt`
identifying the verified key. They MUST NOT contain `act` for
that runtime or classify a distinct registered agent as
`client_instance` solely because a CIA authenticated its instance.
Subject and instance identifiers are mapped as specified in
{{ras-subject}}. Additional claims follow {{AGENT}}.
The RAS and RS MUST apply the `sub_profile` syntax and
classification semantics in {{ACTOR-PROFILE}}. Here the claim is
top-level and classifies the registered agent named by `sub`;
it does not classify `agent_instance_id` or establish delegation.

This profile does not prescribe a JWT access token format. When
issuing opaque access tokens, the RAS MUST support authenticated
introspection under {{RFC7662}} and provide the corresponding
identity and key confirmation. The RS MUST validate access token
authenticity, audience, expiration, and DPoP binding under
{{RFC9449}} before applying its authorization policy.

# Identity and Tenant Relationships {#identity}

## IdP Subject Resolution {#registry}

The IdP MUST maintain an approved federation binding from the
exact tuple `(iss, client_id, agent_id)` in a validated assertion
to one registered agent. It MUST reject an unknown or ambiguous
binding. Agent identifiers MUST be stable across runtime and key
changes and MUST NOT be reassigned. Display names, model names,
platform product identifiers, and key thumbprints MUST NOT be
used to resolve the registered agent.

The registry MUST also maintain the agent's enabled status,
permitted RAS issuers, resources and scopes, and the sources
authorized to supply its attributes. Only administratively
authorized sources may create or modify bindings and assignments.
A client-published `instance_issuers` value does not by itself
establish a federation binding or authorize access to a resource.
A registered agent can represent a reusable workload identity.
Individual jobs or tasks executed under that identity do not
require separate agent entries or OAuth client registrations in
this profile.

The IdP MUST map the authenticated `(iss, sub)` of the assertion
to an issuer-scoped, non-reassigned instance identifier and retain
the relationship to its registered agent. It MUST reject a
conflicting agent assignment for the same instance. The mapping
MUST remain stable across key rotation. The IdP MAY preserve an
incoming identifier if its namespace is trusted and collision-free.
Agent and instance identifiers SHOULD be URIs in controlled
namespaces.

Registry provisioning can use {{SCIM-AGENT}}, an administrative
interface, or another trusted mechanism. A SCIM `externalId` MUST
be qualified by the provisioning source and issuer context when
used in a binding. Provisioning alone does not authorize
federation. Just-in-time provisioning MAY occur before issuance
under an explicit administrative policy; a valid assertion alone
MUST NOT authorize account creation, reactivation, or assignment.

## Issuer and Tenant Trust {#tenant-trust}

The IdP MUST use a distinct issuer identifier for each tenancy,
following the issuer model in {{WAG}}. The RAS MUST establish an
explicit trust relationship binding that issuer to a local tenancy
and the resources for which it may issue grants. User SSO trust
alone MUST NOT authorize acceptance of WAGs.

Metadata and signing keys MUST be obtained through trusted
configuration or authenticated discovery for the approved issuer.
Keys and subject mappings MUST be scoped to that issuer. An
untrusted JWT header containing a key URL MUST NOT establish
issuer trust.

## RAS Subject Resolution {#ras-subject}

The RAS MUST resolve the WAG's `(iss, sub)` to a local agent
principal under the configured issuer and tenancy relationship.
It MAY provision a local principal just in time under that policy.
A grant MUST NOT reactivate a disabled principal contrary to local
policy.

The RAS MUST preserve the identity of the authorized agent and
instance when mapping them to its own namespace. Mappings MUST
distinguish identifiers from different accepted issuers that could
otherwise collide. The RAS MUST retain the original IdP issuer,
agent identifier, and instance identifier with the token state.

# Authorization Server Metadata {#metadata}

An authorization server supporting this profile MUST publish the
following member in its metadata document defined by {{RFC8414}}:

`workload_agent_federation`:
: A JSON object describing support for this profile. If absent,
  support is not advertised.

The `workload_agent_federation` object contains these members:

`roles`:
: REQUIRED. A nonempty array of strings containing `issuer`,
  `resource_authorization_server`, or both. The values indicate
  support for WAG issuance and acceptance, respectively.

`subject_token_types_supported`:
: REQUIRED when `roles` contains `issuer`. An array of supported
  subject token type identifiers. The array MUST contain
  `urn:ietf:params:oauth:token-type:client-instance-jwt`.
  Additional types require a separately specified input profile
  defining identity, client, registry, and key validation.

`grant_signing_alg_values_supported`:
: REQUIRED. A nonempty array of JWS algorithm names supported for
  WAG issuance or validation, as indicated by `roles`. If both
  roles are present, listed algorithms apply to both. The array
  MUST contain `ES256` and MUST NOT contain `none` or symmetric
  MAC algorithms.

The IdP MUST include `urn:ietf:params:oauth:grant-type:token-exchange`
in `grant_types_supported` and `client_instance_assertion` in
`token_endpoint_auth_methods_supported`. The RAS MUST include
`urn:ietf:params:oauth:grant-type:jwt-bearer` in
`grant_types_supported`. Both MUST publish
`dpop_signing_alg_values_supported` containing `ES256` per
{{RFC9449}}. Additional asymmetric algorithms MAY be supported.

The client MUST verify that the IdP advertises the `issuer` role
and the RAS advertises the `resource_authorization_server` role
before using this profile. Advertised capabilities do not
establish issuer trust or override configured algorithm policy.

# Client Metadata {#client-metadata}

The client registration at the IdP follows {{CIA}} and MUST have
an administratively approved `instance_issuers` value and
`ai_agent_instance_profile` set to `true` as defined by {{AGENT}}.
The registration represents the logical client application;
individual agent instances do not require separate registrations.

The IdP MUST support `client_instance_assertion` as a
`token_endpoint_auth_method` for this profile. With this method,
the assertion in `subject_token` and the DPoP proof authenticate
the client. All authentication requirements in {{CIA}} apply,
with `subject_token` replacing the normal presentation parameter.
The IdP MAY support other client authentication methods. The
client MUST use the method associated with its registration;
assertion presentation MUST NOT replace a different registered
method without agreement.

This profile does not require `client_id` or client authentication
at the RAS. The WAG and proof of the bound instance key establish
the presenting agent's authorization. If a deployment separately
requires client authentication at the RAS, it MUST NOT alter the
grant subject or relax grant restrictions. An implementation MUST
NOT construct a client identifier by copying the grant's issuer
or subject.
A JWT access token format that requires `client_id` needs a
separately established client identity.

# Security Considerations {#security}

The security considerations of {{CIA}}, {{AGENT}}, {{WAG}},
{{RFC7521}}, {{RFC8693}}, {{RFC8725}}, and {{RFC9449}} apply.

## Registry and Attribute Authority

A federation binding authorizes an issuer to attest instances of
a registered agent. Compromise of the issuer or registry writer
can therefore permit unauthorized grant issuance. The IdP MUST
authenticate registry changes, restrict each source to its
approved namespace and attributes, and audit binding and assignment
changes. Synchronization MUST NOT merge agents by display name
or allow a platform source to overwrite enterprise policy.

An assertion's signature authenticates its issuer's statements;
it does not establish that the IdP independently measured model
or runtime state. The IdP MUST evaluate evidence freshness and
current registry policy at each issuance.

## Token Substitution

The assertion, WAG, and access token have different audiences and
processing rules. Implementations MUST enforce their respective
audiences, presentation parameters, and, for JWTs, token types. If profile
validation fails, the IdP and RAS MUST NOT retry processing under
a less restrictive grant profile or issue a bearer token. Clients
MUST NOT fall back to an unadvertised profile or bearer processing
when capability or key confirmation is missing.

## Proof of Possession and Replay

Each instance MUST hold its own proof-of-possession key. Validating
a DPoP proof establishes possession of that key; the assertion and
registry binding establish its authority to represent the agent.
The IdP MUST NOT replace the validated binding with an arbitrary
requester-selected key.

Clients MUST generate a proof appropriate to each endpoint and
support DPoP nonce challenges. Replay detection MUST cover every
node accepting assertions or WAGs for the corresponding issuer
and endpoint service. The single-use restrictions in {{protocol}}
apply in addition to DPoP proof validation.

## Lifecycle {#lifecycle}

Disabling an agent, removing an assignment, or revoking assertion
issuer trust MUST prevent new WAG issuance once the change is
applied at the IdP. Registry synchronization MUST have a configured
maximum delay; the IdP MUST reject issuance that depends on data
stale beyond that limit. Disabling a local agent at the RAS MUST
prevent new access-token issuance for that agent.

These changes do not by themselves invalidate previously issued
grants or access tokens. An access token can outlive the consumed
WAG. With the lifetime limits in this profile, the token can
remain usable for up to 300 seconds after grant redemption, in
addition to synchronization delay and accepted clock skew.
Earlier termination requires a deployment-supported revocation
or status propagation mechanism.

A restarted runtime MUST receive a new instance identifier. Key
rotation within an existing instance MUST preserve its identifier
and requires fresh evidence binding the new key.

# Privacy Considerations {#privacy}

Stable agent identifiers permit correlation across instances and
resources. Instance identifiers permit correlation of requests
within an execution. The IdP and RAS SHOULD limit disclosure of
identifiers and provenance to the parties that require them for
authorization or audit. Error responses SHOULD NOT disclose the
existence of unrelated agents.

Logs MUST NOT contain raw assertions, grants, credentials, or
private keys. Audit records should retain issuer-qualified
identifiers and authorization decisions while minimizing model
and runtime information. The claim disclosure requirements of
{{AGENT}} apply.

# IANA Considerations {#iana}

## OAuth Authorization Server Metadata Registration

This specification requests registration of the following value
in the "OAuth Authorization Server Metadata" registry established
by {{RFC8414}}:

Metadata Name:
: `workload_agent_federation`

Metadata Description:
: Workload Agent Federation roles, subject token types, and grant
  signing algorithms supported by an authorization server.

Change Controller:
: IETF

Specification Document(s):
: {{metadata}} of this document.

--- back

# Open Issues {#wag-coordination}
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

The token type `urn:ietf:params:oauth:token-type:wag` and JWT type
`oauth-wag+jwt` are proposed identifiers pending coordination with
{{WAG}}. Their generic definitions and OAuth URI and media type
registrations are expected to be specified there. The IdP issuer
role and the audience restrictions in this profile also need to
be aligned with that specification before publication. The agent
claims are defined and registered by {{AGENT}}; the CIA token type
is defined by {{CIA}}.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

## -00
{:numbered="false"}

* Initial version.

# Acknowledgments
{:numbered="false"}

The author thanks participants in the OAuth, WIMSE, and SCIM
communities for work on agent identity and workload federation.
