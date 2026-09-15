<!-- regenerate: off -->

# OAuth Drafts

This is the working area for individual Internet-Drafts.

## OAuth 2.0 Client Instance Assertion

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-client-instance-assertion)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-client-instance-assertion)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.diff)
* Status: superseded and not being progressed. Its client-published endorsement model moves to Client Attester Endorsement and instance identification moves to Client Instance Identification below; agent representation moves to the agent federation profile and OAuth Actor Profile.

## OAuth 2.0 AI Agent Instance Profile

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-ai-agent-instance)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-ai-agent-instance)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.diff)
* Status: superseded and not being progressed. Replaced by the agent federation profile together with Client Instance Identification below.

## OAuth 2.0 Client Attester Endorsement

* [Draft source](draft-mcguinness-oauth-client-attesters.md)

A companion profile of Attestation-Based Client Authentication defining
`client_attesters` endorsements in CIMD or registered client metadata.
It specifies AS acceptance, key validation, and withdrawal independently
of stable instance identification, using existing authentication methods.

This draft has not yet been submitted to the IETF.

## Client Instance Identification for Attestation-Based Client Authentication

* [Draft source](draft-mcguinness-oauth-client-instance-id.md)
* [Editor's Draft (HTML)](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-id.html)

An optional claims profile for administratively configured deployments
needing instance continuity across attestations and verified key changes.
Identifiers are scoped to individual Receivers by default, with optional
mapped context for downstream consumers. ATTEST already supplies client
instance authentication; its proof methods and token-binding rules remain
unchanged. The profile applies to authorization servers and resource
servers that validate Client Attestations. Deployments that need only
authentication or can
use internal correlation mappings do not require this profile.

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
