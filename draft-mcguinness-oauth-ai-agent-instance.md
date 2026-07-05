---
title: "OAuth 2.0 AI Agent Instance Profile"
abbrev: "oauth-ai-agent-instance"
category: std

docname: draft-mcguinness-oauth-ai-agent-instance-latest
submissiontype: IETF
stand_alone: yes
date: 2026-07-04
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
keyword:
 - OAuth
 - AI agent
 - agent identity
 - client instance
 - attestation

venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "mcguinness/draft-mcguinness-oauth-client-instance-assertion"
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-ai-agent-instance.html"

author:
 -
    fullname: Karl McGuinness
    organization: Independent
    email: public@karlmcguinness.com

normative:
  RFC6749:
  RFC7519:
  RFC7591:
  RFC8414:
  RFC8693:
  RFC9449:
  RFC9711:
  ATTEST-CLIENT-AUTH: I-D.ietf-oauth-attestation-based-client-auth
  CIA-CORE: I-D.mcguinness-oauth-client-instance-assertion
  ENTITY-PROFILES: I-D.mora-oauth-entity-profiles

informative:
  RFC7636:
  RFC9396:
  TXN-TOKENS: I-D.ietf-oauth-transaction-tokens
  ID-CHAINING: I-D.ietf-oauth-identity-chaining
  MCP:
    title: "Model Context Protocol Specification"
    target: https://modelcontextprotocol.io/specification/
    author:
      org: Anthropic
    date: 2025

--- abstract

This specification profiles the OAuth 2.0 Client Instance Assertion
for AI agent deployments, where a single OAuth client identifier
represents an agent platform running many concurrent agent
instances. It defines claims that convey an attested agent instance
identifier and agent provenance (platform, model, runtime
environment) from an agent attester to the authorization server,
rules for surfacing that identity in issued access tokens, and
delegation-chain semantics for agents that spawn sub-agents. The
claims are carrier-independent: they may be conveyed in a Client
Instance Assertion or in a Client Attestation defined by OAuth 2.0
Attestation-Based Client Authentication.

--- middle

# Introduction

AI agent platforms are OAuth clients. A platform registers a single
`client_id` and then runs many concurrent agent instances under it:
one per user session, task, or delegated workflow. Resource servers
receiving access tokens from these platforms see only the
platform's `client_id`; this includes Model Context Protocol
servers ({{MCP}}), which use OAuth for authorization. Every agent
session collapses into one identity, defeating per-agent
authorization, audit attribution, incident response, and abuse
containment.

The OAuth 2.0 Client Instance Assertion specification {{CIA-CORE}}
defines the general mechanism this profile builds on: a client
instance proves its identity to the authorization server (AS) at
the token endpoint, and the validated instance identity surfaces in
the issued access token as `act.sub` (when the agent acts on a
user's or another principal's behalf) or top-level `sub` (when the
agent acts as itself), sender-constrained to a key the instance
holds.

This profile adds what agent deployments need beyond a bare
instance identifier:

* **A stable, attester-minted agent instance identifier**
  ({{agent-claims}}). The instance subject is an identifier the
  agent attester mints for the agent session rather than a key
  thumbprint, so it survives key rotation and names something an
  audit record can act on.
* **Attested agent provenance** ({{agent-claims}}): optional claims
  conveying the agent platform, the model an agent instance runs,
  and evidence about its runtime environment, so resource servers
  can apply provenance-aware policy.
* **A registered actor profile** (`ai_agent`) so resource servers
  can distinguish agent actors from other workload actors with a
  single signal ({{surfacing}}).
* **Attested delegation chains** ({{chains}}): when an agent
  spawns a sub-agent, each hop presents its own instance evidence,
  producing an `act` chain in which every actor was attested rather
  than merely asserted.

The claims defined here are carrier-independent ({{carriers}}).
Workload-style deployments convey them in a Client Instance
Assertion per {{CIA-CORE}}; deployments using OAuth 2.0
Attestation-Based Client Authentication {{ATTEST-CLIENT-AUTH}}
convey them in the Client Attestation. The claims, the subject
derivation, and the access-token surfacing are identical in both
cases.

This profile does not define agent capability or tool-permission
semantics; deployments expressing fine-grained agent permissions
compose this profile with Rich Authorization Requests ({{RFC9396}})
or deployment-specific scope design.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

This document uses the terms "Client Instance Assertion", "client
instance", "instance issuer", and "OAuth client" as defined in
{{CIA-CORE}}, and "Client Attestation" and "DPoP combined mode" as
defined in {{ATTEST-CLIENT-AUTH}}.

Agent:
: An autonomous or semi-autonomous software actor, typically driven
  by a machine-learning model, that performs tasks by calling APIs,
  optionally on behalf of a user or another principal.

Agent Platform:
: The OAuth client under which agent instances run. The platform
  holds the client registration and operates the control plane that
  spawns, supervises, and terminates agent instances.

Agent Instance:
: A client instance ({{CIA-CORE}}) that is an agent: a specific
  agent session, task execution, or runtime.

Agent Attester:
: The authority that authenticates agent instances and mints the
  agent instance claims defined in {{agent-claims}}. Depending on
  the carrier ({{carriers}}), the Agent Attester is a {{CIA-CORE}}
  instance issuer or an {{ATTEST-CLIENT-AUTH}} Attester. It is
  typically the agent platform's control plane, but MAY be a
  distinct party (see {{trust}}).

Agent Instance Evidence:
: The carrier artifact conveying the agent instance claims of
  {{agent-claims}} to the AS: either a Client Instance Assertion,
  or a Client Attestation with its proof of possession.

# Relationship to Other Specifications {#relationships}

This profile depends normatively on {{CIA-CORE}} for token-endpoint
processing, sender-constraint binding, access-token representation,
refresh-token semantics, and resource-server processing. It
registers the `ai_agent` actor profile in the registry established
by {{ENTITY-PROFILES}}. When the Client Attestation carrier is
used, it depends on {{ATTEST-CLIENT-AUTH}} for attestation
validation, including DPoP combined mode ({{RFC9449}}).

Delegation-chain construction follows the `act` semantics of
{{RFC8693}} as profiled by {{CIA-CORE}}.

