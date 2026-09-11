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
  SCIM-AGENT: I-D.wzdk-scim-agent-resource
  RFC6749:
  RFC7515:
  RFC7518:
  RFC7519:
  RFC7523:
  RFC7638:
  RFC7643:
  RFC7644:
  RFC7662:
  RFC8414:
  RFC8693:
  RFC8707:
  RFC8725:
  RFC9068:
  RFC9449:
informative:
  RFC6755:
  RFC9967:
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  SPIFFE-OAUTH: I-D.ietf-oauth-spiffe-client-auth
  JWT-DPOP: I-D.parecki-oauth-jwt-dpop-grant
  SCIM-GOVERNANCE: I-D.kushwaha-scim-agent-governance
--- abstract

This specification profiles OAuth 2.0 to enable agents hosted by
different platforms to access applications through an identity
provider. The identity provider resolves authenticated runtime
evidence to a governed agent identity and issues authorization
grants for resource authorization servers. An agent acting for
itself uses a Workload Authorization Grant; an agent acting for
a user uses an Identity Assertion JWT Authorization Grant with
an agent actor represented using the OAuth Actor Profile.
The profile defines credential acquisition, token exchange,
grant processing, provisioning correlation, and sender constraints.

--- middle

# Introduction

An identity provider (IdP) can govern agents from several
platforms, including their ownership, groups, application
assignments, and lifecycle. A Resource Authorization Server
(RAS) can trust that IdP without trusting each platform's
native workload credentials.

This document defines two modes:

* Self-acting: exchange an IdP-issued Agent Token for a Workload
  Authorization Grant {{WAG}} identifying the agent as subject.
* Delegated: exchange a user's identity assertion and an Agent
  Token for an Identity Assertion JWT Authorization Grant
  {{ID-JAG}} identifying the agent as actor.

Implementations MUST support at least one mode and all common
requirements for their role in that mode.

Both modes use OAuth 2.0 Token Exchange {{RFC8693}} at the IdP
and JWT authorization grant redemption {{RFC7523}} at the RAS.
The Resource Server (RS) accepts its RAS's access token, not
the grant. The common bootstrap uses Client Instance
Identification {{INSTANCE}} and Attestation-Based Client
Authentication {{ATTEST}}. Task-specific authority and
multi-agent delegation chains are outside this profile.

~~~ artwork
  Platform attestation + instance key proof
                    |
                    v
       IdP registry -> Agent Token
                    |
          +---------+----------+
          |                    |
   Agent as subject    User as subject, agent as actor
          |                    |
         WAG                 ID-JAG
          |                    |
          +---------+----------+
                    v
        RAS -> DPoP access token -> Resource
~~~

## Relationship to the OAuth Actor Profile {#actor-relationship}

Implementations supporting delegated mode MUST implement the
actor identity, construction, preservation, authorization,
sender-binding, and resource-processing rules of
{{ACTOR-PROFILE}} for the paths specified here. This document
supplies the agent credential and registry mapping, selects
ID-JAG as the grant, and defines the required user-agent
authorization checks. It does not define a competing actor
format. JWT grant and access-token processing use those Actor
Profile rules; opaque access tokens use its introspection
compatibility path as specified in {{access-tokens}}.

This profile supports one current actor, the Registered Agent.
Its runtime is separate `client_instance` context. IdP grant
issuance introduces that actor from the validated Agent Token;
RAS redemption preserves it and does not introduce another
actor merely because a token endpoint or runtime was involved.

The grant-specific audience, token types, and subject inputs
are those of {{ID-JAG}} as constrained here. In particular,
ID-JAG's RAS issuer audience applies rather than a generic
JWT assertion-grant token-endpoint audience; see
{{coordination}}. Self-acting-only and instance-authentication
implementations are not required to implement Actor Profile.

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
  serve as, or authorize, a Client Attester. Its logical OAuth
  client is distinct from the agents it hosts.

