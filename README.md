# GVSoC/MAGIA Test Automation

This Bash script automates the compilation, execution, and post-processing of tests for the **MAGIA** project based on **GVSoC**.

It allows you to:

* Compile MAGIA SDK binaries for different mesh configurations (`TILES`)
* Dynamically modify the chip topology in the Python file `pulp/pulp/chips/magia/arch.py`
* Run SDK tests on GVSoC with a configurable timeout
* Analyze execution logs to detect errors or unfinished simulations
* Generate **coverage reports** per mesh and globally

---

## Requirements

* Bash >= 4
* Make and properly configured MAGIA SDK toolchain
* GVSoC installed and buildable at the specified path

---

## Script Structure

The script is divided into two main phases:

### 1. Simulation / Build

* Compiles MAGIA SDK binaries (`make clean build`)
* Modifies `N_TILES_X` and `N_TILES_Y` in `pulp/pulp/chips/magia/arch.py`
* Builds GVSoC (`make build TARGETS=magia DEBUG=1`)
* Runs SDK tests on GVSoC, redirecting output to log files under `MESH_<tile>x<tile>/gvsoc-run_<test_name>.log`

### 2. Post-processing / Verification

* Scans test logs
* Detects:

  * **Empty log files** → simulation not completed / timeout
  * Errors present in logs using the `ERROR_PATTERNS` list
* Calculates **coverage**:

  * Per mesh
  * Global
* Prints a detailed summary including failed test names

---

## User Configuration

At the beginning of the script, you can configure:

| Variable         | Description                                         | Example                                              |
| ---------------- | --------------------------------------------------- | ---------------------------------------------------- |
| `GVSOC_PATH`     | Path to GVSoC folder                                | `/home/gvsoc/Documents/test/gvsoc`                   |
| `MAGIA_SDK_PATH` | Path to MAGIA SDK folder                            | `/home/gvsoc/Documents/magia-sdk`                    |
| `COMPILER`       | Toolchain to compile MAGIA SDK                      | `GCC_MULTILIB`                                       |
| `TILES`          | List of mesh sizes to test                          | `"2 4"`                                              |
| `TIMEOUT`        | Maximum timeout for each GVSoC test (seconds)       | `240`                                                |
| `ERROR_PATTERNS` | List of patterns to search in logs to detect errors | `(\"Segmentation fault\" \"Aborted (core dumped)\")` |

---

## Execution

### Available Options

| Flag       | Description                                      |
| ---------- | ------------------------------------------------ |
| `--run`    | Run only the simulation/build phase              |
| `--verify` | Run only the post-processing/verification phase  |
| `--all`    | Run both phases (default if no flag is provided) |

### Examples

Run only the simulation:

```bash
./run_simulations.sh --run
```

Run only the log verification:

```bash
./run_simulations.sh --verify
```

Run both simulation and verification:

```bash
./run_simulations.sh --all
```

---

## Output

* Directories created per mesh: `MESH_<tile>x<tile>`
* SDK compilation log: `sdk-compile.log`
* GVSoC compilation log: `gvsoc-compile.log`
* Test execution logs: `gvsoc-run_<test_name>.log`
* Post-processing prints:

  * Coverage per mesh
  * Global coverage
  * List of failed tests

---

## Log Interpretation

* **Empty logs** → simulation not finished / timeout
* **Logs containing error patterns** → simulation completed but failed

---

## Customization

* Add new error patterns by editing the `ERROR_PATTERNS` array
* Adjust the timeout via `TIMEOUT`
* Change the mesh list using `TILES`

