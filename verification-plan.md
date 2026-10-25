# Verification plan

| Area | Stimulus | Checker |
|---|---|---|
| Read/write data | Initialize 256 locations, 1000 constrained random accesses | Associative reference memory |
| Row conflict | Random rows in each bank | Command model checks tRAS/tRP/tRCD |
| Refresh | Reduced tREFI=80 | Command model rejects accesses during tRFC |
| Reset | Initial reset | Interface assertion disable iff |
| Handshake | Serialized request agent | Stable-request assertion |
| Liveness | Every accepted request | 100-cycle completion assertion |

Coverage records bank, direction, row and bank/direction cross. Protocol timing checking lives in the behavioral command model. Mid-transaction reset injection and quantitative coverage closure are extensions beyond the initial test.
