#!/bin/bash

# --------------------------------------
# User variables
# --------------------------------------

# Set user gvsoc path 
GVSOC_PATH="/home/gvsoc/Documents/test/gvsoc"
# Set user magia-sdk path
MAGIA_SDK_PATH="/home/gvsoc/Documents/magia-sdk"
# Set the magia-sdk compilation toolchain
COMPILER=GCC_MULTILIB
# Set the list of mesh configuration to test. E.g., TILES="2 4" or TILES="2"
TILES="2 4"
# Set the simulation timeout
TIMEOUT="240"
# Set the list of error messages to search in the simulation logs
ERROR_PATTERNS=("Segmentation fault" "Aborted (core dumped)")
# --------------------------------------

# Default: both phases are on
RUN_SIMULATION=1
RUN_VERIFY=1

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --run)
            RUN_SIMULATION=1
            RUN_VERIFY=0
            ;;
        --verify)
            RUN_SIMULATION=0
            RUN_VERIFY=1
            ;;
        --all)
            RUN_SIMULATION=1
            RUN_VERIFY=1
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--run | --verify | --all]"
            exit 1
            ;;
    esac
done

CWD=`pwd`
SDK_TEST_LIST=`find $MAGIA_SDK_PATH/build/bin/ -type f ! -name "*.s"`

# -------------------------------
# Simulation / Build phase
# -------------------------------
if [ $RUN_SIMULATION -eq 1 ]; then
    echo "Start running simulations..."
    rm -rf MESH_*
    for tile in $TILES; do
        echo "Creating simulation files for MESH_${tile}x${tile}"
        mesh_path="$CWD/MESH_${tile}x${tile}"
        mkdir "$mesh_path"

        echo "Mooving to magia-sdk folder: $MAGIA_SDK_PATH... Run make" 
        cd $MAGIA_SDK_PATH
        make clean build compiler=$COMPILER tiles=$tile > $mesh_path/sdk-compile.log 2>&1
        echo "Going back to verification path: $CWD"
        cd $CWD

        echo "Mooving to GVSoC folder: $GVSOC_PATH..."
        cd $GVSOC_PATH
        echo "Prepare architecture for test MESH_${tile}x${tile} and run make..."
        sed -i "s/^    N_TILES_X.*/    N_TILES_X           = ${tile}/" $GVSOC_PATH/pulp/pulp/chips/magia/arch.py
        sed -i "s/^    N_TILES_Y.*/    N_TILES_Y           = ${tile}/" $GVSOC_PATH/pulp/pulp/chips/magia/arch.py
        make build TARGETS=magia DEBUG=1 > $mesh_path/gvsoc-compile.log 2>&1

        for test_bin_path in $SDK_TEST_LIST; do
            test_name=$(basename "$test_bin_path")
            echo "Running GVSoC on test $test_name"
            timeout $TIMEOUT ./install/bin/gvsoc --target=magia --binary=$test_bin_path --trace-level=trace run > $mesh_path/gvsoc-run_$test_name.log 2>&1
        done

        echo "Going back to verification path: $CWD"
        cd $CWD
    done
fi

# -------------------------------
# Post-processing / Verify phase
# -------------------------------
if [ $RUN_VERIFY -eq 1 ]; then
    echo "Start post processing simulation results..."

    all_failed_tests=()               # Global array for all failed tests
    total_tests_global=0
    passed_tests_global=0
    failed_tests_global=0

    for tile in $TILES; do
        echo "Checking simulation files for MESH_${tile}x${tile}"
        mesh_path="$CWD/MESH_${tile}x${tile}"

        failed_tests=()  # reset array array per each mesh

        for log in "$mesh_path"/gvsoc-run_*.log; do
            test_name=$(basename "$log" .log)

            if [ ! -s "$log" ]; then
                echo "⚠️  $log is empty → simulation not ended (TIMEOUT-EXPIRED or GVSoC STUCK)"
                failed_tests+=("$test_name")
                all_failed_tests+=("$test_name")
            else
                # Flag to check if test is failed
                error_found=0
                for pattern in "${ERROR_PATTERNS[@]}"; do
                    if grep -q "$pattern" "$log"; then
                        echo "❌  $log Simulation contains error pattern: '$pattern'"
                        failed_tests+=("$test_name")
                        all_failed_tests+=("$test_name")
                        error_found=1
                        break
                    fi
                done
                if [ $error_found -eq 0 ]; then
                    echo "✅  $log completed without detected errors"
                fi
            fi
        done

        # Coverage per mesh
        total_tests=$(find "$mesh_path" -type f -name "gvsoc-run_*.log" | wc -l)
        failed_count=${#failed_tests[@]}
        passed_count=$((total_tests - failed_count))
        coverage=$(( 100 * passed_count / total_tests ))

        echo
        echo "---- Coverage resume for MESH_${tile}x${tile} ----"
        echo "Total tests:   $total_tests"
        echo "Passed tests:  $passed_count"
        echo "Failed tests:  $failed_count"
        echo "Coverage:      $coverage %"

        if [ $failed_count -gt 0 ]; then
            echo "Failed test names:"
            for t in "${failed_tests[@]}"; do
                echo "  - $t"
            done
        fi
        echo "---------------------------------------------"

        # Update global counters
        total_tests_global=$((total_tests_global + total_tests))
        passed_tests_global=$((passed_tests_global + passed_count))
        failed_tests_global=$((failed_tests_global + failed_count))
    done

    # Global resume
    coverage_global=$(( 100 * passed_tests_global / total_tests_global ))

    echo
    echo "================== GLOBAL SUMMARY =================="
    echo "Total tests:   $total_tests_global"
    echo "Passed tests:  $passed_tests_global"
    echo "Failed tests:  $failed_tests_global"
    echo "Coverage:      $coverage_global %"
    echo "===================================================="
fi

# End of script
