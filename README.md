<!-- regenerate: off -->

# OAuth Agent Federation and Client Instance Identification

This is the working area for individual Internet-Drafts.

## Client Instance Identification for Attestation-Based Client Authentication

* [Draft source](draft-mcguinness-oauth-client-instance-identification.md)
* [Local HTML preview](draft-mcguinness-oauth-client-instance-identification.html) (build with `make`)

A focused profile of ATTEST-CLIENT-AUTH defining stable runtime
identifiers, attester trust, key continuity, and instance context.
It does not determine authorization subjects or delegated actors.

## OAuth 2.0 Profile for Agent Federation

* [Draft source](draft-mcguinness-oauth-workload-agent-federation.md)
* [Local HTML preview](draft-mcguinness-oauth-workload-agent-federation.html) (build with `make`)

An IdP-mediated profile covering agent credential acquisition,
self-acting WAG and user-delegated ID-JAG flows, identity mapping,
and sender binding. Delegated mode normatively uses OAuth Actor
Profile. Provisioning and downstream token formats are deployment
choices; downstream instance context is optional for audit and risk.

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
