# Secure alternatives when secret gist isn't enough

A secret GitHub Gist is unguessable but has no auth gate — anyone with the URL can read it. For sensitive content, use one of these patterns instead.

## Private repo + fine-grained PAT

Best for: ongoing internal docs that an agent needs read access to.

1. Create a private repo (or reuse one): `gh repo create kirollosatef/private-docs --private`.
2. Push the markdown file to the repo.
3. Create a fine-grained PAT scoped to **just that repo** with `Contents: Read-only`:
   - https://github.com/settings/personal-access-tokens/new
   - Resource owner: kirollosatef
   - Repository access: Only select repositories → pick the one
   - Permissions: Repository permissions → Contents → Read-only
4. Agent fetches with:
   ```bash
   curl -H "Authorization: Bearer $PAT" \
     https://raw.githubusercontent.com/kirollosatef/private-docs/main/file.md
   ```
5. Rotate the PAT regularly. One PAT per agent is even safer.

Pros: real auth, revocable, scoped. Cons: agent needs PAT in env.

## Cloudflare R2 presigned URL

Best for: ephemeral one-shot share with a hard expiry, no cleanup work.

1. Need an R2 bucket (`wrangler r2 bucket create kiro-share`) — one-time setup.
2. Upload + presign:
   ```bash
   wrangler r2 object put kiro-share/file.md --file ./file.md
   # Generate presigned URL via aws-cli pointed at R2:
   aws s3 presign s3://kiro-share/file.md \
     --endpoint-url https://<account>.r2.cloudflarestorage.com \
     --expires-in 3600
   ```
3. URL is signed for the TTL you specify (max 7d). After that, returns 403. No deletion needed — the file still exists in the bucket but is unreachable without a fresh signature.

Pros: TTL is cryptographic, not best-effort. No background scheduler. Cons: bucket setup, file still exists server-side.

## Cloudflare Worker + KV

Best for: pretty share URL with countdown page for humans + raw fetch for agents.

Sketch:
```js
export default {
  async fetch(req, env) {
    const id = new URL(req.url).pathname.slice(1);
    const meta = await env.KV.get(`meta:${id}`, 'json');
    if (!meta || Date.now() > meta.expiresAt) {
      return new Response('Expired', { status: 410 });
    }
    const ua = req.headers.get('user-agent') ?? '';
    const wantsRaw = req.headers.get('accept')?.includes('text/markdown')
      || /curl|wget|httpie|node-fetch|python-requests/i.test(ua)
      || new URL(req.url).searchParams.has('raw');

    const body = await env.KV.get(`body:${id}`);
    if (wantsRaw) {
      return new Response(body, { headers: { 'content-type': 'text/markdown' } });
    }
    // HTML wrapper with live countdown
    return new Response(renderHtml(body, meta.expiresAt), {
      headers: { 'content-type': 'text/html' }
    });
  }
}
```

Pros: human gets pretty page + countdown, agent gets raw. One URL. Cons: more setup, KV costs (negligible at this scale).

## Decision table

| Need | Use |
|------|-----|
| Quick share, low risk | secret Gist (this skill default) |
| Internal team, sensitive | Private repo + PAT |
| Hard cryptographic expiry | R2 presigned |
| Pretty UX + agent-friendly | Worker + KV |
| Compliance / audit trail | Private repo + PAT (commits are logged) |
