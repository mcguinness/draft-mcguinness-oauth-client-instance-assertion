<!-- regenerate: off -->

# OAuth Drafts

This is the working area for individual Internet-Drafts.

## OAuth 2.0 Client Instance Assertion

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-client-instance-assertion)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-client-instance-assertion)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-client-instance-assertion.diff)
* Status: superseded and not being progressed. Its instance identification concerns move to Client Instance Identification below; agent representation moves to the agent federation profile and OAuth Actor Profile.

## OAuth 2.0 AI Agent Instance Profile

* [Editor's Copy](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-mcguinness-oauth-ai-agent-instance)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-mcguinness-oauth-ai-agent-instance)
* [Compare Editor's Copy to Individual Draft](https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/#go.draft-mcguinness-oauth-ai-agent-instance.diff)
* Status: superseded and not being progressed. Replaced by the agent federation profile together with Client Instance Identification below.

## Client Instance Identification for Attestation-Based Client Authentication

* [Draft source](draft-mcguinness-oauth-client-instance-id.md)
* [Local HTML preview](draft-mcguinness-oauth-client-instance-id.html) (build with `make`)

An optional claims profile for deployments needing a common instance
identifier across attestations and key changes, with optional downstream
instance context. ATTEST already supplies client instance authentication;
its proof methods and token-binding rules remain unchanged. The profile
applies to authorization servers and resource servers that validate
Client Attestations. Deployments that need only authentication or can
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