Agent Token:
: A short-lived, sender-constrained JWT access token issued by
  the IdP for this profile's exchange service. It identifies
  a Registered Agent and its authenticated instance.

Federation Binding:
: An administratively authorized mapping from a trusted
  attester, logical client, and platform agent identifier to
  a Registered Agent.

# Identity and Deployment {#identity}

The IdP MUST maintain a stable, non-reassignable identifier for
each Registered Agent. It MUST resolve external identities by
an exact, issuer-qualified Federation Binding. It MUST NOT
merge agents by display name, model, owner name, or unqualified
subject value. Several approved external bindings MAY identify
the same Registered Agent.

The instance is an execution of that principal. Starting a
worker or rotating a key MUST NOT, by itself, change the agent
principal or create a delegated actor.

| Mode | Grant subject | Grant actor | Instance context |
|---|---|---|---|
| Self-acting | Registered Agent | Absent | Execution of the subject |
| Delegated | User | Registered Agent | Execution of the current actor |

A user-initiated agent can be self-acting when it uses its own
authority. The IdP MUST determine the mode from the requested
grant and authorized relationship, not from a human initiator
in audit data. Instance-only principals require another profile.

Before issuance, the IdP and RAS MUST establish a trust
relationship binding an IdP issuer to a RAS tenant, permitted
resources, modes, subject mappings, signing keys, and policy.
This profile uses one IdP issuer per enterprise tenancy in
both modes. Discovery alone MUST NOT establish this trust;
user SSO trust MUST NOT implicitly permit self-acting access.

The IdP client registration represents the logical application
and MUST require {{INSTANCE}} with
`attest_jwt_client_auth_dpop`. Approved Federation Bindings
determine which agents it can host. Individual agents and
instances do not require separate client registrations.

Delegated mode additionally requires client authentication at
the RAS under {{ID-JAG}}. The IdP MUST maintain an approved
mapping from its authenticated client and target RAS/resource
to that downstream client. Missing or ambiguous mappings MUST
cause rejection. CIMD {{CIMD}} can provide metadata but does
not replace this approval or agent provisioning.

Self-acting mode does not require a client registration at the
RAS. A deployment MAY require client authentication by
agreement, without changing the authorized subject. It MUST
NOT manufacture a client identifier from the agent subject
merely to satisfy a token-format requirement.

The trust configuration MUST identify the IdP and RAS roles
and the modes supported and permitted for that relationship.
The client and IdP MUST verify applicable metadata under
{{metadata}}. Missing support for the selected mode MUST NOT
cause silent downgrade. The IdP owns enterprise
identity and admission; the platform remains responsible for
runtime evidence and the RAS for its resource policy.

# Establishing an Agent Token {#bootstrap}

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

The attestation MAY include these provenance claims:

`agent_platform`:
: A nonempty StringOrURI identifying the platform product or
  implementation, not the enterprise agent.

`agent_model`:
: An object containing a REQUIRED nonempty string `id` naming
  the model and an OPTIONAL nonempty string `version`.

`agent_runtime`:
: An object containing a REQUIRED nonempty string `id` naming
  the runtime implementation and an OPTIONAL nonempty string
  `version`. It does not identify the instance.

Unknown provenance members are ignored. Incorrect types or
empty values for defined claims or members MUST cause
rejection. These are attester statements, not proof of model
behavior. Platform-supplied groups, owners, and assignments
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
Its `iss` is the IdP tenancy issuer, `sub` is the Registered
Agent identifier, and `client_id` is the actual IdP client.
Its `aud` MUST equal the IdP issuer identifier and `scope`
MUST be `agent-federation`. This audience and scope identify
the IdP's exchange service; no separate resource identifier
or endpoint is defined. The token MUST contain
`sub_profile=ai_agent` as defined by {{ENTITY-PROFILES}},
`agent_federation=1` as a string, `client_instance` identifying
the authenticated upstream instance, and `cnf.jkt` derived
from the proven key under {{RFC7638}}. It MUST NOT contain `act`.

