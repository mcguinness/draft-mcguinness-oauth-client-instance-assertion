---
title: "OAuth 2.0 AI Agent Instance Profile"
abbrev: "oauth-ai-agent-instance"
category: std

docname: draft-mcguinness-oauth-ai-agent-instance-latest
submissiontype: IETF
stand_alone: yes
date: 2026-09-11
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
  RFC7523:
  RFC7662:
  RFC7800:
  RFC8705:
  RFC8707:
  RFC9068:
  RFC7591:
  RFC8414:
  RFC8693:
  RFC9449:
  RFC9711:
  ATTEST-CLIENT-AUTH: I-D.ietf-oauth-attestation-based-client-auth
  CIA-CORE: I-D.mcguinness-oauth-client-instance-assertion
  WAG: I-D.carleton-workload-authz-grant
  ENTITY-PROFILES: I-D.mora-oauth-entity-profiles

informative:
  RFC7636:
  RFC9396:
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  TXN-TOKENS: I-D.ietf-oauth-transaction-tokens
  ID-CHAINING: I-D.ietf-oauth-identity-chaining
  MCP:
    title: "Model Context Protocol Specification"
    target: https://modelcontextprotocol.io/specification/
    author:
      org: Anthropic
    date: 2025

--- abstract

This specification defines identity and provenance semantics for AI
agent instances across OAuth evidence and authorization-grant
carriers. It defines an attested agent instance identifier,
platform, model, and runtime claims, access-token representation,
and attested delegation chains. Client-bound deployments convey
these claims in a Client Instance Assertion or a Client
Attestation. Workload-principal deployments convey them in a
Workload Authorization Grant, without requiring an OAuth client
registration for each agent or a separate instance assertion.

--- middle

# Introduction

AI agent deployments need to distinguish individual sessions, task
executions, and runtimes for authorization, audit attribution,
incident response, and abuse containment. Resource servers,
including Model Context Protocol servers ({{MCP}}), need a common
meaning for agent identity and provenance across deployment models.

In client-bound deployments, a single OAuth `client_id` represents
an agent platform running many instances. {{CIA-CORE}} identifies
one concrete runtime underneath that logical client. In
workload-principal deployments, a Workload Authorization Grant
({{WAG}}) identifies the agent as the principal authorized by the
grant; OAuth client identity is not required by this profile.
These are distinct relationships, with shared agent semantics.

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
* **A uniform agent classification**: surfacing rules that mark
  agent actors with the `ai_agent` entity profile registered by
  {{ENTITY-PROFILES}}, so resource servers can distinguish agent
  actors from other workload actors with a single signal
  ({{surfacing}}).
* **Attested delegation chains** ({{chains}}): when an agent
  spawns a sub-agent, each hop presents its own instance evidence,
  producing an `act` chain in which every actor was attested rather
  than merely asserted.

The claims defined here are carrier-independent ({{carriers}}).
Client-bound deployments use a Client Instance Assertion per
{{CIA-CORE}} or a Client Attestation per {{ATTEST-CLIENT-AUTH}}.
Workload-principal deployments use a Workload Authorization Grant.
The identity and provenance claims have the same meaning across
carriers; grant semantics determine whether the instance is the
subject or a delegated actor ({{surfacing}}).

This profile does not define agent capability or tool-permission
semantics; deployments expressing fine-grained agent permissions
compose this profile with Rich Authorization Requests ({{RFC9396}})
or deployment-specific scope design.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

This document uses the terms "Client Instance Assertion", "client
instance", "instance issuer", and "OAuth client" as defined in
{{CIA-CORE}}, and "Client Attestation", "Client Attester", and
"DPoP combined mode" as defined in {{ATTEST-CLIENT-AUTH}}.

Agent:
: An autonomous or semi-autonomous software actor, typically driven
  by a machine-learning model, that performs tasks by calling APIs,
  optionally on behalf of a user or another principal.

Agent Platform:
: The platform that creates, operates, or supervises Agent
  Instances. In client-bound deployments, it is represented by an
  OAuth client. In workload-principal deployments, it MAY instead
  operate or authorize the issuer that issues authorization grants
  for its Agent Instances.

Agent Instance:
: A specific agent session, task execution, or runtime. It may be
  represented as a client instance ({{CIA-CORE}}) or as a workload
  principal, according to the deployment mode ({{modes}}).

Agent Attester:
: The authority that authenticates agent instances and mints the
  agent instance claims defined in {{agent-claims}}. Depending on
  the carrier ({{carriers}}), the Agent Attester is a {{CIA-CORE}}
  instance issuer, an {{ATTEST-CLIENT-AUTH}} Client Attester, or a
  {{WAG}} authorization-grant issuer. It is typically the agent
  platform's control plane, but MAY be a
  distinct party (see {{trust}}).

