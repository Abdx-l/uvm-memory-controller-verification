# UVM Memory Controller Verification Environment

UVM transaction agent, sequencer, driver, passive monitor, reference-memory scoreboard, constrained-random traffic, functional coverage, and protocol assertions around a DDR-style controller. Includes the complete DUT and behavioral command checker.

## Run

On Linux x86_64 with glibc 2.28 or newer, install `g++` (C++20), `make`, `perl`, `curl`, and Python 3. Then run:

```sh
make test
```

The setup script downloads the pinned EDAPack Verilator **5.052** bundle, checks its SHA-256 digest, and uses its included IEEE 1800.2 UVM library and Bitwuzla constraint solver. No commercial simulator license is needed for this flow. Limit compilation parallelism with `JOBS=1` on smaller systems; the default is two jobs.

An existing bundle can be selected with `make test TOOL_ROOT=/absolute/path/to/verilator`. This is the distribution root containing `bin/` and `share/uvm/src/`.

The regression runs:

| Test | Seeds | Expected completed transactions |
|---|---|---|
| Initialization plus constrained-random read/write traffic | 1, 42, 2026 | 1,256 per seed |
| Interrupted write, reset, preserved-data readback, new write/read, random traffic | 42 | 1,259 |
| Deliberately corrupted read response | 1 | Must be rejected by the scoreboard |

All normal runs must complete with zero UVM errors/fatals, all eight bank/direction bins hit, and observed row hits, conflicts, refreshes, and reset. The reset test additionally requires exactly one aborted transaction and a second reset edge. The negative run succeeds as a regression case only when the simulator exits nonzero and the scoreboard reports a data mismatch.

`build/results/` contains per-run logs, JSON results, coverage data, the aggregate `summary.json`, and JUnit XML. GitHub Actions runs the same commands and uploads these files as the `uvm-regression` artifact. The reported scenario bins are gates, not a claim of exhaustive DDR or UVM coverage.

## Questa

Set `UVM_HOME` to an IEEE 1800.2-2020 UVM distribution root containing `src/`, then run:

```sh
vsim -c -do run_questa.do
```

The portable run disables optional UVM DPI routines. The behavioral memory checks tRCD, tRAS, tRP and tRFC. This is an educational command-scheduling controller, with one outstanding request, rather than a DDR PHY or a JEDEC-compliant memory device.

See [verification-plan.md](verification-plan.md) for the scenario/checker mapping.