The IdP MUST associate the token with its approved Federation
Binding. The token MUST expire within 300 seconds and no later
than the attestation. The response MUST have `token_type=DPoP`,
`expires_in`, and `scope`; it MUST NOT include a refresh token.
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
extensions MUST NOT weaken the required ATTEST bootstrap.
A workload identity shared by replicas MUST NOT identify one
replica without additional authenticated evidence.

# Requesting an Authorization Grant {#exchange}

The client uses {{RFC8693}} at the IdP token endpoint, with the
same client and {{ATTEST}} DPoP combined-mode authentication.
The proof MUST be fresh and its key MUST match the Agent Token.

In both modes, `grant_type` MUST be
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

## Delegated Mode {#delegated-exchange}

`requested_token_type` MUST be
`urn:ietf:params:oauth:token-type:id-jag`. `subject_token` MUST
be a user credential accepted under {{ID-JAG}}. Implementations
MUST support an OpenID Connect ID Token with
`subject_token_type=urn:ietf:params:oauth:token-type:id_token`.
Other subject inputs permitted by {{ID-JAG}} MAY be supported
with its validation rules and applicable {{ACTOR-PROFILE}}
subject processing.

`actor_token` MUST be the Agent Token, with `actor_token_type`
equal to `urn:ietf:params:oauth:token-type:access_token`. The
IdP MUST apply the JWT access token actor-input processing of
{{ACTOR-PROFILE}}. Its top-level `(iss, sub)` identifies the
agent actor; its runtime claim does not supply `act.sub`.

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

## IdP Processing {#idp-processing}

Before issuance, the IdP MUST:

1. Authenticate the current client and instance and resolve
   the current Federation Binding from its agent evidence.
2. Validate the Agent Token as an unexpired token issued by
   this IdP for this exchange service and purpose. Match its
   client, agent, instance, and key to the current request.
   Another valid IdP access token MUST NOT be substituted.
3. Check current agent status, attester trust, external binding,
   application assignment, and permitted mode. Reject stale
   authorization data under {{lifecycle}}.
4. Validate the RAS/resource association and requested scopes.
   Determine a permitted, nonempty subset without broadening
   the request.
5. In delegated mode, validate the user credential under
   {{ID-JAG}}, including audience/client checks and applicable
   scope ceilings. Resolve the user and downstream client.
   Verify existing user-approved or administrator-authorized
   delegation for this Registered Agent, user, client context,
   resource, and scope. Two valid tokens alone MUST NOT
   establish that authorization.
6. Construct the grant under {{grant}}. In delegated mode,
   use Actor Profile's construction rules to introduce the
   validated agent as the sole actor and bind the output to
   its proven key. At RAS redemption this is presenter
   continuation, not another actor introduction.

The means of obtaining prior delegation approval is outside
this profile; absence of approval MUST cause rejection. Stored
approval MUST identify the agent, user, client context,
resources, bounds, and lifecycle. A shared logical client
MUST NOT let one agent use another agent's approval.

The maximum supported actor depth for this profile is one.
Inputs carrying an existing `act` chain MUST be rejected,
not erased or implicitly extended. An Agent Token carrying
`act` is invalid under Actor Profile's direct-actor rule.

The grant lifetime MUST NOT exceed 300 seconds or the remaining
lifetime of the Agent Token, accepted user credential, or
applicable delegation. Bootstrap scope is not a downstream
scope ceiling; it authorizes this service operation. A user
refresh-token or other authorization-state input retains the
scope ceiling required by its input profile.

## Response and Errors {#exchange-response}

The response follows {{RFC8693}}. `issued_token_type` MUST
equal the requested WAG or ID-JAG token type; `token_type` MUST
be `N_A`. `access_token` contains the grant, `expires_in` gives
its remaining lifetime, and `scope` lists the issued scopes.
No refresh token is issued.