Agent Instance Evidence:
: The carrier artifact conveying the agent instance claims of
  {{agent-claims}} to the AS: a Client Instance Assertion, a Client
  Attestation, or a Workload Authorization Grant, together with the
  proof of possession required for the carrier.

# Deployment Modes {#modes}

| Mode | Platform relationship | Evidence carrier | Access-token instance identity |
| --- | --- | --- | --- |
| Client-bound | OAuth client with runtime instances | Client Instance Assertion or Client Attestation | `act.sub` for delegation; `sub` for self-acting client |
| Workload-principal | Trusted issuer with workload principals | Workload Authorization Grant | `sub`; no `act` required |

In client-bound mode, client registration and instance attestation
establish which runtimes belong to the logical client. In
workload-principal mode, issuer trust establishes the workload
namespace; neither an OAuth `client_id` nor per-agent OAuth
registration is required by this profile. A deployment MAY layer
client authentication on a Workload Authorization Grant. That does
not change the grant subject into a delegated actor.

A Workload Authorization Grant normally supplies both the grant
and the agent identity and provenance evidence. A separate Client
Instance Assertion is NOT REQUIRED when the grant directly
identifies and authenticates the instance under {{carrier-wag}}.
Composition with a separate instance authority is specified in
{{carrier-composition}}.

# Relationship to Other Specifications {#relationships}

In client-bound mode, this profile depends normatively on
{{CIA-CORE}} for token-endpoint processing, sender-constraint
binding, access-token representation, refresh-token semantics, and
resource-server processing. In workload-principal mode, {{WAG}}
and {{RFC7523}} govern grant processing, with the additional
identity, proof-of-possession, and representation requirements of
{{carrier-wag}} and {{surfacing-wag}}. Reusing those semantics does
not import CIA client registration or assertion-presentation
requirements into a WAG-only request.

This profile surfaces the `ai_agent` entity profile registered by
{{ENTITY-PROFILES}}, profiling its use for attested agent
instances. When the Client Attestation carrier is
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

{{ATTEST-CLIENT-AUTH}} authenticates a client instance at the
token endpoint but defines no representation of it in issued
tokens; the design rationale appendix records why this profile
builds its representation layer on {{CIA-CORE}} rather than over
{{ATTEST-CLIENT-AUTH}} alone.

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

## Interoperability with WAG {#wag-interop}

This profile can be applied by WAG issuers, authorization servers,
and resource servers as a coordinated deployment profile. WAG
supplies the authorization grant and issuer trust model; this
document supplies the agent identity, provenance, instance key
binding, and access-token representation rules. The integration
uses the existing WAG token request and JWT claims extension
points; it introduces no new grant type or request parameter.

| WAG element | Integration with this profile |
| --- | --- |
| Grant issuer | Acts as the Agent Attester within the trusted tenancy |
| Grant `sub` | Equals `agent_instance_id`; identifies the authorized agent instance |
| `assertion` parameter | Carries the WAG and its agent claims together |
| Agent properties | Retain WAG authorization semantics alongside the `agent_*` identity and provenance claims |
| Instance proof | Binds grant redemption and the access token to the authenticated instance key |
| Access-token subject | Names the agent; separate evidence for the same instance does not add `act` |

Interoperable deployment requires agreement at three boundaries:

* **Issuer and AS:** establish the trusted issuer, tenancy, and
  subject namespace, activate this profile per {{metadata}}, and
  agree on a supported confirmation method. The issuer includes
  `agent_instance_id` and the applicable provenance claims per
  {{carrier-wag}}. A WAG-only request includes `cnf`; omission
  requires the independently validated binding described in
  {{wag-binding}}.
* **Instance and AS:** use the WAG presentation in `assertion`
  with its RFC 7523 grant type and target `resource`, accompanied
  by the required DPoP or mutual-TLS proof. Client authentication,
  if deployed, retains its separate meaning. A separate CIA is
  optional and follows {{carrier-composition}}, including its
  client binding and issuer-qualified identity checks.
* **AS and resource server:** agree on the access-token format,
  issuer context, sender-constraint mechanism, and selective
  provenance disclosure per {{surfacing-wag}}. WAG authorization
  properties retain their issuer-scoped permission mappings;
  raw runtime evidence is consumed by the AS per {{surfacing}}.

