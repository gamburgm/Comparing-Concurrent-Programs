# Test Harness Spec

## Test Specification
A `test` is a:
```json
{
  "candidates": ["candidate"],
  "regions": ["region"]
}
```

A `region` is a:
```json
{
  "name": "string",
  "voters": ["voter"]
}
```

A `candidate` is a:
```json
{
  "name": "string",
  "tax_rate": "number",
  "threshold": "number"
}
```

A `voter` is a:
```json
{
  "name": "string",
  "voting_method": "method"
}
```

A `method` is one of:
- StupidSort

A `StupidSort` is a:
```json
{
  "type": "stupid_sort",
  "candidate": "string"
}
```

## Test Results
A `result` is a:
```json
{
  "regions": ["RegionResult"],
  "winner": "string"
}
```

A `RegionResult` is a:
```json
{
  "name": "string",
  "rounds": ["round"],
  "winner": "string"
}
```

A `Round` is a:
```json
{
  "active_voters": ["string"],
  "active_cands": ["string"],
  "tally": "tally",
  "result": "round_result"
}
```

A `Tally` is a:
```json
{ "string": "number" }
```
Where the key represents the name of a candidate, and the value the number of votes that candidate received.

A `RoundResult` is a:
```json
{
  "type": "round_result_type",
  "candidate": "string"
}
```
Where the `candidate` value corresponds to the name of a candidate.

A `RoundResultType` is one of:
- `"Winner"`
- `"Loser"`