The client MUST check that the response's issued type matches
the requested type and that the grant has the expected protected
type, `agent_federation` version, audience, resource, scope subset,
and `cnf.jkt` for its proven key. Missing or inconsistent binding
MUST cause failure. These checks do not replace the RAS's
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
violations use `invalid_request`. Invalid credentials or
inconsistent identity/key bindings use `invalid_grant`.
Unacceptable targets use `invalid_target`; impermissible scopes
use `invalid_scope`. For a validated actor whose required
delegation cannot be established or is prohibited, the IdP
MUST use `actor_unauthorized` from {{ACTOR-PROFILE}}. It MUST
NOT issue a self-acting grant in response to that failure.
Clients not allowed to use this profile receive
`unauthorized_client`. Authentication and freshness challenges
retain {{ATTEST}} and {{RFC9449}} errors.

# Authorization Grants {#grant}

Grants MUST be signed JWTs in JWS Compact Serialization
{{RFC7515}} under the approved IdP tenancy issuer. The protected
header MUST contain an approved asymmetric `alg` and a `kid`
resolvable through trusted issuer key configuration.
Implementations MUST support `ES256` {{RFC7518}} and reject
`none` and symmetric MAC algorithms.

Self-acting grants follow {{WAG}} with
`typ=oauth-wag+jwt`; delegated grants follow {{ID-JAG}} with
`typ=oauth-id-jag+jwt`. See {{coordination}} for the proposed
WAG identifiers and IdP deployment.

The following claims are REQUIRED in both modes:

`iss`:
: The approved IdP tenancy issuer.

`aud`:
: A string containing the exact RAS issuer identifier.

`sub`:
: The Registered Agent identifier from the Agent Token in
  self-acting mode; the downstream-mapped user identifier in
  delegated mode. It MUST be nonempty and non-reassignable
  within the grant issuer's namespace.

`iat`, `exp`, `jti`:
: Issue time, expiration time, and unique grant identifier.
  `exp` MUST exceed `iat` by at most 300 seconds, subject to
  {{idp-processing}}. The IdP MUST NOT reuse `(iss, jti)`.

`resource`, `scope`:
: The single approved resource and nonempty, space-delimited
  approved scopes.

`agent_federation`:
: The string `1`, identifying this profile's processing rules.
  Other values are not defined here.

`client_instance`:
: The object defined by {{INSTANCE}}. In grants, its `iss`
  MUST equal the grant issuer and its `id` MUST be an
  IdP-assigned reference mapping to the authenticated upstream
  instance. The IdP MUST retain that mapping and SHOULD scope
  the reference to the downstream trust relationship.

`cnf`:
: An object containing `jkt`, the JWK SHA-256 thumbprint of the
  proven instance public key. The IdP MUST derive it from the
  validated key, not an unsigned request value.

Self-acting grants MUST have `sub_profile=ai_agent` and MUST
NOT contain `act`. Delegated grants MUST have an Actor Profile
`act` object containing the Agent Token's `iss` and `sub`,
and `sub_profile=ai_agent`. The `ai_agent` entity profile is
defined by {{ENTITY-PROFILES}}. It classifies the durable
agent principal, not its runtime or logical OAuth client.

Delegated grants MUST include the downstream `client_id` and
other claims required by {{ID-JAG}}. Any user `sub_profile`
classification is supplied only when authoritative under
{{ACTOR-PROFILE}}. The single-tenancy issuer does not replace
ID-JAG's target-tenant processing. User and agent identities
MUST resolve to distinct, correctly typed local principals.

`client_instance` describes execution of the subject in
self-acting mode and of the current actor in delegated mode.
It MUST NOT add an actor or change the subject. Optional
provenance MAY be released after IdP policy evaluation.
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
  "agent_federation": "1",
  "client_instance": {
    "iss": "https://idp.example/tenant/acme",
    "id": "runtime-93ab"
  },
  "cnf": { "jkt": "Ak20Cf62SpTybasujYXbaI-Ms655MyvOZCtnnf8y1QU" },
  "iat": 1789128000,
  "exp": 1789128240,
  "jti": "grant-f194"
}
~~~

