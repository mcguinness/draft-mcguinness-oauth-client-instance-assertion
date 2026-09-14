<!-- regenerate: off -->

# OAuth Agent Federation and Client Instance Identification

This is the working area for individual Internet-Drafts.

## OAuth 2.0 Client Instance Assertion

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-client-instance-assertion)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-client-instance-assertion)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.diff)

## OAuth 2.0 AI Agent Instance Profile

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-ai-agent-instance)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-ai-agent-instance)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.diff)

## Client Instance Identification for Attestation-Based Client Authentication

* [Draft source](draft-mcguinness-oauth-client-instance-identification.md)
* [Local HTML preview](draft-mcguinness-oauth-client-instance-identification.html) (build with `make`)

A focused profile of ATTEST-CLIENT-AUTH defining stable instance
identifiers, attester trust, key continuity, and optional instance
context. Configuration distinguishes installation and execution lifetimes.
It does not determine authorization subjects or delegated actors.

## OAuth 2.0 Profile for Agent Federation

* [Draft source](draft-mcguinness-oauth-workload-agent-federation.md)
* [Local HTML preview](draft-mcguinness-oauth-workload-agent-federation.html) (build with `make`)

A standards-track profile for binding platform-authenticated agents
to IdP identities through platform-issued JWTs, ATTEST, SPIFFE
X.509-SVID, or WIT-SVID authentication. WIT-SVID uses the ATTEST headers directly, with
attestation proof and a matching DPoP key.
For self-acting WAG, JWT credentials are exchanged directly. An
intermediate IdP access token is needed for X.509-SVID and as actor
evidence for user-delegated ID-JAG; an eligible token can be reused.
Instance tracking is optional;
delegation uses OAuth Actor Profile. An agent with its
own client identity uses `client_id`; only shared clients require
an additional `agent_id`. Existing CIMD/EMA
flows and provisioning choices are informative deployment guidance;
examples include downstream client authentication and provisioning
correlation. WAG interoperability still requires coordination with
the underlying draft.

The instance-identification and agent-federation drafts have not
yet been submitted to the IETF.

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