Support for the RFC 7523 grant type or WAG alone does not imply
support for this agent profile. Conversely,
`ai_agent_instance_profile_supported` does not advertise every
carrier. Deployments establish WAG-carrier support through the
trusted issuer agreement in {{metadata}}. An AS that accepts a
WAG without applying this profile does not thereby establish the
agent provenance, instance binding, or token representation
guarantees defined here. Once this profile is required, missing
or invalid evidence is rejected under {{errors}}; it cannot be
handled by silently falling back to ordinary WAG processing.

WAG's prohibition on refresh-token issuance continues to apply
({{refresh}}). Delegation through a subsequent token exchange is
governed by {{chains}}; this integration does not repurpose the
WAG as a CIA actor token. {{appendix-example-wag}} illustrates
WAG-only issuance and composition with a separate runtime
authority.

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
  instances attested by this Attester (including across any OAuth
  clients the Attester serves) and MUST be
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
  Platform. It does not identify an OAuth client; where present,
  `client_id` conveys that separate identity.

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

An AS processing Agent Instance Evidence under this profile
({{metadata}}) MUST reject evidence
that omits `agent_instance_id` ({{errors}}). Evidence whose
object-valued claims are malformed (for example, `agent_model`
without an `id` member) MUST be rejected the same way.

# Evidence Carriers {#carriers}

The claims in {{agent-claims}} can be carried in the following
artifacts. Normally one artifact supplies the agent evidence;
{{carrier-precedence}} and {{carrier-composition}} specify how to
validate requests that combine artifacts. Claim semantics are
carrier-independent; presentation, trust, and grant processing
follow the selected carrier.

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

The Agent Attester acts as an {{ATTEST-CLIENT-AUTH}} Client Attester and
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
self-acting and subject-instance cases, the Attester issuer is not
represented as a
standard access-token claim; the AS MUST retain it with token
state for revocation, introspection, audit, and issuer-aware
resource-server policy; in particular, per-instance revocation
keyed on the issuer-and-subject pair per {{CIA-CORE}} depends on
it.

## Workload Authorization Grant Carrier {#carrier-wag}

An Agent Instance MAY be represented by a Workload Authorization
Grant ({{WAG}}). The grant issuer acts as the Agent Attester and
includes the claims of {{agent-claims}} in the signed grant. The
grant's `sub` MUST equal `agent_instance_id`, using exact string
comparison. Its `iss` identifies the trusted authorization-grant
issuer, not the OAuth client. The WAG non-reassignment requirement
continues to apply even after an instance ceases to be
audit-relevant.

The instance presents the JWT in `assertion` with
`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`, and the
target resource in `resource`, per {{WAG}} and {{RFC8707}}. The AS
MUST validate the signature, issuer trust, audience, lifetime, and
required claims per {{WAG}} and {{RFC7523}}, as well as the agent
claims in this profile. Trust is established for the grant issuer
and its tenancy under AS policy ({{metadata}}); CIA
`instance_issuers` metadata is not consulted for grant validation.
The AS MUST reject reuse of an accepted `(iss, jti)` grant through
its expiry, allowing for accepted clock skew. A grant issuer
SHOULD issue short-lived grants and MUST issue fresh grants when
attested provenance changes as specified in {{agent-claims}}.

### Instance Key Binding {#wag-binding}

An AI-agent WAG SHOULD contain `cnf` ({{RFC7800}}) identifying an
instance-specific key. This profile supports `cnf.jkt` with DPoP
({{RFC9449}}) and `cnf.x5t#S256` with mutual TLS ({{RFC8705}}).
When `cnf` is present, the AS MUST verify possession at the token
endpoint and bind the issued access token to that same key,
following the confirmation matching rules of {{CIA-CORE}}. The
AS MUST reject an unsupported or unverifiable binding; the
presence of an arbitrary `cnf` member is not sufficient.

When the grant omits `cnf`, the AS MUST obtain an authenticated
binding between the grant subject and an instance-specific key
from independently validated instance evidence under
{{carrier-composition}}. A DPoP proof with a requester-selected
key alone does not establish that binding. A WAG-only request
therefore requires `cnf`. In every case the AS MUST issue an
access token constrained to the verified instance key and MUST
NOT issue a bearer access token under this profile. Client-level
shared credentials do not satisfy instance binding.

### Identity and Authorization Properties {#wag-properties}

`agent_instance_id`, `agent_platform`, `agent_model`, and
`agent_runtime` describe identity and provenance. WAG properties
such as `name`, `namespace`, `groups`, `roles`, and `ctx` describe
issuer-asserted attributes for authorization. They retain their
{{WAG}} semantics and issuer-scoped permission mapping; this
profile does not redefine them or interpret them as agent identity.
Conversely, provenance claims are not portable permission grants.
Their disclosure follows {{surfacing}}, including the prohibition
on forwarding raw `agent_runtime` evidence.

