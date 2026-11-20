# maps_api_server

The OpenMaps push backend: a Serverpod server that watches Nostr relays for
NIP-59 gift wraps addressed to registered identities and forwards them — still
encrypted — over Firebase Cloud Messaging (default) or UnifiedPush. Neither the
transport provider nor a distributor can read the message.

See [`../docs/push.md`](../docs/push.md) for the registration protocol, the
configuration variables and the FCM credentials it needs.

Start it with:

    cd maps_api
    serverpod start

The OpenMaps app at the repository root is the client, through the generated
`maps_api_client` package.