Runtime-environment evidence is conveyed using the Entity
Attestation Token ({{RFC9711}}) via the `agent_runtime` claim
({{agent-claims}}); this profile does not define an evidence
format of its own.

Transaction Tokens ({{TXN-TOKENS}}) address propagation of
immutable context across workloads within a trust domain after
initial authorization; this profile addresses agent instance
identity at initial token issuance. The two are complementary: a
deployment may derive transaction tokens from access tokens issued
under this profile, carrying the agent instance identity into the
transaction context.

Identity and authorization chaining ({{ID-CHAINING}}) enables an
authorization server in one domain to issue tokens redeemable in
another, the pattern underlying enterprise cross-application
access deployments in which an enterprise identity provider
brokers agent access to third-party resources. That work moves
identity across domains; it does not define agent claims. The two
compose naturally: an authorization server applying this profile
at issuance carries the agent instance identity and provenance
into the chained tokens it brokers.

Agent identity is an active topic in multiple communities. This
profile deliberately limits itself to two things: conveying
attested agent instance identity and provenance to the OAuth token
endpoint, and representing that identity in issued access tokens.
It does not define agent-to-agent authentication protocols, agent
discovery, capability or tool description, or model governance,
and is designed to compose with, rather than compete with,
specifications that do. In particular, fine-grained permission
description composes via Rich Authorization Requests
({{RFC9396}}), and hardware-rooted runtime evidence composes via
Entity Attestation Token formats ({{RFC9711}}).

# Agent Instance Claims {#agent-claims}

The following claims are conveyed in the Agent Instance Evidence
by the Agent Attester. Claim names are registered in the JSON Web
Token Claims registry ({{iana-claims}}). The claims are validated
by the AS as part of carrier validation ({{carriers}}); unknown
members within object-valued claims MUST be ignored unless a
profile of this document defines their processing.

`agent_instance_id` (REQUIRED):
: A StringOrURI ({{RFC7519}}) identifying this agent instance,
  minted by the Agent Attester. The value MUST be unique among all
  instances attested by this Attester (across every OAuth client
  the Attester serves, so that resource servers evaluating the
  identifier need not qualify it by `client_id`) and MUST be
  stable for the lifetime of the agent instance. The value
  MUST NOT be derived from a proof-of-possession key: keys are
  binding material, not identity ({{subject}}). The Attester MUST
  NOT reassign an active or audit-relevant value to a different
  instance; see {{security-lifecycle}}. Attesters SHOULD mint
  URI-shaped values within a namespace they control (for example,
  `https://attester.example.com/instances/sess-9f2c`), which makes
  the minting authority evident to consumers of the identifier.

`agent_platform` (OPTIONAL):
: A StringOrURI identifying the agent platform or orchestration
  runtime under which the instance executes (for example, an
  identifier naming the orchestrator product and its major
  version). The value identifies software operated by the Agent
  Platform, not the OAuth client identity, which continues to be
  conveyed by `client_id`.

`agent_model` (OPTIONAL):
: A JSON object characterizing the primary model configured for
  the agent instance, as determined by the Agent Attester at
  evidence issuance. The object contains an `id` member (REQUIRED,
  a StringOrURI model identifier) and MAY contain a `version`
  member (a string). The claim describes the instance's
  configuration, not each individual operation: an agent instance
  may route individual operations to other models (for example,
  routing, fallback, or auxiliary models) without invalidating the
  claim. A change to the primary configured model, however, means
  previously issued evidence no longer describes the instance, and
  the Attester MUST issue fresh evidence before the instance
  obtains further tokens under this profile
  ({{security-freshness}}). A registry of model identifiers is out
  of scope; `agent_model.id` interoperability is an agreement
  between the Attester and the resource servers that consume it.

`agent_runtime` (OPTIONAL):
: A JSON object conveying evidence about the runtime environment of
  the agent instance, such as confidential-computing or
  trusted-execution attestation results. This document defines one
  member: `eat` (OPTIONAL), containing an Entity Attestation Token
  ({{RFC9711}}), carried as the JWT compact serialization when the
  EAT is in JWT form or base64url-encoded when in CWT form. The two
  forms are distinguishable by structure: a JWT compact
  serialization contains period separators, while a
  base64url-encoded CWT does not. Additional
  members MAY be defined by deployments or companion profiles;
  unknown members MUST be ignored. `agent_runtime` is consumed by
  the AS for policy and is not surfaced to resource servers by
  default ({{surfacing}}).

An AS that receives Agent Instance Evidence for a client
registered for this profile ({{metadata}}) MUST reject evidence
that omits `agent_instance_id` ({{errors}}). Evidence whose
object-valued claims are malformed (for example, `agent_model`
without an `id` member) MUST be rejected the same way.

# Evidence Carriers {#carriers}

The claims in {{agent-claims}} are carried in exactly one of the
following artifacts per token request. The claims, their
validation, and all downstream processing are identical regardless
of carrier.

## Client Instance Assertion Carrier {#carrier-cia}

The Agent Attester acts as a {{CIA-CORE}} instance issuer and
includes the claims of {{agent-claims}} in the Client Instance
Assertion. All {{CIA-CORE}} requirements for assertion format,
presentation, and validation apply unchanged, including the
`(iss, jti)` replay check and sender-constraint verification.

The assertion's `sub` MUST equal the `agent_instance_id` value;
the AS MUST reject an assertion where the two differ. The
assertion's `sub_profile` SHOULD include the value `ai_agent`;
regardless of what the evidence carries, surfacing follows
{{surfacing}}.

This carrier suits workload-style agent platforms that operate (or
integrate with) an instance issuer, and inherits {{CIA-CORE}}'s
per-client trust delegation: the platform's client metadata lists
the Agent Attester in `instance_issuers`, bounding which authority
may attest its instances.

## Client Attestation Carrier {#carrier-attest}

The Agent Attester acts as an {{ATTEST-CLIENT-AUTH}} Attester and
includes the claims of {{agent-claims}} in the Client Attestation
JWT. The client authenticates per {{ATTEST-CLIENT-AUTH}} using
DPoP combined mode; the DPoP key is the instance binding key for
{{CIA-CORE}}'s sender-constraint requirement, and the issued
access token MUST be DPoP-bound to that key.