## WAG with Separate Instance Evidence {#carrier-composition}

A deployment MAY combine a WAG from an authorization authority
with a Client Instance Assertion from a runtime authority, or with
Client Attestation authentication. The AS MUST validate each
artifact independently under its carrier's trust and processing
rules. CIA composition therefore still requires an OAuth client
and the CIA `client_id` binding; WAG alone does not.

The AS MUST establish that the WAG's `(iss, sub)` and the separate
evidence's issuer and instance identifier refer to the same
instance. The CIA instance identifier is its `sub` (which MUST
equal its own `agent_instance_id`); the Client Attestation instance
identifier is `agent_instance_id`, not its client-valued `sub`.
Within an explicitly trusted common namespace these identifiers
MUST be equal. Different namespaces require an explicitly
configured, issuer-qualified subject mapping authorized by AS
policy. Equal strings from unrelated issuers, heuristic matching,
and mappings asserted only by the requester MUST NOT establish
equivalence. The AS MUST reject a request when equivalence cannot
be established.

If both the WAG and separate evidence contain `cnf`, their binding
members MUST identify the same key material (thumbprint equality
for the same member). All presented instance evidence and the
verified proof of possession MUST resolve to one instance binding
key, including when the WAG omits `cnf`. The AS MUST reject
conflicting or unverifiable bindings. If CIA and Client Attestation
are both presented, {{carrier-precedence}} also applies.

The WAG remains authoritative for the grant subject and
`agent_instance_id`. Separate evidence supplies additional facts
about that subject, not a distinct delegated actor. The AS MUST
configure which issuer is authoritative for each provenance claim,
MUST NOT silently overwrite conflicting claims, and MUST reject
conflicts unless that configured policy resolves them. It MUST
retain both issuer-qualified identities, any mapping used, and
claim provenance for audit and revocation. The access token uses
the subject-instance representation of {{surfacing-wag}}; the AS
MUST NOT add an `act` entry merely because separate evidence
confirms the same instance.

## Carrier Precedence {#carrier-precedence}

Between the two client-bound artifacts, a Client Instance
Assertion takes precedence over a Client Attestation presented
for client authentication: the CIA supplies instance identity and
provenance. When a WAG is also present, {{carrier-composition}}
governs the grant subject and resolution of claims between the WAG
and that client-bound evidence. To ensure the CIA and Client
Attestation describe the same instance, the AS MUST verify that
the assertion's `cnf` binding key and the DPoP key matched against
the Client Attestation's `cnf` identify the same key material (for
`cnf.jkt`, thumbprint equality); if they differ, the AS MUST
reject the request with `invalid_grant`. If both artifacts carry
`agent_instance_id`, the values MUST be equal; the AS MUST reject
the request with `invalid_grant` otherwise.

# Client and Authorization Server Metadata {#metadata}

Client metadata below activates client-bound mode. For
workload-principal mode, the AS MUST establish use of this profile
in its trusted WAG issuer configuration or by out-of-band
agreement, including the permitted subject namespace and required
instance binding. No client registration flag is required. An AS
MUST NOT select subject-instance processing merely because an
untrusted JWT contains `agent_instance_id`, or fall back to bearer
WAG processing when evidence required by configured policy is
missing or invalid.

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
  representation. This flag does not advertise support for every
  carrier; deployments MUST establish the supported carriers by
  their client registration or trusted issuer agreement. WAG
  support also requires the grant-type advertisement in {{WAG}}.

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

In client-bound mode, access-token representation follows
{{CIA-CORE}}: the instance subject appears as `act.sub` in
delegation cases and as top-level `sub` in self-acting and
subject-instance cases. Workload-principal representation follows
{{surfacing-wag}}. All issued access tokens are sender-constrained
to the verified instance key.

This profile additionally specifies:

* The surfaced `sub_profile` (top-level when the instance is the
  subject, `act.sub_profile` in delegation cases) MUST include
  `ai_agent` ({{ENTITY-PROFILES}}). It MUST additionally include
  `client_instance` ({{CIA-CORE}}) when validated Client Instance
  Assertion or Client Attestation evidence establishes that
  relationship. WAG-only evidence MUST NOT imply that
  classification. Values use the underlying registry's list
  syntax; other applicable registered values MAY be included.
