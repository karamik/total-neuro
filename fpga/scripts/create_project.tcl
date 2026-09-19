# ========================================================================
# create_project.tcl – Automated Vivado project for TOTAL-Neuro FPGA demo
# Usage: vivado -mode batch -source fpga/scripts/create_project.tcl
# ========================================================================

set project_name "total_neuro_demo"
set part_name    "xc7a35ticsg324-1L"
set top_module   "top_fpga"
set board_name   "digilentinc.com:arty-a7-35:part0:1.1"

# ------------------------------------------------------------------------
# 1. Create project
# ------------------------------------------------------------------------
create_project $project_name ./build/$project_name -part $part_name -force
set_property BOARD_PART $board_name [current_project]
set_property target_language Verilog [current_project]

# ------------------------------------------------------------------------
# 2. Add RTL sources
# ------------------------------------------------------------------------
add_files -norecurse [list \
    ./fpga/top_fpga.sv \
    ./rtl/loader_fsm_asic.sv \
    ./rtl/active_shield.sv \
    ./rtl/dpa_noise_gen.sv \
    ./rtl/tmr_reg.sv \
    ./rtl/key_obfuscation.sv \
    ./rtl/puf_attestation.sv \
    ./rtl/firmware_signer_check.sv \
    ./rtl/apollo_kill_switch.sv \
    ./rtl/cycle_monitor.sv \
    ./rtl/shield_health_monitor.sv \
    ./rtl/security_integration.sv \
]

# ------------------------------------------------------------------------
# 3. Add constraints
# ------------------------------------------------------------------------
add_files -fileset constrs_1 -norecurse ./fpga/constraints/arty_a7.xdc

# ------------------------------------------------------------------------
# 4. Set top module
# ------------------------------------------------------------------------
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

# ------------------------------------------------------------------------
# 5. Run synthesis
# ------------------------------------------------------------------------
puts "=== Starting synthesis ==="
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}
puts "=== Synthesis complete ==="

# ------------------------------------------------------------------------
# 6. Run implementation
# ------------------------------------------------------------------------
puts "=== Starting implementation ==="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}
puts "=== Implementation complete ==="

# ------------------------------------------------------------------------
# 7. Report timing and utilization
# ------------------------------------------------------------------------
open_run impl_1
report_timing_summary -file ./build/$project_name/timing_summary.rpt
report_utilization  -file ./build/$project_name/utilization.rpt

puts "=== Bitstream generated: ./build/$project_name/$project_name.runs/impl_1/top_fpga.bit ==="
puts "=== To program: open_hw_manager; connect_hw_server; open_hw_target; ==="
puts "===            set_property PROGRAM.FILE {./build/.../top_fpga.bit} [current_hw_device] ; program_hw_devices [current_hw_device] ==="
