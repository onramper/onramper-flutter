# Backend session endpoint

`OnramperClient.initialize` and `sessionExpirationHandler` both consume a `{sessionId, sessionToken}` pair. That pair **must be minted server-side** — the request that produces it is signed with your partner's Ed25519 SigV2 key, which never leaves your servers. This document describes the upstream endpoint your backend calls and provides a reference implementation.

> The partner secret **never** leaves your servers. The mobile app calls _your_ endpoint, which then signs and calls Onramper's upstream endpoint. Do not embed the private key or long-lived credentials in the Flutter bundle.

## Upstream endpoint

```
POST {UPSTREAM}/partners/v2/{apiKey}/client-sessions
```

Where `{UPSTREAM}` is:

| Environment | URL |
|---|---|
| Staging | `https://api-stg.onramper.com` |
| Production | `https://api.onramper.com` |

### Request

Body:

```json
{
  "scope": ["quotes:read", "checkout:write"]
}
```

Headers (SigV2 signing — see the [Onramper partner API docs](https://onramper.com/docs) for full detail):

- `X-Onramper-Signature-Version: v2`
- `X-Onramper-Timestamp: <unix seconds>`
- `X-Onramper-Signature: <base64 Ed25519 signature over "<method>\n<path>\n<timestamp>\n<sha256(body)>">`

### Response (201)

```json
{
  "sessionId": "sess_01H...",
  "sessionToken": "eyJhbGciOi..."
}
```

The response is opaque, single-use for the initial bind, and time-bounded. Return it verbatim to your Flutter app.

## Reference implementation (Node.js + Fastify)

```ts
import Fastify from 'fastify';
import { createHash, createPrivateKey, sign } from 'node:crypto';

const UPSTREAM = process.env.ONRAMPER_UPSTREAM ?? 'https://api.onramper.com';
const API_KEY = process.env.ONRAMPER_API_KEY!;
// Ed25519 private key in PKCS8 PEM. Store in a secrets manager, not the repo.
const PRIVATE_KEY = createPrivateKey(process.env.ONRAMPER_ED25519_PRIVATE_KEY_PEM!);

const app = Fastify();

app.post('/onramper/session', async (request, reply) => {
  // 1) Authenticate the end user against your own auth system.
  const user = await authenticate(request);
  if (!user) return reply.code(401).send({ error: 'unauthorized' });

  // 2) Sign the SigV2 request.
  const path = `/partners/v2/${API_KEY}/client-sessions`;
  const method = 'POST';
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const body = JSON.stringify({ scope: ['quotes:read', 'checkout:write'] });
  const bodyHash = createHash('sha256').update(body).digest('hex');
  const message = `${method}\n${path}\n${timestamp}\n${bodyHash}`;
  const signature = sign(null, Buffer.from(message), PRIVATE_KEY).toString('base64');

  // 3) Forward to Onramper upstream.
  const response = await fetch(`${UPSTREAM}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      'x-onramper-signature-version': 'v2',
      'x-onramper-timestamp': timestamp,
      'x-onramper-signature': signature,
    },
    body,
  });
  if (!response.ok) {
    const text = await response.text();
    request.log.error({ status: response.status, body: text }, 'upstream error');
    return reply.code(502).send({ error: 'upstream_error' });
  }

  // 4) Return the (sessionId, sessionToken) verbatim.
  const json = (await response.json()) as { sessionId: string; sessionToken: string };
  return reply.code(201).send(json);
});

async function authenticate(request: Fastify.FastifyRequest): Promise<{ id: string } | null> {
  // Your own auth layer — e.g. verify a bearer token, session cookie, etc.
  // Do NOT expose this endpoint unauthenticated.
  return null;
}

app.listen({ port: 3000 });
```

## Client-side wiring

Once your endpoint returns the pair, plug it into `OnramperClient`:

```dart
Future<SessionCredentials> mintSession() async {
  final response = await http.post(
    Uri.parse('https://your-app-backend.example.com/onramper/session'),
    headers: {
      'authorization': 'Bearer $userAuthToken',
      'content-type': 'application/json',
    },
  );
  if (response.statusCode != 201) {
    throw StateError('Failed to mint Onramper session: ${response.statusCode}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return SessionCredentials(
    sessionId: json['sessionId'] as String,
    sessionToken: json['sessionToken'] as String,
  );
}

// One-shot at app start / user login:
final pair = await mintSession();
await client.initialize(sessionId: pair.sessionId, sessionToken: pair.sessionToken);

// Every future refresh: reuse the same fetcher.
final client = OnramperClient(
  configuration: /* ... */,
  sessionExpirationHandler: mintSession,
);
```

## Notes

- **The `sessionExpirationHandler` fires rarely** — only when the SDK's silent refresh + re-bootstrap paths are exhausted. In steady state this may be days or weeks apart. Your endpoint should still be idempotent and fast.
- **Do not cache the returned token.** It's already bound to the device's DPoP key by the SDK's `initialize` call. Caching it in your backend or the app buys nothing and creates a stale-token risk.
- **Never** expose the raw SigV2 signing endpoint or the private key to the mobile app.
- The scope list (`["quotes:read", "checkout:write"]`) is required for the Flutter SDK. Additional scopes are not needed unless you're using the API for something outside the on-ramp flow.
