set_global_assignment -entity "fastPll" -library "lib_fastPll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "fastPll" -library "lib_fastPll" -name IP_TOOL_VERSION "18.0"
set_global_assignment -entity "fastPll" -library "lib_fastPll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_fastPll" -name SPD_FILE [file join $::quartus(sip_path) "fastPll.spd"]

set_global_assignment -library "lib_fastPll" -name MISC_FILE [file join $::quartus(sip_path) "fastPll_sim/fastPll.vo"]
