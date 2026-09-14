# Client Instance Identification: Implementation Guide

This guide is informative and is maintained separately from the
[Client Instance Identification draft](../draft-mcguinness-oauth-client-instance-id.md).
It illustrates deployment choices and introduces no protocol requirements
or enrollment procedure.

The attester in each pattern authenticates the instance and verifies
possession of its Client Instance Key before issuing a Client Attestation.
Authentication and proof processing follow
[CLIENT-ATTEST](https://www.ietf.org/ietf-ftp/internet-drafts/draft-ietf-oauth-attestation-based-client-auth-11.html).

## Attester Patterns

| Attester | Identified unit | Continuity evidence | Not distinguished |
|---|---|---|---|
| Mobile platform app-attestation service | Installation | Platform-attested key generated at install and bound to the app identity | Concurrent processes of one installation |
| Enterprise device management for a desktop agent | Installation | Device enrollment record and a hardware-backed key held by the managed installation | Reinstallation on the same device without re-enrollment |
| Container orchestrator or workload runtime | Execution | Runtime-assigned identity for one container execution; a restart yields a new identifier | Processes within that container execution |
| Function or job scheduler | Execution | Per-invocation or per-job environment identity | Retries that the platform treats as the same job |

The draft's instance lifetime and key continuity rules apply to each pattern. A device key
alone does not establish installation continuity; a workload identity
alone does not distinguish replicas. Assurance depends on the evidence
actually evaluated, as described in the draft's Security Considerations.

## Managed Application

Two installations of a managed mobile application share an OAuth
`client_id`:

1. An enterprise attester validates installation evidence and key
   possession, then assigns each installation a distinct identifier.
2. Each installation presents its attestation and proof to the IdP,
   which uses the issuer-qualified identifier for audit correlation.
3. Verified key replacement preserves the identifier; a clone or new
   installation receives another.

## Workload Replicas

Two container replicas share a SPIFFE workload identity but hold
separate Client Instance Keys:

1. A runtime attester validates workload identity, authenticated
   evidence identifying each execution, and possession of its key.
2. It issues each execution a Client Attestation for the configured
   Logical Client with a distinct `client_instance_id`.
3. The IdP validates the attestation and proof to correlate requests.
   Renewal preserves the identifier; a new execution receives another.

The shared workload identity alone cannot distinguish the replicas.

## Downstream Audit Correlation

An IdP conveys instance context to a downstream recipient:

1. After validating an attestation and proof, it assigns a
   recipient-scoped identifier and includes `client_instance` in a
   token or introspection response: `iss` identifies the IdP and `id`
   contains the mapped identifier.
2. The recipient validates the token or authenticated response and
   uses the pair for audit correlation without the original attestation.
3. The IdP preserves the mapping across verified key changes and uses
   different mappings for other recipients.

An IdP needing only local correlation can instead use its internal
enrollment mapping and ATTEST alone, without this profile.

## AAuth Agent Provider

An [AAuth Agent Provider](https://dickhardt.github.io/AAuth/draft-hardt-oauth-aauth-protocol.html) can also act as an OAuth Client Attester:

1. Its enrollment records and validated evidence establish installation
   continuity and key possession.
2. It issues a separate Client Attestation with the approved OAuth
   `client_id` as `sub` and an opaque `client_instance_id`.
3. The client presents that credential using ATTEST proof processing.

Native AAuth tokens and HTTP signatures retain their own semantics.
This example defines no token conversion or enrollment binding.
