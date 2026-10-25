# Verification plan

| Area | Stimulus | Checker |
|---|---|---|
| Read/write data | Initialize 256 locations, 1000 constrained random accesses for each of three seeds | Associative reference memory; exact completion count |
| Row conflict | Random rows in each bank | Command model checks tRAS/tRP/tRCD |
| Refresh | Reduced tREFI=80 | Command model rejects accesses during tRFC |
| Reset | Initial reset and an interrupted write followed by readback and new write/read | Pending-request cancellation, unchanged stored data, reset/abort count gates |
| Handshake | Agent holds requests across refresh backpressure | Stable-request assertion |
| Liveness | Every accepted request | 100-cycle completion assertion |

| Checker sensitivity | Corrupt each returned data word via an explicit test-only switch | Regression requires nonzero simulator exit and a DATA error |

Native functional coverage records bank, direction, row and bank/direction cross. Portable counters independently gate all eight bank/direction combinations and require positive row-hit, bank-conflict, refresh and reset observations. The reset case requires one canceled transaction and at least two reset edges. Counts and simulator logs are written to per-run JSON and logs; the runner emits JUnit XML.

The behavioral memory retains data over a controller reset. Its command checker enforces tRAS/tRP/tRCD and rejects commands during tRFC. The test never reads an uninitialized location. The baseline initializes rows 0-3 of all four banks and randomly accesses rows 0-3, columns 0-3.

The controller accepts only one outstanding request. DDR burst data signaling, multi-request reordering, exhaustive timing-space exploration, asynchronous reset release, and physical interface timing are outside this model's scope.