* The AS MAY surface `agent_platform` and `agent_model` subject to
  local policy and the privacy considerations of
  {{security-privacy}}. Surfaced provenance claims appear within
  the `act` object in delegation cases (they describe the actor)
  and at top level in self-acting and subject-instance cases. An AS
  MUST NOT surface provenance claims that were not
  present in validated Agent Instance Evidence.
* `agent_runtime` evidence is consumed by the AS for policy and
  MUST NOT be surfaced to resource servers verbatim. Deployments
  that expose a runtime-assurance signal to resource servers
  SHOULD surface a coarse assurance tier ({{trust}}) via a
  deployment-defined claim rather than raw evidence.

For opaque (reference) access tokens, the same surfaced claims
appear in introspection responses, per {{CIA-CORE}}'s
introspection requirements.

## Workload-Principal Tokens {#surfacing-wag}

This profile explicitly defines a conforming WAG's grant subject
as the presenting Agent Instance. It is the subject-instance case
of {{CIA-CORE}} when a CIA is also presented, and represents an
agent acting as itself whether or not separate evidence is used.
The AS MUST set the access token's `sub` to the WAG's
`agent_instance_id`, subject to issuer-aware AS namespacing below,
and MUST omit `act`. Separate evidence about that same instance
MUST NOT introduce an actor entry. Top-level `sub_profile` and selective provenance follow
{{surfacing}}, and top-level `cnf` follows {{wag-binding}}.

The access token's `iss` identifies the AS. The AS MUST retain the
WAG issuer with token state for audit, revocation, introspection,
and issuer-aware policy; it MUST NOT substitute the WAG issuer
for the access token's issuer. Where accepted issuers have
colliding subject spaces, the AS MUST apply issuer-qualified
namespacing to the surfaced `sub` or expose authenticated issuer
context understood by the resource server. Subject mappings MUST
preserve the grant principal's identity and MUST NOT select a
subject from unrelated evidence. Resource servers MUST treat
identifiers as opaque and evaluate them in their established
issuer context.

This profile does not require `client_id` in WAG-only access
tokens and does not impose CIA's {{RFC9068}} token format on that
mode. A deployment using a token format requiring `client_id`
needs an explicit client identity arrangement under that format;
it MUST NOT invent a client identity by copying the workload
subject or grant issuer. Opaque tokens expose the same identity,
classification, and binding through {{RFC7662}} introspection.

Resource servers MUST validate the access token's authenticity,
issuer, intended audience, and lifetime under the deployed token
format, or obtain an active response from authenticated
introspection, before using its claims. They MUST verify the DPoP
proof or mutual-TLS binding against the token's top-level `cnf`
per {{RFC9449}} or {{RFC8705}}, respectively. Policy MUST use the
validated subject and issuer context for instance attribution;
`agent_platform` is not a substitute for either.

# Attested Delegation Chains {#chains}

When an agent instance spawns a sub-agent that requires its own
access token, the sub-agent obtains it via token exchange
({{RFC8693}}) using {{CIA-CORE}}'s token-exchange presentation,
presenting its own Client Instance Assertion or using the Client
Attestation carrier. The resulting `act` chain preserves any
existing actor entries per {{CIA-CORE}}'s chain merging. When the
spawning agent was itself the subject, it remains the subject of
the exchanged token. Scope attenuation at each exchange follows
{{RFC8693}}.

A WAG is an authorization grant in the `assertion` slot, not a
CIA `actor_token`. This document does not define WAG presentation
as actor evidence on token exchange. A token issued from a WAG
MAY be used as a `subject_token` under an applicable token-exchange
profile and AS policy. A different sub-agent then acts for that
subject, and the CIA delegation classification applies; the
subject-instance exception for WAG redemption does not collapse
token-exchange actor chains.

Whether a given instance is permitted to perform such an exchange
is AS authorization policy under {{RFC8693}} and {{CIA-CORE}};
this profile defines no separate spawn-permission mechanism.
The spawning agent remains represented as the grant subject or
within the preserved actor chain. Across these exchanges, spawning
cannot be used to shed the identity recorded at the preceding hop.

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

The WAG carrier MUST NOT result in refresh-token issuance, per
{{WAG}}, including when combined with separate instance evidence.
The instance obtains further access tokens with a fresh WAG.

For the client-bound carriers on other grants, refresh-token
handling follows {{CIA-CORE}}, with the derived
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
error taxonomy of the selected carrier: {{CIA-CORE}},
{{ATTEST-CLIENT-AUTH}}, or {{WAG}} and {{RFC7523}}. Failures of WAG
validation are `invalid_grant`; DPoP protocol errors retain the
codes specified by {{RFC9449}}. This profile adds the
following `invalid_grant` cases (returned as `invalid_client`
when, per {{CIA-CORE}}, the evidence is the client authentication
credential):

