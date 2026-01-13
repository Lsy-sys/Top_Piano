## 系统时钟 (100MHz)
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clk]

## PS/2 键盘接口 (J4 接口由 PIC24 转换)
set_property -dict {PACKAGE_PIN K5  IOSTANDARD LVCMOS33} [get_ports ps2_clk]
set_property -dict {PACKAGE_PIN L4  IOSTANDARD LVCMOS33} [get_ports ps2_data]

## 音频输出接口 (J12 音频孔)
# AUDIO_PWM 信号输出到低通滤波器
set_property -dict {PACKAGE_PIN T1  IOSTANDARD LVCMOS33} [get_ports audio_pwm]
# AUDIO_SD 音频放大器关断信号（SD#），置1开启放大器输出
set_property -dict {PACKAGE_PIN M6  IOSTANDARD LVCMOS33} [get_ports audio_sd]