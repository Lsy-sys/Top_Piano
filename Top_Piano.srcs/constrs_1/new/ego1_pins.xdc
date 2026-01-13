## 时钟与音频
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clk]
set_property -dict {PACKAGE_PIN T1  IOSTANDARD LVCMOS33} [get_ports audio_pwm]
set_property -dict {PACKAGE_PIN M6  IOSTANDARD LVCMOS33} [get_ports audio_sd]

## PS2 接口
set_property -dict {PACKAGE_PIN K5  IOSTANDARD LVCMOS33} [get_ports ps2_clk]
set_property -dict {PACKAGE_PIN L4  IOSTANDARD LVCMOS33} [get_ports ps2_data]

## 数码管段选 (LED0)
set_property -dict {PACKAGE_PIN B4  IOSTANDARD LVCMOS33} [get_ports {seg0[0]}] ;# A0
set_property -dict {PACKAGE_PIN A4  IOSTANDARD LVCMOS33} [get_ports {seg0[1]}] ;# B0
set_property -dict {PACKAGE_PIN A3  IOSTANDARD LVCMOS33} [get_ports {seg0[2]}] ;# C0
set_property -dict {PACKAGE_PIN B1  IOSTANDARD LVCMOS33} [get_ports {seg0[3]}] ;# D0
set_property -dict {PACKAGE_PIN A1  IOSTANDARD LVCMOS33} [get_ports {seg0[4]}] ;# E0
set_property -dict {PACKAGE_PIN B3  IOSTANDARD LVCMOS33} [get_ports {seg0[5]}] ;# F0
set_property -dict {PACKAGE_PIN B2  IOSTANDARD LVCMOS33} [get_ports {seg0[6]}] ;# G0
set_property -dict {PACKAGE_PIN D5  IOSTANDARD LVCMOS33} [get_ports {seg0[7]}] ;# DP0

## 数码管段选 (LED1)
set_property -dict {PACKAGE_PIN D4  IOSTANDARD LVCMOS33} [get_ports {seg1[0]}] ;# A1
set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports {seg1[1]}] ;# B1
set_property -dict {PACKAGE_PIN D3  IOSTANDARD LVCMOS33} [get_ports {seg1[2]}] ;# C1
set_property -dict {PACKAGE_PIN F4  IOSTANDARD LVCMOS33} [get_ports {seg1[3]}] ;# D1
set_property -dict {PACKAGE_PIN F3  IOSTANDARD LVCMOS33} [get_ports {seg1[4]}] ;# E1
set_property -dict {PACKAGE_PIN E2  IOSTANDARD LVCMOS33} [get_ports {seg1[5]}] ;# F1
set_property -dict {PACKAGE_PIN D2  IOSTANDARD LVCMOS33} [get_ports {seg1[6]}] ;# G1
set_property -dict {PACKAGE_PIN H2  IOSTANDARD LVCMOS33} [get_ports {seg1[7]}] ;# DP1

## 数码管位选
set_property -dict {PACKAGE_PIN G2  IOSTANDARD LVCMOS33} [get_ports {seg_en[0]}] ;# DN0_K1
set_property -dict {PACKAGE_PIN C2  IOSTANDARD LVCMOS33} [get_ports {seg_en[1]}] ;# DN0_K2
set_property -dict {PACKAGE_PIN C1  IOSTANDARD LVCMOS33} [get_ports {seg_en[2]}] ;# DN0_K3
set_property -dict {PACKAGE_PIN H1  IOSTANDARD LVCMOS33} [get_ports {seg_en[3]}] ;# DN0_K4
set_property -dict {PACKAGE_PIN G1  IOSTANDARD LVCMOS33} [get_ports {seg_en[4]}] ;# DN1_K1
set_property -dict {PACKAGE_PIN F1  IOSTANDARD LVCMOS33} [get_ports {seg_en[5]}] ;# DN1_K2
set_property -dict {PACKAGE_PIN E1  IOSTANDARD LVCMOS33} [get_ports {seg_en[6]}] ;# DN1_K3
set_property -dict {PACKAGE_PIN G6  IOSTANDARD LVCMOS33} [get_ports {seg_en[7]}] ;# DN1_K4