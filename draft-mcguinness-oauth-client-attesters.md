---
title: "OAuth 2.0 Client Attester Delegation"
abbrev: "Client Attester Delegation"
category: std
docname: draft-mcguinness-oauth-client-attesters-latest
submissiontype: IETF
stand_alone: yes
date: 2026-09-15
ipr: trust200902
area: "Security"
workgroup: "Web Authorization Protocol"
keyword:
 - OAuth
 - client attestation
 - client metadata
venue:
  group: "Web Authorization Protocol"
  type: "Working Group"
  mail: "oauth@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/oauth/"
  github: "mcguinness/draft-mcguinness-oauth-client-instance-assertion"
  latest: "https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-attesters.html"
author:
 - fullname: Karl McGuinness
   organization: Independent
   email: public@karlmcguinness.com
normative:
  ATTEST: I-D.ietf-oauth-attestation-based-client-auth
  CIMD: I-D.ietf-oauth-client-id-metadata-document
  RFC6749:
  RFC7517:
  RFC7519:
  RFC7591:
  RFC8725:
  RFC9111:
informative:
  INSTANCE-ID:
    title: "Client Instance Identification for Attestation-Based Client Authentication"
    target: https://mcguinness.github.io/draft-mcguinness-oauth-client-instance-assertion/draft-mcguinness-oauth-client-instance-id.html
    author:
      - fullname: Karl McGuinness
    date: 2026-09-11
--- abstract

This specification defines client metadata identifying the attesters
that an OAuth client authorizes to attest its instances. It profiles
Attestation-Based Client Authentication for authorization servers that
accept such delegation, using Client ID Metadata Documents or registered
client metadata. It defines endorsement, validation, and withdrawal
rules without introducing a new credential or authentication method.

--- middle

# Introduction

A client identified by one metadata URL can have many installations,
each holding a different key. Attestation-Based Client Authentication
{{ATTEST}} allows an attester to authenticate those instances, but
leaves attester trust establishment to deployments. Client ID Metadata
Documents {{CIMD}} publish client metadata but do not specify how the
client delegates this attestation authority.

This profile adds `client_attesters`: the client's endorsements of
attesters and their verification keys. An authorization server (AS)
accepts an endorsement only under its own trust policy. The resulting
chain is:

~~~ ascii-art
Client metadata --endorses--> Attester --attests--> Client Instance
       |                         |                       |
       +------ AS accepts delegation and validates proof-+
~~~

The profile applies at AS endpoints accepting CLIENT-ATTEST for client
authentication or as an additional security signal. It retains ATTEST's
wire format, proof methods, and token binding. It does not assign
instance identifiers or establish user delegation; {{INSTANCE-ID}} is
an optional, independent profile for stable instance identification.

# Conventions and Trust Model {#trust}

{::boilerplate bcp14-tagged}

OAuth terms follow {{RFC6749}} and Client Attester, Client Attestation,
and Client Instance Key follow {{ATTEST}}. The client publisher controls
the authoritative metadata for a `client_id`; an endorsement authorizes
an attester to issue Client Attestations naming that client.

The AS MUST configure whether it accepts client-published delegation
and which client publishers, attesters, or evidence assurances its
policy permits. It can, for example, accept endorsements from approved
client publishers without individually pre-registering their attesters.
An endorsement MUST NOT by itself establish that the client is trusted
or authorized to access a resource.

For requests governed by this profile, both a current client endorsement
and AS policy approval are REQUIRED. AS policy can narrow the endorsed
set; it MUST NOT add an unendorsed attester or silently fall back to a
different trust mechanism. Other ATTEST deployments can use separately
configured trust without this profile.

Profile applicability is an AS policy decision, not selected by the
presence or absence of `client_attesters`. ATTEST authentication-method
discovery does not signal this trust policy; deployments relying on
client endorsement enforcement establish that the AS applies this
profile through their trust agreement.

# Client Metadata {#metadata}

`client_attesters` is OPTIONAL client metadata, usable in a CIMD or
registered metadata under {{RFC7591}}. Its value is an array of objects:

| Member | Requirement | Meaning |
|---|---|---|
| `issuer` | REQUIRED, nonempty StringOrURI {{RFC7519}} | Exact `iss` of the endorsed Client Attester |
| `jwks_uri` | REQUIRED, HTTPS URL without userinfo or fragment | Location of the attester's public JWK Set {{RFC7517}} |

An issuer MUST occur at most once in the array. Missing or empty
`client_attesters` authorizes no attester under this profile. Malformed
entries or duplicate issuers MUST cause rejection of the metadata for
this profile; implementations MUST NOT partially accept that list.
Unrecognized members MUST be ignored; extensions MUST NOT weaken the
meaning of an endorsement for implementations that ignore them.

Each entry delegates only attestation for the `client_id` whose metadata
contains it. It does not authorize recursive delegation or reuse for
another client. An `issuer` identifies a namespace, not a discovery
endpoint. The `jwks_uri` within the entry is distinct from a top-level
client `jwks_uri`, which serves the client's own authentication method.

Clients using attestation as client authentication select
`attest_jwt_client_auth` or `attest_jwt_client_auth_dpop` under
{{ATTEST, Section 9}}. When attestation supplements another method,
that method remains required under {{ATTEST, Section 7.6}}.
`client_attesters` does not select a grant, proof method, or the optional
instance-identification profile.

# Attestation and AS Processing {#processing}

Requests under this profile MUST include `client_id` to select the
client metadata; the parameter alone is not authentication.