Example delegated grant payload:

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
  "agent_federation": "1",
  "client_instance": {
    "iss": "https://idp.example/tenant/acme",
    "id": "runtime-93ab"
  },
  "cnf": { "jkt": "Ak20Cf62SpTybasujYXbaI-Ms655MyvOZCtnnf8y1QU" },
  "iat": 1789128000,
  "exp": 1789128240,
  "jti": "grant-f195"
}
~~~

# Redeeming a Grant {#redemption}

The client sends the grant in `assertion` with
`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`
to the RAS token endpoint, accompanied by a fresh DPoP proof
using the bound key. An optional `resource` MUST equal the
grant's resource; optional `scope` MUST be a nonempty subset
of its scopes. If omitted, the grant's values apply.
`audience`, actor inputs, and `authorization_details` are
not permitted. Delegated requests MUST authenticate as the
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

1. Select the approved issuer/tenant relationship and validate
   signature, protected type, required claims, audience,
   lifetime, and `agent_federation=1`. Reject unsupported
   versions and mode/type mismatches.
2. Validate the DPoP proof for its token endpoint under
   {{RFC9449}}. Compute its public-key thumbprint and compare
   it to `cnf.jkt`. Missing or mismatched proof MUST fail.
3. Enforce delegated client authentication and exact downstream
   `client_id` matching under {{ID-JAG}}. Apply Actor Profile
   grant validation and presenter-continuation processing.
4. Resolve the subject and agent actor under {{provisioning}}.
   Check current local status and policy. A suspended agent
   MUST be rejected in either mode.
5. Apply the requested scope subset and local policy without
   exceeding the grant. For delegated access, evaluate user
   permissions, permitted agent behavior, and delegation bounds
   together. Their permissions MUST NOT be unioned.
6. Atomically consume `(iss, jti)` upon successful issuance.
   A grant MUST produce at most one successful issuance across
   all RAS nodes. Replay state MUST be retained through grant
   expiration plus accepted clock skew.

A lost successful response requires a new grant. Consumed grants
fail with `invalid_grant`. Malformed requests and invalid scope
use `invalid_request` and `invalid_scope`. Delegated actor
structure, identity, depth, and policy errors follow
{{ACTOR-PROFILE}}, including `actor_unauthorized` for a prohibited
or unconfirmed relationship. Other grant validation failures
use `invalid_grant`; authentication and nonce challenges retain
their base errors. No failure permits bearer issuance or retry
under a less restrictive grant profile.

# Access Tokens and Resource Processing {#access-tokens}

The RAS MUST issue a DPoP-bound access token for the approved
resource with `token_type=DPoP`, `expires_in`, and `scope`.
It MUST expire no later than the grant and MUST NOT be
accompanied by a refresh token. The client MUST reject another
token type or scopes broader than those in the grant.

The RAS MUST retain the mode, mapped subject, canonical agent
identity, validated `client_instance`, scopes, resource, key,
and originating grant identifiers in token state. Subject
mapping MUST preserve the underlying principal. In delegated
mode the RAS MUST preserve the validated `act` object unchanged
under {{ACTOR-PROFILE}}; local agent-record resolution is not
permission to rewrite its namespace or add a runtime actor.

Implementations MUST support opaque access tokens with
{{RFC7662}} introspection. This uses the Actor Profile
introspection compatibility path in delegated mode; an opaque
token itself is not an Actor Profile JWT. Active results MUST
include `sub`, `aud`, `exp`, `scope`, `cnf.jkt`,
`agent_federation=1`, and the grant's unchanged `client_instance`.
Delegated results MUST also include the unchanged `act` and
applicable subject classification under {{ACTOR-PROFILE}}.
An established logical client, including the delegated client,
MUST be reported as `client_id`. Inactive responses MUST NOT
disclose this context.