Because the Client Attestation's `sub` names the OAuth client
under {{ATTEST-CLIENT-AUTH}}, the instance subject on this carrier
comes exclusively from the `agent_instance_id` claim.

Applying this carrier changes the shape of the client's issued
access tokens. Whether the AS applies it for a given client is
established through the client's registered metadata
({{metadata}}) or by out-of-band agreement; an AS MUST NOT apply
it to a client that has not agreed to receive instance
representation in its tokens.

This carrier is available on the grants covered by
{{CIA-CORE}}'s access-token classification (`authorization_code`,
`client_credentials`, `refresh_token`, JWT bearer, and
token-exchange); grants outside that classification are refused
per {{CIA-CORE}}. Because this carrier presents no request
parameter, its activation (per the client's profile registration)
substitutes for {{CIA-CORE}}'s parameter-presence trigger: on
token-exchange in particular, it applies even when no
`actor_token` is present.

The {{CIA-CORE}} validation steps that depend on a presented
assertion (token-type matching, descriptor lookup, signature
verification, claim validation, `client_id` binding, and replay
checking) are satisfied on this carrier by the completed
{{ATTEST-CLIENT-AUTH}} validation together with the claim
requirements of {{agent-claims}}. Replay protection is provided by
{{ATTEST-CLIENT-AUTH}} validation, including the DPoP proof
freshness rules of {{RFC9449}}; {{CIA-CORE}}'s `(iss, jti)`
replay cache does not apply because no Client Instance Assertion
is presented. Trust for this carrier is the AS-to-Attester trust
of {{ATTEST-CLIENT-AUTH}}; {{CIA-CORE}}'s `instance_issuers`
metadata is not consulted.

For delegation cases on this carrier, the AS MUST set `act.iss` to
the issuer identifier of the validated Client Attestation JWT. For
self-acting cases, the Attester issuer is not represented as a
standard access-token claim; the AS MUST retain it with token
state for revocation, introspection, audit, and issuer-aware
resource-server policy; in particular, per-instance revocation
keyed on the issuer-and-subject pair per {{CIA-CORE}} depends on
it.

## Carrier Precedence {#carrier-precedence}

A token request that presents a Client Instance Assertion while
also authenticating via {{ATTEST-CLIENT-AUTH}} uses the Client
Instance Assertion as the Agent Instance Evidence: its claims are
authoritative for instance identity and provenance. To ensure the
two artifacts describe the same instance, the AS MUST verify that
the assertion's `cnf` binding key and the DPoP key matched against
the Client Attestation's `cnf` identify the same key material (for
`cnf.jkt`, thumbprint equality); if they differ, the AS MUST
reject the request with `invalid_grant`. If both artifacts carry
`agent_instance_id`, the values MUST be equal; the AS MUST reject
the request with `invalid_grant` otherwise.

# Client and Authorization Server Metadata {#metadata}

This document defines one client metadata parameter (registered
per {{RFC7591}}, applicable to any registration model supported by
{{CIA-CORE}}) and one authorization server metadata parameter
(registered per {{RFC8414}}):

`ai_agent_instance_profile` (client metadata):
: OPTIONAL. Boolean, default `false`. When `true`, the client is
  registered for this profile. The AS MUST require Agent Instance
  Evidence on every token request from the client on the grants
  covered by {{CIA-CORE}}'s access-token classification, except
  `refresh_token` requests, which follow {{refresh}}; a covered
  request presenting no evidence MUST be rejected ({{errors}}).
  Without this requirement, an instance could omit evidence and
  obtain tokens indistinguishable from an ordinary client's,
  silently escaping the attribution this profile provides. The
  client's registration or AS policy MAY exempt designated grant
  types whose requests are not made by agent instances (for
  example, `client_credentials` used by the platform's control
  plane); exempted requests are processed as ordinary OAuth
  requests and receive no instance representation. The AS MUST
  require `agent_instance_id` in the client's Agent Instance
  Evidence ({{agent-claims}}) and MUST apply the surfacing rules
  of {{surfacing}}; when the Client Attestation carrier is used,
  this registration constitutes the client's agreement required by
  {{carrier-attest}}. Deployments without access to
  this parameter MAY establish the same registration by
  out-of-band agreement.

`ai_agent_instance_profile_supported` (AS metadata):
: OPTIONAL. Boolean. Indicates that the AS supports this profile:
  validating agent instance claims, deriving the instance subject
  per {{subject}}, and surfacing per {{surfacing}}. An AS
  implementing this profile MUST include this parameter, set to
  `true`, in any authorization server metadata it publishes.
  Clients SHOULD verify it before depending on agent
  instance surfacing, since an AS without support may process the
  underlying carrier without applying this profile's
  representation.

# Instance Subject Derivation {#subject}

The instance subject used for access-token surfacing is the
`agent_instance_id` value, scoped to the Agent Attester that
minted it. The AS MUST NOT derive the instance subject from a
proof-of-possession key thumbprint: keys are binding material, not
identity, and key rotation MUST NOT change the agent instance's
identity. Consumers needing key-level correlation can use the
access token's `cnf` confirmation claim directly.

Because the subject is Attester-minted and key-independent:

* the identity is stable across DPoP or binding-key rotation
  within an instance's lifetime: access tokens obtained with a
  rotated key carry the same instance subject, so resource-server
  policy state and audit trails keyed on the subject survive
  rotation ({{refresh}} covers the refresh-token interaction);
* audit records name an identifier the Agent Attester can resolve
  to session context, rather than an opaque key fingerprint.

When a client lists multiple Agent Attesters, the subject-collision
requirements of {{CIA-CORE}} apply: the client MUST ensure the
Attesters' `agent_instance_id` spaces do not collide. Attesters
that follow the URI-shaped minting recommendation of
{{agent-claims}} satisfy this structurally, since each mints within
a namespace it controls.

# Access Token Surfacing {#surfacing}

Access-token representation follows {{CIA-CORE}}: the instance
subject appears as `act.sub` in delegation cases and as top-level
`sub` in self-acting cases, and the issued access token is
sender-constrained per {{CIA-CORE}}.

This profile additionally specifies:

