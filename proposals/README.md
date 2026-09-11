# WAG reciprocal integration patch

`wag-ai-agent-profile.patch` proposes the WAG-side integration with
this branch's AI Agent Instance Profile. WAG is maintained in a
[separate repository](https://github.com/pcarleton/draft-carleton-workload-authz-grant).
The patch has not been submitted upstream.

Base revision: `2c5222b411c6ff73bed92ec94622d0b2c8717bce` (retrieved 2026-09-10).
Source SHA-256: `cbca7cee50599d3af4388b45d5d9c049a943955a7964079f8443b36f6cd110b8`.

The patch adds the shared agent vocabulary, references the profile's
proof-of-possession and optional CIA composition rules, and keeps
WAG authorization properties separate from identity and provenance.
It preserves WAG's no-refresh-token rule and generic workload scope.

Apply from a WAG checkout at the base revision:

```sh
git apply --check /path/to/wag-ai-agent-profile.patch
git apply /path/to/wag-ai-agent-profile.patch
```

The reciprocal reference targets the AI draft as edited on this
branch; coordinate the draft revisions before upstream publication.