JWT access tokens MAY carry equivalent information directly;
delegated JWTs MUST follow Actor Profile's access-token output
rules. A token claiming {{RFC9068}} conformance MUST include
its required `client_id`. A clientless self-acting deployment
MUST use another token format.

The RS MUST validate the token or obtain an active introspection
result, enforce audience, expiry, scope, and local policy,
and verify DPoP against the enclosing token's `cnf.jkt`,
including the access-token hash required by {{RFC9449}}.
It MUST NOT accept grants or Agent Tokens as API access tokens.
Delegated processing MUST follow {{ACTOR-PROFILE}}, including
actor policy and errors, without reducing access to user-only
authorization. Required actor or instance context MUST NOT
be filtered from introspection for a resource relying on it.

The RS needs no upstream platform attestation support.
Instance context supports audit and risk restrictions; an
instance identifier does not itself grant permissions.

# Provisioning and Attributes {#provisioning}

The IdP MUST resolve an active Registered Agent before issuing
tokens or grants. Records MAY be synchronized from platforms
or admitted just in time under explicit policy. Each source
MUST be restricted to approved namespaces and writable
attributes. Changes to bindings and assignments, including
platform migration, MUST be authenticated and audited.

## Downstream Correlation {#scim}

The IdP and RAS MUST support provisioning Agent resources using
{{SCIM-AGENT}} and {{RFC7644}}. A deployment MAY instead enable
JIT admission under the trust relationship. Both paths MUST
use the same principal mapping.

Each authenticated SCIM provisioning client MUST be bound to
one IdP issuer and target tenant. For an Agent resource,
`externalId` {{RFC7643}} MUST equal the agent identifier used
in that IdP's WAG `sub` and ID-JAG `act.sub`. The RAS MUST
retain source issuer and tenant with the record and resolve
`(issuer, externalId)` within that tenant. It MUST NOT treat
`externalId` or provider-local SCIM `id` as globally unique.
User mapping continues to follow {{ID-JAG}}.

JIT MUST resolve that qualified mapping before creating a
record. Concurrent SCIM and JIT creation MUST converge on one
record. A grant or create operation MUST NOT reactivate a
disabled identity without explicit reactivation authority.
Deletion tombstones or equivalent state MUST prevent stale
credentials or delayed provisioning from recreating retired
identities. Identifiers MUST NOT be reassigned. Per-instance
SCIM records are not required; an instance's end does not
retire its Registered Agent.

## Groups and Ownership {#attributes}

SCIM membership and Agent ownership use {{SCIM-AGENT}}.
The RAS MUST correlate membership references to local Agent
or User resources, retaining their distinct types. Ownership
MUST NOT implicitly confer the owner's data privileges.

In grants under this profile, optional `groups` MUST be an
array of nonempty strings identifying groups in the grant
issuer's namespace. These are exact identifiers, not display
names. The RAS MUST map them through tenant trust before use
in policy. They describe the subject: the agent in WAG and
the user in ID-JAG. Agent actor memberships in delegated mode
MUST come from the provisioned agent record; this profile
does not define group authorization claims inside `act`.

Grant groups are audience-filtered assertions, not a complete
directory snapshot. Absence MUST NOT imply an empty membership
set, nor may a truncated array be treated as complete. Missing
required membership evidence MUST cause the affected authorization
to fail. The trust relationship MUST designate provisioned
state or grant claims as authoritative for each membership
policy and bound its age. Conflicting sources MUST NOT be
unioned to broaden authority.

Assignments, user resource permissions, and delegation bounds
MUST be evaluated separately. Provenance, groups, and ownership
are policy inputs, not self-executing permissions. Optional
governance metadata can use {{SCIM-GOVERNANCE}}.

# Authorization Server Metadata {#metadata}