* The surfaced `sub_profile` (top-level in self-acting cases,
  `act.sub_profile` in delegation cases) MUST include both the
  value `ai_agent` ({{iana-entity-profile}}) and the value
  `client_instance` (registered by {{CIA-CORE}}), per the list
  syntax of the underlying registry. Every agent instance is a
  client instance; including both values lets resource servers
  that implement {{CIA-CORE}} but not this profile continue to
  classify the actor correctly. Other applicable registered
  values MAY additionally be included.
* The AS MAY surface `agent_platform` and `agent_model` subject to
  local policy and the privacy considerations of
  {{security-privacy}}. Surfaced provenance claims appear within
  the `act` object in delegation cases (they describe the actor)
  and at top level in self-acting cases (the instance is the
  subject). An AS MUST NOT surface provenance claims that were not
  present in validated Agent Instance Evidence.
* `agent_runtime` evidence is consumed by the AS for policy and
  MUST NOT be surfaced to resource servers verbatim. Deployments
  that expose a runtime-assurance signal to resource servers
  SHOULD surface a coarse assurance tier ({{trust}}) via a
  deployment-defined claim rather than raw evidence.

For opaque (reference) access tokens, the same surfaced claims
appear in introspection responses, per {{CIA-CORE}}'s
introspection requirements.

# Attested Delegation Chains {#chains}

When an agent instance spawns a sub-agent that requires its own
access token, the sub-agent obtains it via token exchange
({{RFC8693}}) using {{CIA-CORE}}'s token-exchange presentation,
presenting its own Agent Instance Evidence (either carrier). The
resulting `act` chain nests the spawning agent's actor entry per
{{CIA-CORE}}'s chain merging, and scope attenuation at each
exchange follows {{RFC8693}}.

Whether a given instance is permitted to perform such an exchange
is AS authorization policy under {{RFC8693}} and {{CIA-CORE}};
this profile defines no separate spawn-permission mechanism.
Because chain merging preserves the spawning agent's entry,
spawning cannot be used to shed identity: a compromised instance
that spawns sub-agents remains visible in every descendant chain.

The property this profile targets: every actor entry the AS
introduces into a chain corresponds to an instance that presented
Agent Instance Evidence at the hop where it was introduced. An AS
MUST NOT introduce an actor entry for an agent instance that did
not present such evidence. Inner actor entries preserved verbatim
from a `subject_token` were attested at the hop (and by the AS)
that introduced them; the attested-at-every-hop property
therefore spans exactly the hops processed under this profile.

Chains that cross agent platforms or authorization servers (a
sub-agent running on a different platform, under a different
OAuth client, possibly at a different AS) compose through
cross-domain token exchange and are governed by the trust and
federation policy of the domains involved; this profile defines
no additional cross-domain rules.

# Refresh Tokens {#refresh}

Refresh-token handling follows {{CIA-CORE}}, with the derived
instance subject, the Agent Attester, and any surfaced provenance
claims recorded as originating instance state. Fresh Agent
Instance Evidence presented on refresh MUST be issued by the same
Agent Attester and carry the same `agent_instance_id` recorded at
original issuance; the AS MUST reject a refresh presenting
evidence from a different Attester or for a different instance
with `invalid_grant`. A refresh processed without fresh evidence
re-surfaces the provenance recorded at original issuance; see
{{security-freshness}} for the staleness this implies across
refresh chains.

Refresh tokens remain bound to the binding key present at their
issuance, per {{CIA-CORE}}; this profile does not relax that
binding. An instance that rotates its binding key (for example,
after migrating between nodes) therefore cannot use a
previously issued refresh token with the new key; it obtains new
tokens through a fresh grant or token exchange, presenting fresh
evidence that carries its unchanged `agent_instance_id`. The
instance's identity, and everything resource servers key on it,
is unaffected by the rotation ({{subject}}).

# Trust Model and Assurance Tiers {#trust}

The strength of agent instance claims depends on who the Agent
Attester is relative to the agent platform:

Platform self-attestation:
: The Attester is the agent platform's own control plane. The
  claims reflect the platform's internal bookkeeping; assurance
  rests on organizational separation between the control plane and
  the agent runtime, comparable to a workload identity provider
  attesting its own workloads.

Hardware-rooted attestation:
: The Attester incorporates evidence from a trusted-execution or
  confidential-computing environment (conveyed via
  `agent_runtime`, aligned with {{RFC9711}}). Claims about the
  runtime are rooted in hardware rather than platform assertion.

Independent attestation:
: The Attester is a party distinct from the platform operator (for
  example, an enterprise attesting agent instances it runs on a
  third-party platform). Claims reflect a trust relationship
  independent of the platform.

Authorization servers and resource servers MAY condition policy on
the tier. Deployments SHOULD document which tier their Attester
provides and MUST NOT represent platform self-attestation as
hardware-rooted or independent attestation.

# Local and Public-Client Agent Instances {#local-agents}

Agent instances do not necessarily run on platform
infrastructure: command-line and desktop agents execute on
end-user machines, typically as public clients ({{RFC6749}}) using
the `authorization_code` grant with PKCE ({{RFC7636}}) and without
a client-level credential. This profile applies to such
deployments with the following pattern:

* The local agent instance generates its per-instance
  proof-of-possession key locally and authenticates to the agent
  platform's control plane (how is out of scope; typically the
  user's platform login). The control plane, acting as the Agent
  Attester, mints Agent Instance Evidence whose `cnf` binds the
  key the local instance presented and whose `agent_instance_id`
  names the local session.
* The instance presents the evidence at the token endpoint per
  the Client Instance Assertion carrier ({{carrier-cia}})
  alongside its normal public-client interaction. Presenting a
  Client Instance Assertion does not require confidential-client
  authentication; only {{CIA-CORE}}'s instance-assertion
  authentication method does, and public clients do not use that
  method.
* The issued access token is sender-constrained to the locally
  held key per {{CIA-CORE}}, and the instance subject, surfacing,
  and chain semantics of this profile apply unchanged.

Attestation of a local session is platform self-attestation
({{trust}}) with a narrower meaning: the Attester vouches that it
issued the session to an authenticated platform account and bound
the presented key, not for the integrity of the end-user host the
instance runs on. Resource servers applying tier-conditioned
policy SHOULD treat locally executing instances accordingly;
deployments needing runtime-integrity claims for local instances
can convey hardware-rooted evidence from the host via
`agent_runtime` ({{agent-claims}}) where available.