The Client Attester MUST verify that the requesting runtime is
authorized as an instance of the specified client, using authenticated
enrollment or platform evidence. Knowledge of a public `client_id` or
possession of a newly generated key alone is insufficient. The attester
MUST include its `issuer` value as `iss` and the exact client identifier
as `sub`; other claims and proof requirements follow ATTEST.

For each presentation, the AS MUST:

1. Obtain authoritative metadata for the requested `client_id`, following
   CIMD resolution and validation or its registered metadata policy.
   Selection between registered and fetched metadata follows CIMD;
   the AS MUST NOT combine their endorsement lists.
2. Validate `client_attesters` and select the entry whose `issuer`
   exactly matches the attestation's nonempty `iss`. Verify AS policy
   permits that client-to-attester delegation.
3. Resolve the selected entry's JWK Set and verify the attestation's
   signature using an acceptable asymmetric algorithm and a public key
   from that set. Symmetric keys, private keys, and `alg=none` MUST NOT
   be accepted under this profile.
4. Verify `sub` exactly equals the requested `client_id`, then validate
   the remaining attestation and proof under the selected ATTEST method.
5. Apply grant and authorization policy independently of the endorsement.

Issuer and client identifiers MUST use exact, case-sensitive comparison
without URI normalization. Key selection and caches MUST bind keys to
the client identifier, endorsed issuer, and endorsed key location;
`kid` alone or a union of keys from different entries is insufficient.
Token-controlled key locations MUST NOT override the selected entry.

Failures specific to endorsement or attestation validation MUST use
`invalid_client_attestation`, without exposing policy details. This
profile deliberately also uses that error when a valid attestation's
issuer lacks an accepted endorsement. Other metadata-discovery,
registration, authentication, and grant errors follow their base
specifications. Unsupported or rejected delegation MUST NOT trigger
an unauthenticated fallback.

# Updates and Withdrawal {#updates}

The AS MUST enforce configured finite maximum ages for endorsement
metadata and JWK Sets used to accept presentations, applying HTTP
caching constraints {{RFC9111}} when stricter. It MUST revalidate or
refresh expired entries before use and MUST NOT use stale entries if
that operation fails. Network retrieval is not needed for each request
while the applicable entries remain fresh.

Once a metadata or key update is accepted, the AS MUST use it on the
next presentation. Removing an endorsement, removing a verification
key, or publishing an empty list prevents acceptance under that entry
or key, including for attestations issued before the update. Local
policy denial MUST take effect immediately on subsequent requests,
without waiting for cache expiration.

For planned key rotation, publish the new key before using it and
retain the old key while attestations signed with it should remain
acceptable. Metadata caches and JWKS caches have separate propagation
windows; the AS's configured maximum ages bound stale acceptance.
Withdrawal does not itself invalidate issued access tokens. Refresh
requests requiring client attestation are checked again under
{{processing}}; revoking already issued tokens requires separate action.

# Security Considerations

The considerations in {{ATTEST}}, {{CIMD}}, and {{RFC8725}} apply.

* **Publisher and attester compromise:** either can undermine client
  authentication. The AS's admission policy limits whose endorsements
  it accepts. Attesters serving several clients or tenants need issuance
  controls preventing one from obtaining attestations for another.
* **Key retrieval:** the AS MUST authenticate HTTPS servers, bound
  response sizes and request time, and prevent retrieval from prohibited
  network destinations. It MUST NOT follow redirects for `jwks_uri`
  retrieval. Endorsed URLs remain subject to SSRF defenses; endorsement
  does not make a network location safe.
* **Withdrawal latency:** an already cached endorsement or key can
  remain acceptable until its allowed age expires. Urgent incidents
  require local denial or another revocation channel; removing a key
  at its origin is not instantaneous revocation.
* **Privacy:** public metadata exposes client-to-attester relationships.
  It SHOULD NOT enumerate instances or their keys. Caching reduces the
  request-timing information observable at metadata and key endpoints.
  No stable instance identifier is required by this profile.

# IANA Considerations

This document requests registration in the OAuth Dynamic Client
Registration Metadata registry established by {{RFC7591}}:

* Client Metadata Name: `client_attesters`
* Client Metadata Description: Attesters endorsed to issue Client
  Attestations for this client, with their verification-key locations
* Change Controller: IETF
* Specification Document(s): {{metadata}} of this document

--- back

# CIMD Deployment Example {#example}
{:numbered="false"}

This example is informative. The AS's policy permits endorsements from
this client publisher. At `https://platform.example/oauth-client`, the
publisher serves:

~~~ json
{
  "client_id": "https://platform.example/oauth-client",
  "client_name": "Managed Agent Harness",
  "redirect_uris": ["https://platform.example/callback"],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "attest_jwt_client_auth_dpop",
  "client_attesters": [
    {
      "issuer": "https://attester.example/tenant/acme",
      "jwks_uri": "https://attester.example/tenant/acme/jwks"
    }
  ]
}
~~~

1. The runtime proves its authorization to use this client identifier
   and possession of its instance key to the attester.
2. The attester issues an ATTEST credential with
   `iss=https://attester.example/tenant/acme`,
   `sub=https://platform.example/oauth-client`, an expiration, and the
   instance public key in `cnf.jwk`.
3. After obtaining user authorization, the runtime redeems its code
   with that `client_id`, the Client Attestation, and combined DPoP proof.
4. The AS validates the CIMD, accepted endorsement, attestation, proof,
   and grant before issuing the access token.

There is one client metadata document, not one per installation.
An endorsement for this client does not let the attester authenticate
another client, even if both use the same attestation service.
The flow does not require `client_instance_id` or an `act` claim.

# Document History
{:numbered="false"}

*RFC EDITOR: Remove this section before publication.*

* Initial draft.
