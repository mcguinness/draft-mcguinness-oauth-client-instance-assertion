<!-- regenerate: off -->

# OAuth Drafts

This repository retains superseded individual Internet-Drafts. Active
successor specifications are maintained in the repositories linked below.

## OAuth 2.0 Client Instance Assertion

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-client-instance-assertion)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-client-instance-assertion)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.diff)
* Status: superseded and not being progressed. Its client-published endorsement model moves to Client Attester Endorsement and instance identification moves to Client Instance Identification below. Delegation-chain nesting and depth limits move to the OAuth Actor Profile. No successor yet defines how an instance appears as an actor or subject.

Attestation-Based Client Authentication (ATTEST) and the two companion
profiles replace CIA's client-instance authentication, attester trust, and
identification mechanisms. They are not wire-compatible or complete
replacements for its authorization flows. Actor construction and grant
semantics belong to consuming authorization profiles; native SPIFFE
authentication belongs to SPIFFE Client Authentication. Direct SVID
carriage, automatic instance-as-actor mapping, and CIA's discovery
parameters are not carried forward. The `client-instance-jwt` token type,
the Client Instance Subject Syntaxes registry, and the `client_instance`
entity-profile value are not carried forward.

Behavioural differences a CIA deployment should expect:

* Client metadata alone no longer establishes attester trust; the AS
  either configures the attester or authorizes the client publisher to
  select keys.
* An endorsement cannot limit which instances or subjects an attester
  may assert.
* Withdrawing an endorsement stops new authentication but does not
  invalidate issued tokens unless the deployment revokes them.
* Access tokens need not be sender-constrained; CIA prohibited bearer
  tokens.
* Replay rejection of a repeated attestation becomes ATTEST's
  recommended proof-of-possession replay check.
* Inline `jwks` in an endorsement is not supported; `jwks_uri` is
  required.

ATTEST method discovery does not establish support for either companion
profile. Their use, required downstream context, and revocation policy
require administrative agreement.

## OAuth 2.0 AI Agent Instance Profile

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-ai-agent-instance)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-ai-agent-instance)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.diff)
* Status: superseded and not being progressed. Agent principals are covered by the agent federation profile; per-instance identification is available through Client Instance Identification, but the federation profile does not yet compose with it.

## OAuth 2.0 Client Attester Endorsement

* [Repository and draft source](https://github.com/mcguinness/draft-mcguinness-oauth-client-attesters)
* [Editor's Draft (HTML)](https://mcguinness.github.io/draft-mcguinness-oauth-client-attesters/draft-mcguinness-oauth-client-attesters.html)

A companion profile of Attestation-Based Client Authentication defining
`client_attesters` endorsements in CIMD or registered client metadata.
It specifies AS acceptance, key validation, and withdrawal independently
of stable instance identification, using existing authentication methods.

This draft has not yet been submitted to the IETF.

## Client Instance Identification for Attestation-Based Client Authentication

* [Repository and draft source](https://github.com/mcguinness/draft-mcguinness-oauth-client-instance-id)
* [Editor's Draft (HTML)](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-id/draft-mcguinness-oauth-client-instance-id.html)

An optional claims profile for administratively configured deployments
needing instance continuity across attestations and verified key changes.
Identifiers are scoped to individual Receivers by default, with optional
mapped context for downstream consumers. ATTEST supplies client instance
authentication and proof methods. Attributing a token presentation to an
instance requires a sender-constrained token; context on an unbound token
records only participation. It applies to authorization servers and
resource servers that validate Client Attestations. Deployments that need
only authentication or can use internal correlation mappings do not
require this profile.

This draft has not yet been submitted to the IETF.

## Contributing

See the
[guidelines for contributions](https://github.com/mcguinness/draft-mcguinness-oauth-client-instance-assertion/blob/main/CONTRIBUTING.md).

The contributing file also has tips on how to make contributions, if you
don't already know how to do that.

## Command Line Usage

Formatted text and HTML versions of the draft can be built using `make`.

```sh
$ make
```

Command line usage requires that you have the necessary software installed.  See
[the instructions](https://github.com/martinthomson/i-d-template/blob/main/doc/SETUP.md).
