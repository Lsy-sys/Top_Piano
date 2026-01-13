`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/13 10:52:07
// Design Name: 
// Module Name: Top_Piano
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module Top_Piano(
    input clk,           // 系统时钟 P17
    input ps2_clk,       // PS2时钟 K5
    input ps2_data,      // PS2数据 L4
    output audio_pwm,    // PWM输出 T1
    output audio_sd      // 音频使能 M6
);

    // --- 1. 信号定义与初始化 ---
    assign audio_sd = 1'b1; // 高电平启用音频放大器
    
    reg [3:0]  ps2_cnt = 0;
    reg [10:0] ps2_buffer = 0;
    reg [7:0]  key_code = 0;
    reg        key_valid = 0;
    reg        ps2_clk_sync, ps2_clk_last;
    
    reg [17:0] period_reg = 0; // 存储当前音阶的分频阈值
    reg [17:0] pwm_cnt = 0;    // PWM分频计数器
    reg        pwm_out = 0;
    reg        is_break = 0;   // PS/2断码标识（F0）

    assign audio_pwm = pwm_out;

    // --- 2. PS/2 物理层异步信号同步 ---
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_last <= ps2_clk_sync;
    end
    wire ps2_fall = (ps2_clk_last && !ps2_clk_sync); // 检测PS2时钟下降沿

    // --- 3. PS/2 串行接收逻辑 (行为级) ---
    always @(posedge clk) begin
        if (ps2_fall) begin
            ps2_buffer[ps2_cnt] <= ps2_data;
            if (ps2_cnt == 4'd10) begin
                ps2_cnt <= 4'd0;
                key_code <= ps2_buffer[8:1]; // 提取8位扫描码
                key_valid <= 1'b1;
            end else begin
                ps2_cnt <= ps2_cnt + 4'd1;
                key_valid <= 1'b0;
            end
        end else begin
            key_valid <= 1'b0;
        end
    end

    // --- 4. 键盘扫描码处理与音阶映射 (功能隔离) ---
    // 阈值计算：100,000,000Hz / (频率 * 2)
    always @(posedge clk) begin
        if (key_valid) begin
            if (key_code == 8'hF0) begin
                is_break <= 1'b1; // 检测到断码前缀
            end else if (is_break) begin
                period_reg <= 18'd0; // 松开按键，分频设为0（静音）
                is_break <= 1'b0;
            end else begin
                case (key_code)
                    8'h16: period_reg <= 18'd191113; // 数字键1 -> Do (261.6Hz)
                    8'h1E: period_reg <= 18'd170262; // 数字键2 -> Re (293.7Hz)
                    8'h26: period_reg <= 18'd151685; // 数字键3 -> Mi (329.6Hz)
                    8'h25: period_reg <= 18'd143173; // 数字键4 -> Fa (349.2Hz)
                    8'h2E: period_reg <= 18'd127553; // 数字键5 -> So (392.0Hz)
                    8'h36: period_reg <= 18'd113636; // 数字键6 -> La (440.0Hz)
                    8'h3D: period_reg <= 18'd101238; // 数字键7 -> Si (493.9Hz)
                    default: period_reg <= period_reg;
                endcase
            end
        end
    end

    // --- 5. 音频 PWM 发生器 (行为级，严禁除法/取模) ---
    always @(posedge clk) begin
        if (period_reg == 18'd0) begin
            pwm_cnt <= 18'd0;
            pwm_out <= 1'b0;
        end else if (pwm_cnt >= period_reg) begin
            pwm_cnt <= 18'd0;
            pwm_out <= !pwm_out; // 翻转电平产生方波
        end else begin
            pwm_cnt <= pwm_cnt + 18'd1;
        end
    end

endmodule