* a token request on a covered grant other than `refresh_token`
  presents no Agent Instance Evidence, and neither the client's
  registration nor AS policy exempts the grant type
  ({{metadata}});
* the Agent Instance Evidence omits `agent_instance_id` when this
  profile is required by client or issuer configuration
  ({{metadata}});
* an object-valued agent claim is malformed
  ({{agent-claims}});
* on the CIA or WAG carrier, `sub` does not equal
  `agent_instance_id` ({{carrier-cia}}, {{carrier-wag}});
* a WAG lacks an authenticated instance key binding, is replayed,
  or fails agent claim validation ({{carrier-wag}});
* combined evidence fails issuer-qualified identity consistency,
  key consistency, or provenance conflict resolution
  ({{carrier-composition}});
* under carrier precedence, the binding keys or
  `agent_instance_id` values of the two artifacts do not match
  ({{carrier-precedence}});
* on refresh, presented evidence is issued by a different Agent
  Attester or carries a different `agent_instance_id` than
  recorded at original issuance ({{refresh}}).

# Conformance {#conformance}

An AS conforms to this profile by supporting at least one evidence
carrier ({{carriers}}); requiring evidence under the applicable
client or trusted issuer configuration per {{metadata}};
validating the agent instance claims per {{agent-claims}}; deriving the instance subject per {{subject}};
surfacing per {{surfacing}}, including `ai_agent` and, when
applicable, `client_instance` in the surfaced `sub_profile`; applying
the refresh rules of {{refresh}};
applying carrier precedence and composition
({{carrier-precedence}}, {{carrier-composition}}) when multiple
artifacts are presented; and advertising support via
`ai_agent_instance_profile_supported` ({{metadata}}). An AS
supporting the Client Instance Assertion carrier conforms to
{{CIA-CORE}}; an AS supporting the Client Attestation carrier
conforms to {{ATTEST-CLIENT-AUTH}} and to the activation-policy
requirement of {{carrier-attest}}. An AS supporting the WAG
carrier conforms to {{WAG}} and {{RFC7523}}, and applies
{{carrier-wag}} and {{surfacing-wag}}.

An Agent Attester conforms by meeting the minting requirements of
{{agent-claims}} (in particular the uniqueness, stability,
non-reassignment, and key-independence of `agent_instance_id`)
and, per carrier, the obligations of a {{CIA-CORE}} instance
issuer, an {{ATTEST-CLIENT-AUTH}} Client Attester, or a {{WAG}}
authorization-grant issuer.

An Agent Platform conforms by establishing this profile for the
carriers it uses through client registration or trusted issuer
configuration ({{metadata}}), listing its Agent Attester per
{{carrier-cia}} where applicable, and ensuring the Attester is
authorized to attest its instances.

A resource server conforms by processing delegated, self-acting,
and subject-instance tokens per the applicable {{CIA-CORE}} or
{{surfacing-wag}} resource-server rules, treating subjects and
actors whose `sub_profile` includes `ai_agent` as agent instances, and
treating surfaced provenance claims subject to the assurance-tier
considerations of {{trust}} and {{security-provenance}}.

# Security Considerations {#security}

This document inherits the security considerations of {{CIA-CORE}}
and, when the Client Attestation carrier is used,
{{ATTEST-CLIENT-AUTH}} and {{RFC9449}}. The WAG carrier additionally
inherits {{WAG}} and {{RFC7523}}, with instance key binding per
{{wag-binding}}. Configured issuer trust and subject mappings are
security boundaries: accepting a new issuer or mapping MUST NOT
let it impersonate another tenant's instances. The AS MUST select
the authorization-grant profile from trusted configuration and
MUST NOT infer subject-instance semantics from matching subject
strings or shared keys alone.

## Attestation Freshness and Model Drift {#security-freshness}

Agent Instance Evidence describes the instance as of evidence
issuance. The claim most exposed to drift is `agent_model`: a
platform that hot-swaps or upgrades the model serving a session
invalidates previously issued evidence. {{agent-claims}} requires
fresh evidence after a model change, but the AS cannot detect a
violation in-band; resource servers applying model-version policy
are trusting the Attester's issuance discipline.

On the Client Instance Assertion carrier, {{CIA-CORE}}'s short
assertion lifetimes bound the drift window. On the WAG carrier,
the grant lifetime bounds the window for obtaining tokens from
stale evidence; fresh grants are needed for subsequent issuance.
On the Client Attestation carrier, the window is bounded by the Client
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

