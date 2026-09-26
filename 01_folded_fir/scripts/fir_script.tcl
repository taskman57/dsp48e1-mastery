# ==============================================================================
# Vivado Project Generation Script (Project Mode)
# Script Location: 01_folded_fir/scripts/fir_script.tcl
# ==============================================================================

# Determine paths relative to the scripts/ folder
set script_dir [file dirname [file normalize [info script]]]
set module_dir [file normalize "$script_dir/.."]

# Project Configuration
set proj_name        "folded_fir_proj"
set target_part      "xc7z020clg400-1"
set top_design_name  "range_detector"
set top_tb_name      "tb_range_detector"
set proj_dir         "$module_dir/project"

# 1. Create Vivado Project
create_project $proj_name $proj_dir -part $target_part -force

# 2. Configure Language Properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# 3. Import IP Cores (.xci)
if {[file exists "$module_dir/ipcores"]} {
    set ip_files [glob -nocomplain -directory "$module_dir/ipcores" -type f "*/*.xci"]
    if {[llength $ip_files] > 0} {
        puts "--> Adding IP cores: $ip_files"
        read_ip $ip_files
        generate_target all [get_files $ip_files]
    }
}

# 4. Import Design Sources (HDL)
if {[file exists "$module_dir/hdl"]} {
    puts "--> Adding HDL sources from $module_dir/hdl..."
    add_files -fileset sources_1 "$module_dir/hdl"
    set hdl_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == VHDL}]
    if {[llength $hdl_files] > 0} {
        set_property file_type {VHDL} $hdl_files
    }
}

# 5. Import Simulation Sources (Includes testbenches and golden vector packages)
if {[file exists "$module_dir/sim"]} {
    puts "--> Adding simulation sources and golden reference packages from $module_dir/sim..."
    add_files -fileset sim_1 "$module_dir/sim"
    set sim_files [get_files -of_objects [get_filesets sim_1] -filter {FILE_TYPE == VHDL}]
    if {[llength $sim_files] > 0} {
        set_property file_type {VHDL} $sim_files
    }
}

# 6. Update Compile Order and Set Top Modules
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[get_filesets sources_1] ne ""} {
    set_property top $top_design_name [get_filesets sources_1]
    update_compile_order -fileset sources_1
}

if {[get_filesets sim_1] ne ""} {
    set_property top $top_tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

puts "=========================================================================="
puts " Project '$proj_name' created successfully at:"
puts " $proj_dir"
puts " Top Level Entity: $top_design_name"
puts " Simulation Top:   $top_tb_name"
puts "=========================================================================="