This profile uses existing {{RFC8414}} metadata and the
`authorization_grant_profiles_supported` parameter from
{{ID-JAG}}. It defines no new authorization server metadata
parameter. Roles and permitted modes are established by the
trust configuration in {{identity}}; ES256 support is required
by the profile rather than negotiated through a new field.

The IdP MUST advertise `client_credentials` and token exchange
in `grant_types_supported`, `attest_jwt_client_auth_dpop` in
`token_endpoint_auth_methods_supported`, and {{INSTANCE}}
support. The RAS MUST advertise JWT bearer grant support and
its introspection endpoint. Both MUST advertise DPoP with
`ES256`. All grant-type names use their full registered values.

The RAS MUST advertise
`urn:ietf:params:oauth:grant-profile:agent-federation` in
`authorization_grant_profiles_supported` as defined by
{{ID-JAG}}. For delegated mode it MUST also advertise ID-JAG
and Actor Profile grant support using their defined identifiers.
Delegated IdPs MUST advertise Actor Profile token-exchange
capabilities for ID Token subjects, JWT access-token actors,
and ID-JAG output. Entity-profile metadata MUST include
`ai_agent` in supported actor types. Clients MUST advertise
their applicable grant profiles and underlying grant types.
These advertisements do not authorize any issuer or client.

Example RAS metadata fragment for self-acting mode:

~~~ json
{
  "issuer": "https://as.app.example",
  "token_endpoint": "https://as.app.example/token",
  "introspection_endpoint": "https://as.app.example/introspect",
  "grant_types_supported": [
    "urn:ietf:params:oauth:grant-type:jwt-bearer"
  ],
  "dpop_signing_alg_values_supported": ["ES256"],
  "authorization_grant_profiles_supported": [
    "urn:ietf:params:oauth:grant-profile:agent-federation"
  ]
}
~~~

# Security Considerations

The requirements of {{ATTEST}}, {{INSTANCE}}, {{ID-JAG}},
{{WAG}}, {{RFC8693}}, {{RFC8725}}, and {{RFC9449}} apply to
their uses here. Delegated mode additionally applies
{{ACTOR-PROFILE}} as specified in {{actor-relationship}}.

## Binding and Substitution

The IdP MUST bind attested agent, instance, client, Agent Token,
and DPoP key together. Independently valid credentials for
different agents or instances MUST NOT be combined. Proofs
MUST be fresh for each endpoint; clients MUST NOT forward
proofs between IdP, RAS, and RS. DPoP nonce challenges MUST
be supported and replay caches MUST cover all service nodes.

Binding an access token alone does not protect a bearer grant.
This profile requires proof at both issuance and redemption,
using JWT bearer presentation with additional mandatory binding
checks. The separate grant type in {{JWT-DPOP}} is not
implicitly selected.

The IdP MUST issue grants only to a RAS configured to enforce
this profile. A RAS receiving an unsupported `agent_federation`
value MUST reject the grant, not retry as an ordinary ID-JAG
or WAG. A gateway becoming the key holder requires explicitly
authorized credential and identity mapping; forwarding another
runtime's identifier does not prove it sent the request.

## Lifecycle and Freshness {#lifecycle}

IdP and RAS MUST configure maximum ages for status, assignment,
delegation, and membership data used in issuance. Data stale
beyond those bounds MUST cause affected issuance to fail.
Disabling an agent, revoking a binding or attester, removing
an assignment, or revoking delegation MUST prevent subsequent
issuance once applied at the relevant server. An Agent Token
MUST NOT override current policy.

Disabling the local agent at the RAS MUST invalidate its active
self-acting and delegated token state; introspection MUST
report those tokens inactive. Membership or scope changes MUST
invalidate affected authority or trigger reevaluation before
an active result is returned. RS introspection caches MUST be
bounded by configured revocation delay and token expiry.

Locally validated JWT access tokens require revocation/status
propagation or remain usable until expiry. SCIM events
{{RFC9967}} can propagate changes, but receivers still need
the mapping to affected tokens and sessions. Deployments MUST
document synchronization and enforcement delay bounds and
behavior during event-stream failure.