The carriers place control over the Attester set with
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

On the WAG carrier, AS-configured issuer and tenancy trust governs
both authorization grants and the agent claims they carry. A
separate runtime attester does not acquire authority to issue
WAGs by participating in {{carrier-composition}}; both trust
relationships must be validated independently.

The same claims therefore arrive under different trust models
depending on carrier. The registration-time agreement required by
{{carrier-attest}} is the client's control point on the
attestation carrier: clients SHOULD establish the acceptable
Attester set as part of that agreement. Deployments in which the
client requires in-band, auditable control over its attestation
surface SHOULD use the Client Instance Assertion carrier.

## Attester Trust from Client-Asserted Metadata {#security-dcr}

In deployments where the client's metadata originates from the
client itself rather than from a vetted registration process,
the `instance_issuers` list and the `ai_agent_instance_profile`
flag arrive from a party the AS has no prior relationship with.
This is the case for unauthenticated dynamic registration
({{RFC7591}}) and equally for clients identified by a Client ID
Metadata Document ({{CIMD}}), where the metadata document is
authored and hosted by the client at a URL it controls; both
occur when agent applications register with an authorization
server discovered at run time. An unauthenticated registrant
naming an Attester it controls gains nothing against other
clients (the Attester attests only that client's instances), but
the AS is nonetheless accepting a trust root and a token-shape
obligation from an unvetted source.

An AS accepting client-asserted metadata SHOULD NOT honor
`instance_issuers` entries from such a source unless each listed
Agent Attester is validated against AS policy, for example an
AS-side allowlist of recognized platform Attesters, or, for
dynamic registration, a signed software statement ({{RFC7591}})
from an authority the AS trusts. Software statements do not exist
in the {{CIMD}} model; there, the allowlist applies unchanged, and
the AS MAY additionally condition acceptance on the provenance of
the client identifier itself, which is a URL the client
demonstrably controls. The `ai_agent_instance_profile` flag in
metadata listing no `instance_issuers` implicates the Client
Attestation carrier, whose Attester trust is AS-configured
({{carrier-attest}}); honoring the flag there accepts a
token-shape obligation but no new trust root. AS-operated
allowlists of well-known agent platform Attesters are the expected
deployment pattern for resource ecosystems serving dynamically
registered or {{CIMD}}-identified agent clients.

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

## OAuth Entity Profiles Registry

This document requests no registration in the "OAuth Entity
Profiles" registry: the `ai_agent` entity profile this document
surfaces ({{surfacing}}) is registered by {{ENTITY-PROFILES}} as
part of that registry's initial contents.

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
should not need a second artifact carrying the same facts.
Workload-principal deployments use {{WAG}} to authorize the agent
itself and need no client-instance relationship. One grant can
carry both authorization and agent provenance. Binding
the agent claims to a single carrier would fragment the profile by
deployment style without any interoperability gain.

## Why the profile is not defined over Attestation-Based Client Authentication alone
{:numbered="false"}

A natural question is why this profile does not depend solely on
{{ATTEST-CLIENT-AUTH}}, a working-group document, and omit
{{CIA-CORE}}. Attestation-based client authentication
authenticates a client instance at the token endpoint and
deliberately stops there: it defines no representation of the
instance in issued access tokens, no instance identifier (the
attestation's `sub` is the `client_id`; the instance is identified
only by its key, the key-as-identity model that {{subject}}
rejects), no token-exchange or delegation-chain semantics, no
introspection content, and no identity continuity across key
rotation. On the client-bound carriers, the access-token
representation machinery is imported from {{CIA-CORE}}.
The WAG carrier uses the common agent semantics with the distinct
workload-principal representation in {{surfacing-wag}}. Removing
the {{CIA-CORE}} dependency would not remove that machinery; it
would relocate it into this document, coupling a general
instance-representation layer to the AI-agent use case. The
Client Instance Assertion carrier additionally serves deployments
the attestation carrier structurally cannot: platforms that keep
an existing client authentication method and add instance
evidence rather than replacing their credential, clients
requiring in-band control over their Attester set, SPIFFE-based
workload reuse, mTLS sender constraint, and short-lived
per-issuance evidence. {{ATTEST-CLIENT-AUTH}} answers whether a
genuine instance of the client is authenticating; {{CIA-CORE}}
defines what the resource server sees afterward. This profile is
a profile of the second question.

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

## Why both `sub` and `agent_instance_id` on CIA and WAG carriers
{:numbered="false"}

On the Client Instance Assertion and WAG carriers, `sub` must
equal `agent_instance_id`, which is deliberately redundant.
Carrying the claim on all carriers gives implementations a single
code path for subject derivation regardless of carrier, and the
equality check on these two carriers is a cheap integrity
cross-check. Making the claim optional where `sub` already carries
the value was considered and rejected as an invitation to
carrier-conditional bugs.

## Why no standardized assurance-tier claim
{:numbered="false"}

This document names three assurance tiers ({{trust}}) but does not
register a claim conveying them, directing deployments to a
deployment-defined claim instead ({{surfacing}}). The tiers are
policy vocabulary between an AS and its resource servers, not
attested facts: which tier a given Attester provides is an
operational judgment the AS makes when it configures trust, and a
standardized claim would present that judgment with the same
apparent authority as the attested claims it summarizes.
Registering a tier claim before deployments demonstrate convergent
semantics would freeze the wrong thing; one can be added by a
later document without disturbing anything defined here.

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

# Worked Example: Workload-Principal Agent {#appendix-example-wag}
{:numbered="false"}

An enterprise authorizes a support agent to obtain tokens for its
support API. The AS has configured trust in the tenancy's issuer
`https://acme.agents.example` and requires this profile for its
WAGs. No OAuth client registration is needed for this deployment.
The issuer mints the following WAG; cryptographic values are
abbreviated for display:

~~~ json
{
  "iss": "https://acme.agents.example",
  "sub": "wimse://acme.agents.example/agent/7f3d9a2e",
  "agent_instance_id":
    "wimse://acme.agents.example/agent/7f3d9a2e",
  "agent_platform": "urn:example:claude-code",
  "agent_model": {
    "id": "urn:example:model:atlas",
    "version": "7.3"
  },
  "agent_runtime": { "eat": "eyJ...runtime-evidence..." },
  "name": "Support Triage Agent",
  "namespace": "acme/support",
  "groups": ["support-eng"],
  "roles": ["responder"],
  "ctx": "channel:C0123456789",
  "cnf": { "jkt": "0ZcOCORZNYy...iguA4I" },
  "aud": ["https://as.example", "https://as.example/token"],
  "iat": 1785271680,
  "exp": 1785271980,
  "jti": "wag-7d0f5a2b"
}
~~~

The instance redeems this grant with proof of possession of its
binding key. Line breaks in the form body are for display only:

~~~ http-message
POST /token HTTP/1.1
Host: as.example
Content-Type: application/x-www-form-urlencoded
DPoP: <proof signed by the key identified by cnf.jkt>

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer
&assertion=eyJhbGciOiJFUzI1NiIs...
&resource=https%3A%2F%2Fsupport.example%2F
~~~

The AS validates the issuer, grant, agent claims, replay status,
and DPoP proof. Its local permission mapping grants
`issues.read issues.write`. An illustrative access-token payload
is below; this deployment uses a JWT format that does not require
`client_id`, as discussed in {{surfacing-wag}}:

~~~ json
{
  "iss": "https://as.example",
  "aud": "https://support.example/",
  "sub": "wimse://acme.agents.example/agent/7f3d9a2e",
  "sub_profile": "ai_agent",
  "scope": "issues.read issues.write",
  "agent_platform": "urn:example:claude-code",
  "agent_model": {
    "id": "urn:example:model:atlas",
    "version": "7.3"
  },
  "cnf": { "jkt": "0ZcOCORZNYy...iguA4I" },
  "iat": 1785271685,
  "exp": 1785271985
}
~~~

The token has no `act`: the agent is the authorized subject.
`agent_runtime` was consumed by the AS and is not forwarded.
The resource server validates the AS token and DPoP proof and
applies subject-based policy. No refresh token is issued; the
agent obtains a new WAG for later access.

## Separate Runtime Authority
{:numbered="false"}

If an enterprise issuer supplies the WAG while a runtime authority
supplies CIA evidence, the client-bound composition additionally
establishes the OAuth client and its trusted instance issuer. For
example, a CIA names the same URI in both `sub` and
`agent_instance_id`, carries the client's `client_id`, and binds
the same key in `cnf.jkt`. The token request adds `client_id` and
`client_instance_assertion`, plus any required client
authentication. The AS checks the shared namespace agreement or
configured issuer-qualified mapping and validates both authorities
per {{carrier-composition}}.

The resulting token still has the WAG principal in `sub` and no
`act`. It additionally includes `client_instance` in `sub_profile`
and the established `client_id` under the applicable client-bound
token format. A different instance subject without an authorized
mapping, or a different confirmation key, causes rejection rather
than a token with a duplicated or substituted actor.

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