# Error Responses {#errors}

Errors are returned per {{RFC6749}} Section 5.2, inheriting the
error taxonomy of {{CIA-CORE}} and, on the Client Attestation
carrier, of {{ATTEST-CLIENT-AUTH}}. This profile adds the
following `invalid_grant` cases (returned as `invalid_client`
when, per {{CIA-CORE}}, the evidence is the client authentication
credential):

* a token request on a covered grant other than `refresh_token`
  presents no Agent Instance Evidence, and neither the client's
  registration nor AS policy exempts the grant type
  ({{metadata}});
* the Agent Instance Evidence omits `agent_instance_id` and the
  client is registered for this profile ({{metadata}});
* an object-valued agent claim is malformed
  ({{agent-claims}});
* on the Client Instance Assertion carrier, the assertion's `sub`
  does not equal `agent_instance_id` ({{carrier-cia}});
* under carrier precedence, the binding keys or
  `agent_instance_id` values of the two artifacts do not match
  ({{carrier-precedence}});
* on refresh, presented evidence is issued by a different Agent
  Attester or carries a different `agent_instance_id` than
  recorded at original issuance ({{refresh}}).

# Conformance {#conformance}

An AS conforms to this profile by supporting at least one evidence
carrier ({{carriers}}); requiring evidence from registered clients
per {{metadata}}; validating the agent instance claims per
{{agent-claims}}; deriving the instance subject per {{subject}};
surfacing per {{surfacing}}, including the `ai_agent` and
`client_instance` values in the surfaced `sub_profile`; applying
the refresh rules of {{refresh}};
applying carrier precedence ({{carrier-precedence}}) when both
artifacts are presented; and advertising support via
`ai_agent_instance_profile_supported` ({{metadata}}). An AS
supporting the Client Instance Assertion carrier conforms to
{{CIA-CORE}}; an AS supporting the Client Attestation carrier
conforms to {{ATTEST-CLIENT-AUTH}} and to the activation-policy
requirement of {{carrier-attest}}.

An Agent Attester conforms by meeting the minting requirements of
{{agent-claims}} (in particular the uniqueness, stability,
non-reassignment, and key-independence of `agent_instance_id`)
and, per carrier, the obligations of a {{CIA-CORE}} instance
issuer or an {{ATTEST-CLIENT-AUTH}} Attester.

An Agent Platform (OAuth client) conforms by registering for this
profile ({{metadata}}) and for exactly the carriers it uses,
listing its Agent Attester per {{carrier-cia}} where applicable,
and ensuring the Attester is authorized to attest its instances.

A resource server conforms by processing delegated and self-acting
tokens per {{CIA-CORE}}'s resource-server rules, treating actors
whose `sub_profile` includes `ai_agent` as agent instances, and
treating surfaced provenance claims subject to the assurance-tier
considerations of {{trust}} and {{security-provenance}}.

# Security Considerations {#security}

This document inherits the security considerations of {{CIA-CORE}}
and, when the Client Attestation carrier is used,
{{ATTEST-CLIENT-AUTH}} and {{RFC9449}}.

## Attestation Freshness and Model Drift {#security-freshness}

Agent Instance Evidence describes the instance as of evidence
issuance. The claim most exposed to drift is `agent_model`: a
platform that hot-swaps or upgrades the model serving a session
invalidates previously issued evidence. {{agent-claims}} requires
fresh evidence after a model change, but the AS cannot detect a
violation in-band; resource servers applying model-version policy
are trusting the Attester's issuance discipline.

On the Client Instance Assertion carrier, {{CIA-CORE}}'s short
assertion lifetimes bound the drift window. On the Client
Attestation carrier, the window is bounded by the Client
Attestation's lifetime, which some Attester ecosystems set to
hours or days, plus DPoP proof freshness; the DPoP proof
establishes recent possession of the bound key, not recent
Attester endorsement. Deployments requiring current provenance
SHOULD use short-lived evidence and SHOULD require fresh evidence
on refresh rather than permitting refresh from stored originating
instance state.

Surfaced provenance is additionally static for the lifetime of
each issued access token: a token surfacing `agent_model` remains
valid after the platform upgrades the instance's primary model,
until the token expires. Refresh processed from stored originating
state ({{refresh}}) extends this window across the refresh-token
lifetime. Resource servers gating sensitive operations on
provenance SHOULD account for the access-token TTL in their policy
assumptions, and ASes serving such resource servers SHOULD keep
access-token lifetimes short relative to the deployment's model
upgrade cadence.

## Instance Identifier Lifecycle {#security-lifecycle}

The value of `agent_instance_id` to audit and containment depends
on the Attester honoring its minting obligations
({{agent-claims}}). An Attester that reassigns an identifier to a
different instance destroys audit attribution and can redirect
per-instance policy (including revocation) at the resource server
and AS. An Attester that mints one identifier for many instances
(for example, a pool identifier) silently collapses per-agent
containment back to the aggregate. These obligations are
operational: the AS verifies the evidence signature and claims but
cannot verify in-band that the Attester's minting practice is
sound. Clients SHOULD list only Attesters whose practices they
have audited, mirroring {{CIA-CORE}}'s issuer-trust guidance.

## Provenance Assurance {#security-provenance}

`agent_platform`, `agent_model`, and `agent_runtime` are only as
trustworthy as the Attester tier that produced them ({{trust}}).
Under platform self-attestation, a model claim is the platform's
statement about itself; resource servers MUST NOT treat it as
independently verified. Policy that gates sensitive operations on
provenance (for example, minimum model version) SHOULD take the
assurance tier into account, and deployments needing verifiable
runtime claims SHOULD use hardware-rooted attestation via
`agent_runtime` and {{RFC9711}}-aligned evidence.

## Shared Trust Root on the Client Attestation Carrier {#security-shared-root}

On the Client Attestation carrier, the AS-to-Attester trust that
authenticates the client also underpins the instance identity and
provenance surfaced to resource servers. Compromise of the
Attester's signing key therefore affects client authentication,
instance identity, and provenance simultaneously. Operators SHOULD
evaluate Attester key custody and rotation accordingly and ensure
incident response covers access-token revocation for all three.