Access tokens cannot outlive their grants, so residual access
after the last permitted grant issuance is bounded by that
grant's remaining lifetime plus accepted clock skew. Delayed
policy propagation adds its configured delay. This does not
promise immediate revocation at disconnected resource servers.

# Privacy Considerations

Stable agent identifiers permit correlation across applications.
The IdP SHOULD scope instance references to downstream trust
relationships and MUST retain an unambiguous internal mapping.
One key across IdP, RAS, and RS also permits correlation;
instances SHOULD use separate key/evidence contexts for
unrelated trust relationships while retaining agent identity.

Only needed provenance SHOULD be released. Raw platform evidence
and owner personal data SHOULD NOT appear in grants. Audit
records SHOULD identify qualified principals, instance, mode,
target, and decision; they MUST NOT contain raw credentials
or private keys.

# IANA Considerations

## JWT Claims

The following registrations are requested in the registry
established by {{RFC7519}}; the Change Controller is IETF.

| Claim Name | Description | Reference |
|---|---|---|
| `agent_id` | Attester-scoped agent principal identifier | {{agent-evidence}} |
| `agent_platform` | Agent platform implementation identifier | {{agent-evidence}} |
| `agent_model` | Agent model identifier and version | {{agent-evidence}} |
| `agent_runtime` | Runtime implementation identifier and version | {{agent-evidence}} |
| `agent_federation` | Agent federation processing profile version | {{grant}} |

The `agent_federation` marker also appears in the Agent Token
defined in {{agent-token}}, where its processing is restricted
to the IdP exchange service. It does not turn an access token
into a WAG or ID-JAG.

`client_instance` is defined by {{INSTANCE}}; `act` uses
{{ACTOR-PROFILE}}; `ai_agent` is defined by {{ENTITY-PROFILES}}.
No new actor format or Agent Token type is registered.

## Token Introspection Response

Register `agent_federation` in the registry established by
{{RFC7662}}, with description "Agent federation processing
profile version", reference {{access-tokens}}, and Change
Controller IETF.

## OAuth URI

Register `urn:ietf:params:oauth:grant-profile:agent-federation`
in the registry established by {{RFC6755}}, with Common Name
"Agent Federation Grant Profile", Change Controller IETF,
and reference {{metadata}}. WAG identifiers are addressed in
{{coordination}}.

--- back

# Interoperability Cases
{:numbered="false"}

An interoperability exercise should include independent
implementations of the platform, IdP, RAS, and RS, with the
following cases for each supported mode:

| Case | Required result |
|---|---|
| Agent restart or second replica | Same governed agent; distinct instance |
| Instance key rotation | New evidence and Agent Token; no silent rebinding |
| Self-acting exchange | Agent subject; no `act` |
| Delegated exchange | User subject; durable agent Actor Profile `act` |
| Unrelated agent token or instance proof | Reject inconsistent bindings |
| Valid user and agent credentials without delegation | `actor_unauthorized` |
| Grant replay or incorrect redemption key | Reject |
| Concurrent JIT and SCIM creation | One qualified agent record |
| Disabled agent with a still-valid credential | No new issuance or JIT reactivation |
| Delegated redemption | Preserve actor; no additional runtime hop |

Single-mode implementations need not implement cases specific
to the other mode.

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

The SCIM correlation and lifecycle requirements are proposed
bindings to {{SCIM-AGENT}}. Agent group membership is a dependency
on that proposal, not an assumed capability of all existing
SCIM implementations. Sender-bound grant processing also needs
coordination with the JWT authorization-grant work.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Reworked the initial Workload Agent Federation draft for
  self-acting and user-delegated modes using one IdP Agent Token.
* Replaced CIA with ATTEST instance identification and folded
  in vocabulary from draft-mcguinness-oauth-ai-agent-instance.
* Applied Actor Profile to delegation and added provisioning,
  resource processing, and lifecycle requirements.
