## 时钟 (100MHz)
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clk]

## 开关
set_property -dict {PACKAGE_PIN P5  IOSTANDARD LVCMOS33} [get_ports sw0] ;# 总开关
set_property -dict {PACKAGE_PIN N4  IOSTANDARD LVCMOS33} [get_ports sw1] ;# 自动演奏开关 (手册5.2)
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports btn_s4]
set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports btn_r11]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports btn_r17]
set_property -dict {PACKAGE_PIN P4  IOSTANDARD LVCMOS33} [get_ports sw2]

## 音频输出
set_property -dict {PACKAGE_PIN T1  IOSTANDARD LVCMOS33} [get_ports audio_pwm]
set_property -dict {PACKAGE_PIN M6  IOSTANDARD LVCMOS33} [get_ports audio_sd]

## PS2 接口
set_property -dict {PACKAGE_PIN K5  IOSTANDARD LVCMOS33} [get_ports ps2_clk]
set_property -dict {PACKAGE_PIN L4  IOSTANDARD LVCMOS33} [get_ports ps2_data]

## 数码管段选与位选 (共阴极，高电平点亮)
set_property -dict {PACKAGE_PIN B4  IOSTANDARD LVCMOS33} [get_ports {seg0[0]}]
set_property -dict {PACKAGE_PIN A4  IOSTANDARD LVCMOS33} [get_ports {seg0[1]}]
set_property -dict {PACKAGE_PIN A3  IOSTANDARD LVCMOS33} [get_ports {seg0[2]}]
set_property -dict {PACKAGE_PIN B1  IOSTANDARD LVCMOS33} [get_ports {seg0[3]}]
set_property -dict {PACKAGE_PIN A1  IOSTANDARD LVCMOS33} [get_ports {seg0[4]}]
set_property -dict {PACKAGE_PIN B3  IOSTANDARD LVCMOS33} [get_ports {seg0[5]}]
set_property -dict {PACKAGE_PIN B2  IOSTANDARD LVCMOS33} [get_ports {seg0[6]}]
set_property -dict {PACKAGE_PIN D5  IOSTANDARD LVCMOS33} [get_ports {seg0[7]}]

set_property -dict {PACKAGE_PIN D4  IOSTANDARD LVCMOS33} [get_ports {seg1[0]}]
set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports {seg1[1]}]
set_property -dict {PACKAGE_PIN D3  IOSTANDARD LVCMOS33} [get_ports {seg1[2]}]
set_property -dict {PACKAGE_PIN F4  IOSTANDARD LVCMOS33} [get_ports {seg1[3]}]
set_property -dict {PACKAGE_PIN F3  IOSTANDARD LVCMOS33} [get_ports {seg1[4]}]
set_property -dict {PACKAGE_PIN E2  IOSTANDARD LVCMOS33} [get_ports {seg1[5]}]
set_property -dict {PACKAGE_PIN D2  IOSTANDARD LVCMOS33} [get_ports {seg1[6]}]
set_property -dict {PACKAGE_PIN H2  IOSTANDARD LVCMOS33} [get_ports {seg1[7]}]

set_property -dict {PACKAGE_PIN G2  IOSTANDARD LVCMOS33} [get_ports {seg_en[0]}]
set_property -dict {PACKAGE_PIN C2  IOSTANDARD LVCMOS33} [get_ports {seg_en[1]}]
set_property -dict {PACKAGE_PIN C1  IOSTANDARD LVCMOS33} [get_ports {seg_en[2]}]
set_property -dict {PACKAGE_PIN H1  IOSTANDARD LVCMOS33} [get_ports {seg_en[3]}]
set_property -dict {PACKAGE_PIN G1  IOSTANDARD LVCMOS33} [get_ports {seg_en[4]}]
set_property -dict {PACKAGE_PIN F1  IOSTANDARD LVCMOS33} [get_ports {seg_en[5]}]
set_property -dict {PACKAGE_PIN E1  IOSTANDARD LVCMOS33} [get_ports {seg_en[6]}]
set_property -dict {PACKAGE_PIN G6  IOSTANDARD LVCMOS33} [get_ports {seg_en[7]}]


## VGA 红色分量 (High to Low: B7, C5, C6, F5)
set_property -dict {PACKAGE_PIN B7  IOSTANDARD LVCMOS33} [get_ports {vga_r[3]}]
set_property -dict {PACKAGE_PIN C5  IOSTANDARD LVCMOS33} [get_ports {vga_r[2]}]
set_property -dict {PACKAGE_PIN C6  IOSTANDARD LVCMOS33} [get_ports {vga_r[1]}]
set_property -dict {PACKAGE_PIN F5  IOSTANDARD LVCMOS33} [get_ports {vga_r[0]}]

## VGA 绿色分量 (High to Low: D8, A5, A6, B6)
set_property -dict {PACKAGE_PIN D8  IOSTANDARD LVCMOS33} [get_ports {vga_g[3]}]
set_property -dict {PACKAGE_PIN A5  IOSTANDARD LVCMOS33} [get_ports {vga_g[2]}]
set_property -dict {PACKAGE_PIN A6  IOSTANDARD LVCMOS33} [get_ports {vga_g[1]}]
set_property -dict {PACKAGE_PIN B6  IOSTANDARD LVCMOS33} [get_ports {vga_g[0]}]

## VGA 蓝色分量 (High to Low: E7, E5, E6, C7)
set_property -dict {PACKAGE_PIN E7  IOSTANDARD LVCMOS33} [get_ports {vga_b[3]}]
set_property -dict {PACKAGE_PIN E5  IOSTANDARD LVCMOS33} [get_ports {vga_b[2]}]
set_property -dict {PACKAGE_PIN E6  IOSTANDARD LVCMOS33} [get_ports {vga_b[1]}]
set_property -dict {PACKAGE_PIN C7  IOSTANDARD LVCMOS33} [get_ports {vga_b[0]}]

## VGA 同步信号
set_property -dict {PACKAGE_PIN D7  IOSTANDARD LVCMOS33} [get_ports vga_hs]
set_property -dict {PACKAGE_PIN C4  IOSTANDARD LVCMOS33} [get_ports vga_vs]