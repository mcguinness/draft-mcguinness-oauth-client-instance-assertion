<!-- regenerate: off -->

# OAuth Agent Federation and Client Instance Identification

This is the working area for individual Internet-Drafts.

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
to IdP identities through ATTEST or SPIFFE X.509-SVID authentication.
Eligible IdP-issued access tokens are exchanged for user-delegated
ID-JAG or provisional self-acting WAG. Instance tracking is optional;
delegation uses OAuth Actor Profile. An agent with its
own client identity uses `client_id`; only shared clients require
an additional `agent_id`. Existing CIMD/EMA
flows and provisioning choices are informative deployment guidance;
examples include downstream client authentication and provisioning
correlation. WAG interoperability still requires coordination with
the underlying draft.

These two drafts replace the earlier Client Instance Assertion
and standalone AI Agent Instance architecture. The earlier sources
remain in Git history. The new instance-identification draft and
the federation draft have not yet been submitted to the IETF.

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
