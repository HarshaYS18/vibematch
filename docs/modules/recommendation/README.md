# Recommendation module

Owner: Recommendation Service.

Owns feature extraction, candidate scoring, ephemeral feed projection and
personalization availability. Does not own content, permissions, wallet, room or
identity state.

Kafka replay can rebuild feeds. Redis loss is therefore an availability/
personalization event rather than durable data loss.
