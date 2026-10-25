# UVM Memory Controller Verification Environment

UVM transaction agent, sequencer, driver, passive monitor, scoreboard, constrained-random traffic, functional coverage, and protocol assertions around a DDR-style controller. Includes the complete DUT and behavioral command checker.

## Run

Requires Questa with UVM support. Set UVM_HOME to a UVM 1.2 source directory and run `vsim -c -do run_questa.do`. See verification-plan.md for implemented scenarios and coverage scope.
