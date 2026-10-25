"""Run real UVM simulations, enforce scenario coverage, and test the scoreboard."""
import argparse
import json
from pathlib import Path
import resource
import subprocess
import xml.etree.ElementTree as ET


def validate(result, expected, reset):
    assert result["errors"] == result["fatals"] == 0, result
    assert result["checked"] == result["expected"] == expected, result
    assert result["reads"] + result["writes"] == expected, result
    assert all(count > 0 for bank in result["bank_direction"] for count in bank), result
    assert all(result[k] > 0 for k in ("row_hits", "conflicts", "refreshes", "resets")), result
    assert result["aborted"] == int(reset), result
    assert result["resets"] >= (2 if reset else 1), result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", default="obj_dir/Vtop")
    args = parser.parse_args()
    binary = str(Path(args.binary).resolve())
    output = Path("build/results").resolve()
    output.mkdir(parents=True, exist_ok=True)
    # A negative simulation exits through $fatal; do not leave a core dump.
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    suite = ET.Element("testsuite", name="UVM memory controller")
    summaries = []
    failures = 0
    scenarios = [("memory_test", seed, 1256, False) for seed in (1, 42, 2026)]
    scenarios += [("reset_recovery_test", 42, 1259, True)]
    scenarios += [("memory_test", 1, 1256, False)]  # corrupted read negative test
    for index, (test, seed, expected, reset) in enumerate(scenarios):
        negative = index == len(scenarios) - 1
        name = "scoreboard_rejects_corruption" if negative else f"{test}_seed_{seed}"
        directory = output / name
        directory.mkdir(exist_ok=True)
        case = ET.SubElement(suite, "testcase", name=name, classname="memory_regression")
        result_path = directory / "result.json"
        result_path.unlink(missing_ok=True)
        command = [binary, f"+UVM_TESTNAME={test}", f"+verilator+seed+{seed}",
                   f"+RESULT_JSON={result_path}"]
        if negative:
            command.append("+INJECT_READ_ERROR")
        try:
            process = subprocess.run(command, cwd=directory, capture_output=True, text=True, timeout=180)
            log = process.stdout + process.stderr
            (directory / "simulation.log").write_text(log)
            assert result_path.exists(), f"no result JSON; exit {process.returncode}\n{log[-4000:]}"
            result = json.loads(result_path.read_text())
            if negative:
                assert process.returncode != 0 and result["errors"] > 0 and "[DATA]" in log, result
                assert result["checked"] == expected, result
            else:
                assert process.returncode == 0, log[-4000:]
                validate(result, expected, reset)
            summaries.append({"name": name, "seed": seed, "passed": True, **result})
            print(f"PASS {name}: {result['checked']} checked, {result['errors']} errors"
                  + (" (expected rejection)" if negative else ""), flush=True)
        except (AssertionError, OSError, subprocess.TimeoutExpired, ValueError) as error:
            failures += 1
            ET.SubElement(case, "failure", message=str(error)).text = str(error)
            summaries.append({"name": name, "passed": False, "error": str(error)})
            print(f"FAIL {name}: {error}", flush=True)
    suite.set("tests", str(len(scenarios)))
    suite.set("failures", str(failures))
    ET.ElementTree(suite).write(output / "junit.xml", encoding="utf-8", xml_declaration=True)
    (output / "summary.json").write_text(json.dumps(summaries, indent=2) + "\n")
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