## Carrier Trust Asymmetry {#security-carrier-asymmetry}

The two carriers place control over the Attester set with
different parties. On the Client Instance Assertion carrier, the
*client* controls which authorities may attest its instances, by
listing them in its `instance_issuers` metadata ({{carrier-cia}});
the AS accepts only Attesters the client has endorsed. On the
Client Attestation carrier, Attester trust is AS-configured
({{carrier-attest}}); the client has no in-band mechanism to bound
which Attesters the AS will accept for it, and a
mistakenly-trusted or compromised Attester at the AS can mint
agent identities under the client's `client_id` without any
client-published endorsement being violated.

The same claims therefore arrive under two different trust models
depending on carrier. The registration-time agreement required by
{{carrier-attest}} is the client's control point on the
attestation carrier: clients SHOULD establish the acceptable
Attester set as part of that agreement. Deployments in which the
client requires in-band, auditable control over its attestation
surface SHOULD use the Client Instance Assertion carrier.

## Attester Trust via Dynamic Registration {#security-dcr}

In deployments where clients register dynamically ({{RFC7591}}),
including agent applications registering with an authorization
server discovered at run time, the `instance_issuers` list and the
`ai_agent_instance_profile` flag arrive as registration metadata
from a party the AS has no prior relationship with. An
unauthenticated registrant naming an Attester it controls gains
nothing against other clients (the Attester attests only that
client's instances), but the AS is nonetheless accepting a trust
root and a token-shape obligation from an unvetted source.

An AS accepting dynamic registration SHOULD NOT honor
`instance_issuers` entries from unauthenticated registrations
unless each listed Agent Attester is validated against AS policy,
for example an AS-side allowlist of recognized platform Attesters,
or a signed software statement ({{RFC7591}}) from an authority the
AS trusts. The `ai_agent_instance_profile` flag on a registration
listing no `instance_issuers` implicates the Client Attestation
carrier, whose Attester trust is AS-configured
({{carrier-attest}}); honoring the flag there accepts a
token-shape obligation but no new trust root. AS-operated
allowlists of well-known agent platform Attesters are the expected
deployment pattern for resource ecosystems serving dynamically
registered agent clients.

## Local Instance Keys and Evidence Minting {#security-local-keys}

For locally executing instances ({{local-agents}}), the instance
binding key is held on an end-user machine rather than on platform
infrastructure. A process that extracts the key and current
evidence can act as the instance until they expire. Local
instances SHOULD generate and hold binding keys in a platform
keystore or hardware-backed key store where the host provides one,
and Attesters SHOULD issue short-lived evidence to locally
executing instances.

The Attester's evidence-minting interface is part of the identity
boundary: whoever can authenticate to it obtains evidence binding
a key they control, so possession of a user's platform credentials
suffices to mint agent instances attributed to that account.
Attesters SHOULD bind evidence minting to the authenticated
session through which the instance was established, SHOULD audit
minting events with the same rigor as token issuance, and SHOULD
rate-limit minting per account.

## Privacy {#security-privacy}

Agent provenance claims reveal implementation details
(orchestrator, model identity and version, and indirectly the
platform's upgrade cadence) to every resource server that
receives them. Surfacing is therefore selective ({{surfacing}}):
the AS surfaces only what local policy requires, and
`agent_runtime` evidence is never surfaced verbatim.

`agent_instance_id` is a per-instance identifier linkable across
every request the instance makes for its lifetime. Platforms
SHOULD scope instance lifetimes to the task or session they
represent; long-lived instances accumulate long linkable
histories at every resource server they touch. Where instances
act on behalf of users, the identifier's granularity SHOULD NOT be
chosen such that it becomes a stable pseudonym for the user across
contexts the user would consider separate.

## Scope of Protection {#security-scope}

Instance identity supports attribution, per-agent policy, and
containment; it does not constrain what a compromised or
prompt-injected agent does within the scope it was granted. An
attested chain records which instance acted; it does not make
the action safe. Least-privilege composition (scope design,
{{RFC9396}} authorization details, per-exchange attenuation as in
{{chains}}) remains the containment mechanism; this profile makes
its enforcement and audit per-agent rather than per-platform.

Similarly, the `ai_agent` classification is a policy-routing
signal whose membership is determined by the Agent Attester; this
profile defines no test for what constitutes an agent, and the
boundary (autonomous agent versus script versus assistive tool) is
inherently a judgment of the attesting party. Resource servers
MUST NOT derive security guarantees from the classification
itself, as distinct from the attested identity and provenance
that accompany it.

# IANA Considerations {#iana}

## JSON Web Token Claims Registration {#iana-claims}

IANA is requested to register the following claims in the "JSON
Web Token Claims" registry established by {{RFC7519}}.

### agent_instance_id

Claim Name:
: `agent_instance_id`

Claim Description:
: Attester-minted identifier of an AI agent instance

Change Controller:
: IETF

Specification Document(s):
: {{agent-claims}} of this document

### agent_platform

Claim Name:
: `agent_platform`

Claim Description:
: Identifier of the agent platform or orchestration runtime of an
  AI agent instance

Change Controller:
: IETF

Specification Document(s):
: {{agent-claims}} of this document

### agent_model

Claim Name:
: `agent_model`

Claim Description:
: Model identifier and version an AI agent instance is operating
  with

Change Controller:
: IETF

Specification Document(s):
: {{agent-claims}} of this document

### agent_runtime

Claim Name:
: `agent_runtime`

Claim Description:
: Runtime-environment evidence for an AI agent instance

Change Controller:
: IETF

Specification Document(s):
: {{agent-claims}} of this document

## OAuth Dynamic Client Registration Metadata {#iana-client-metadata}

IANA is requested to register the following parameter in the
"OAuth Dynamic Client Registration Metadata" registry established
by {{RFC7591}}.

Client Metadata Name:
: `ai_agent_instance_profile`

Client Metadata Description:
: Boolean indicating that the client is registered for the OAuth
  2.0 AI Agent Instance Profile

Change Controller:
: IETF

Specification Document(s):
: {{metadata}} of this document

## OAuth Authorization Server Metadata {#iana-as-metadata}

IANA is requested to register the following parameter in the
"OAuth Authorization Server Metadata" registry established by
{{RFC8414}}.

Metadata Name:
: `ai_agent_instance_profile_supported`

Metadata Description:
: Boolean indicating authorization server support for the OAuth
  2.0 AI Agent Instance Profile

Change Controller:
: IETF

Specification Document(s):
: {{metadata}} of this document

## OAuth Entity Profile {#iana-entity-profile}

IANA is requested to register the following value in the "OAuth
Entity Profiles" registry established by {{ENTITY-PROFILES}}. This
registration is contingent on the establishment of that registry.

Entity Profile Name:
: `ai_agent`

Entity Profile Description:
: An AI agent instance: an autonomous or semi-autonomous software
  actor, typically driven by a machine-learning model, acting as a
  concrete runtime instance of an OAuth client.

Usage Location:
: "Subject Profile", "Actor Profile"

Change Controller:
: IETF

Specification Document:
: This document

--- back

# Design Rationale {#design-rationale}
{:numbered="false"}

This appendix records design choices that motivated the normative
text.

## Why Attester-minted identifiers rather than key-derived subjects
{:numbered="false"}

Deriving the instance subject from a proof-of-possession key
thumbprint is superficially attractive, since it requires no
minting infrastructure, but fails as identity. A key thumbprint carries
no semantic content an audit record or policy can act on; key
rotation silently mints a new actor, orphaning audit trails and
resource-server policy state at exactly the moments (migration,
key hygiene) rotation is routine; and key-level correlation is
already available to every consumer via the access token's `cnf`
confirmation claim, so a thumbprint-shaped subject adds no
information. This profile therefore requires an Attester-minted,
key-independent identifier and forbids key-derived subjects
({{subject}}).

## Why carrier-pluggable
{:numbered="false"}

The interoperable surface of this profile is the claims, the
subject derivation, and the token surfacing, not the transport
that conveys the claims to the AS. Workload-style agent platforms
already operate instance issuers and fit {{CIA-CORE}}'s assertion
carrier; platforms in ecosystems deploying
{{ATTEST-CLIENT-AUTH}} already present Client Attestations and
should not need a second artifact carrying the same facts. Binding
the agent claims to a single carrier would fragment the profile by
deployment style without any interoperability gain.

## Why flat claims rather than one structured agent claim
{:numbered="false"}

A single structured `agent` claim object was considered. Flat
claims were chosen because individual JWT claim registrations are
the established practice of the JWT Claims registry, selective
surfacing ({{surfacing}}) operates naturally per claim, and
consumers can adopt `agent_instance_id` without parsing a
container whose other members they ignore. The two object-valued
claims (`agent_model`, `agent_runtime`) group members that are
only meaningful together.

## Why both `sub` and `agent_instance_id` on the assertion carrier
{:numbered="false"}

On the Client Instance Assertion carrier the assertion's `sub`
must equal `agent_instance_id`, which is deliberately redundant.
Carrying the claim on both carriers gives implementations a single
code path for subject derivation regardless of carrier, and the
equality check on the assertion carrier is a cheap integrity
cross-check. Making the claim optional where `sub` already carries
the value was considered and rejected as an invitation to
carrier-conditional bugs.

## Why generic `agent_*` claim names are registered now
{:numbered="false"}

Agent identity claims are being invented independently across the
industry. Registering `agent_instance_id`, `agent_platform`,
`agent_model`, and `agent_runtime` early is intended to converge
that activity on one vocabulary before divergence hardens, not to
claim the namespace for this document; the semantics here are
deliberately minimal so that other specifications can profile
them. Coordination with related work in other bodies is invited,
and the names are open to revision during working group review.

## Why refresh tokens keep {{CIA-CORE}}'s key binding
{:numbered="false"}

Allowing a refresh token to be re-bound to a rotated key on
presentation of fresh evidence was considered, since the
Attester-minted identity makes "same instance, new key" provable.
It was rejected for this version: it would relax a {{CIA-CORE}}
MUST and enlarge the refresh-token replay surface to the Attester
trust boundary. Identity continuity across rotation is preserved
without it, since new grants and exchanges under the unchanged
`agent_instance_id` carry the same subject ({{refresh}}), at
the cost of one extra grant round-trip after a rotation.

# Worked Example: Agent Calling an MCP Server {#appendix-example-mcp}
{:numbered="false"}

Alice uses an AI assistant operated by an agent platform to triage
issues in her project tracker. The tracker's API is fronted by a
Model Context Protocol server ({{MCP}}) that acts as an OAuth
resource server. The example uses the Client Instance Assertion
carrier ({{carrier-cia}}); the Client Attestation carrier would
convey the same claims with the flow otherwise unchanged.

Deployment:

* User: `alice@example.com`
* OAuth client (agent platform): `https://agents.example.com/assistant`
* Agent Attester (the platform's control plane):
  `https://attester.agents.example.com`
* AS: `https://as.example.com`
* MCP resource server: `https://mcp.example.org` (fronting the
  project tracker)

The platform's registered client metadata lists its control plane
as a trusted instance issuer per {{CIA-CORE}}:

~~~ json
{
  "client_id": "https://agents.example.com/assistant",
  "jwks_uri": "https://agents.example.com/assistant/jwks.json",
  "token_endpoint_auth_method": "private_key_jwt",
  "ai_agent_instance_profile": true,
  "instance_issuers": [
    {
      "issuer": "https://attester.agents.example.com",
      "jwks_uri": "https://attester.agents.example.com/jwks.json",
      "subject_syntax": "uri"
    }
  ]
}
~~~

## Delegation and Instance Spawn
{:numbered="false"}

Alice authorizes the assistant through a standard
`authorization_code` flow with PKCE ({{RFC7636}}); her consent
covers the client as
a whole, per {{CIA-CORE}}'s authorization-time consistency rules.
To handle her request, the platform's control plane spawns agent
instance `sess-9f2c`, provisions it a per-instance DPoP key, and,
acting as the Agent Attester, mints a Client Instance Assertion
carrying the claims of {{agent-claims}}:

~~~ json
{
  "iss":       "https://attester.agents.example.com",
  "sub":
    "https://attester.agents.example.com/instances/sess-9f2c",
  "aud":       "https://as.example.com",
  "client_id": "https://agents.example.com/assistant",
  "sub_profile": "ai_agent",
  "agent_instance_id":
    "https://attester.agents.example.com/instances/sess-9f2c",
  "agent_platform": "urn:example:orchestrator:v5",
  "agent_model":
    { "id": "urn:example:model:atlas", "version": "7.3" },
  "iat": 1770000000,
  "exp": 1770000300,
  "jti": "ag-1a2b3c",
  "cnf": { "jkt": "0ZcOCORZNYy...iguA4I" }
}
~~~

Per {{carrier-cia}}, the assertion's `sub` equals
`agent_instance_id`. The identifier names the session in the
Attester's namespace; it is not derived from the DPoP key.

## Token Issuance
{:numbered="false"}

The instance redeems the authorization code, presenting the
assertion and a DPoP proof signed with its instance key:

~~~ http-message
POST /token HTTP/1.1
Host: as.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: <DPoP proof bound to sess-9f2c's key>

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&code_verifier=...
&client_id=https%3A%2F%2Fagents.example.com%2Fassistant
&client_assertion_type=
  urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIs...
&client_instance_assertion=eyJhbGciOiJFUzI1NiIs...
~~~

The AS validates per {{CIA-CORE}}, classifies the request as
delegation, and issues a DPoP-bound access token. Local policy
surfaces `agent_model` (but not `agent_platform`) per
{{surfacing}}:

~~~ json
{
  "iss":       "https://as.example.com",
  "aud":       "https://mcp.example.org",
  "sub":       "alice@example.com",
  "client_id": "https://agents.example.com/assistant",
  "scope":     "projects.read issues.write",
  "iat":       1770000005,
  "exp":       1770001805,
  "cnf":       { "jkt": "0ZcOCORZNYy...iguA4I" },
  "act": {
    "iss":         "https://attester.agents.example.com",
    "sub":
      "https://attester.agents.example.com/instances/sess-9f2c",
    "sub_profile": "ai_agent client_instance",
    "agent_model":
      { "id": "urn:example:model:atlas", "version": "7.3" },
    "cnf":         { "jkt": "0ZcOCORZNYy...iguA4I" }
  }
}
~~~

## Resource Server Processing
{:numbered="false"}

The MCP server validates the JWT and the accompanying DPoP proof,
then applies agent-aware policy that is impossible when it sees
only `client_id`:

* `act.sub_profile` containing `ai_agent` routes the request
  through the server's agent policy tier (for example, requiring
  human-in-the-loop confirmation for destructive tools).
* Local policy requires `agent_model.version` of at least `7` for
  `issues.write`; a token surfacing an older attested model would
  be limited to read-only tools. (The attested model characterizes
  the instance's primary configuration at evidence issuance, not
  each individual operation, and is static for the token lifetime;
  see {{agent-claims}} and {{security-freshness}} for the limits
  of such policy.)
* Rate limits and anomaly detection are keyed on
  `(client_id, act.sub)`: one runaway session is throttled
  without affecting the platform's other agents.
* The audit record attributes the action end to end:
  "`alice@example.com` via agent instance `sess-9f2c` (model
  `atlas` 7.3) updated issue 4711."

If `sess-9f2c` misbehaves, the MCP server reports `act.sub`; the
platform terminates the session, and the AS applies per-instance
revocation keyed on `(act.iss, act.sub)` per {{CIA-CORE}},
containing one agent without revoking the platform's client
registration.

## Sub-Agent Spawn (Attested Chain)
{:numbered="false"}

The agent delegates a subtask (summarizing a long issue thread)
to a specialized sub-agent. The platform spawns instance
`sess-a114` running a smaller model, with its own DPoP key and its
own assertion (`agent_instance_id` `.../instances/sess-a114`,
`agent_model` `{"id": "urn:example:model:scout", "version": "2.0"}`).
The sub-agent exchanges the parent's access token per {{CIA-CORE}}'s
token-exchange presentation, presenting its assertion as
`actor_token`. The resulting token nests the chain:

~~~ json
{
  "iss":       "https://as.example.com",
  "aud":       "https://mcp.example.org",
  "sub":       "alice@example.com",
  "client_id": "https://agents.example.com/assistant",
  "scope":     "projects.read",
  "cnf":       { "jkt": "QrS...XyZ" },
  "act": {
    "iss":         "https://attester.agents.example.com",
    "sub":
      "https://attester.agents.example.com/instances/sess-a114",
    "sub_profile": "ai_agent client_instance",
    "agent_model":
      { "id": "urn:example:model:scout", "version": "2.0" },
    "cnf":         { "jkt": "QrS...XyZ" },
    "act": {
      "iss":         "https://attester.agents.example.com",
      "sub":
        "https://attester.agents.example.com/instances/sess-9f2c",
      "sub_profile": "ai_agent client_instance"
    }
  }
}
~~~

The chain reads outward-in: sub-agent `sess-a114` (scout 2.0)
acting for agent `sess-9f2c` (atlas 7.3), acting for Alice. Every
actor entry corresponds to an instance that presented Attester
evidence at its hop ({{chains}}); scope was attenuated to
`projects.read` at the exchange.

## Key Rotation
{:numbered="false"}

Mid-session, the platform migrates `sess-9f2c` to another node and
rotates its DPoP key. The Attester mints a fresh assertion with the
same `agent_instance_id` and the new `cnf.jkt`. Access tokens
obtained with the new key carry the same `act.sub`: the MCP
server's per-agent rate-limit state, policy decisions, and audit
trail continue uninterrupted. Had the subject been derived from the
key thumbprint, the rotation would have silently minted a new actor
identity, orphaning the audit trail. (Refresh tokens remain bound
to the key present at their issuance per {{CIA-CORE}} and
{{refresh}}; the migrated instance obtains new tokens through a
fresh grant or exchange under its unchanged identity.)

# Document History
{:numbered="false"}

*RFC EDITOR: please remove this section before publication.*

## -00 {#history-00}
{:numbered="false"}

* Initial version.

# Acknowledgments
{:numbered="false"}

The author thanks participants in the OAuth Working Group for
discussions on client instance identity and agent identity that
informed this document.
