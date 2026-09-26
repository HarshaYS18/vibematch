# Search Service tests

`test_contracts.py` locks explicit search-projection event semantics.
`test_projector.py` verifies ACK-after-projection-write and NAK-on-OpenSearch-failure.
Repository guards additionally prohibit synchronous database+OpenSearch dual writes.
