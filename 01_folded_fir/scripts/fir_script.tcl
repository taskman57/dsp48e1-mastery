# ==============================================================================
# Vivado Project Generation Script (Project Mode)
# Script Location: 01_folded_fir/scripts/fir_script.tcl
# ==============================================================================

# Determine paths relative to the scripts/ folder
set script_dir [file dirname [file normalize [info script]]]
set module_dir [file normalize "$script_dir/.."]

# Project Configuration
set proj_name     "folded_fir_proj"
set target_part   "xc7z020clg400-1"
set top_tb_name   "tb_fir_impl"
set proj_dir      "$module_dir/project"

# 1. Create Vivado Project
create_project $proj_name $proj_dir -part $target_part -force

# 2. Configure Language Properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# 3. Import Design Sources (HDL)
if {[file exists "$module_dir/hdl"]} {
    # Add all VHDL files from the hdl directory to sources_1
    add_files -fileset sources_1 "$module_dir/hdl"
    
    set hdl_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == VHDL}]
    if {[llength $hdl_files] > 0} {
        set_property file_type {VHDL} $hdl_files
    }

    # Ensure dsp_package.vhd is explicitly marked active for synthesis and simulation
    set dsp_pkg "$module_dir/hdl/dsp_package.vhd"
    if {[file exists $dsp_pkg]} {
        set_property used_in_synthesis true  [get_files $dsp_pkg]
        set_property used_in_simulation true [get_files $dsp_pkg]
    }
}

# 4. Import Simulation Sources and Waveform Configurations
if {[file exists "$module_dir/sim"]} {
    add_files -fileset sim_1 "$module_dir/sim"
    set sim_files [get_files -of_objects [get_filesets sim_1] -filter {FILE_TYPE == VHDL}]
    if {[llength $sim_files] > 0} {
        set_property file_type {VHDL} $sim_files
    }

    # Automatically load waveform configuration if it exists
    set wcfg_file [glob -nocomplain "$module_dir/sim/*.wcfg"]
    if {[llength $wcfg_file] > 0} {
        set_property xsim.simulate.custom_wcfg $wcfg_file [get_filesets sim_1]
    }
}

# 5. Update Compile Order and Set Testbench Top
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[get_filesets sim_1] ne ""} {
    set_property top $top_tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

puts "=========================================================================="
puts " Project '$proj_name' created successfully at:"
puts " $proj_dir"
puts "=========================================================================="