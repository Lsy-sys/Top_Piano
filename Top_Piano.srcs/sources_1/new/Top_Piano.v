module Top_Piano(
    input clk,           // 100MHz 系统时钟 (P17)
    input ps2_clk,       // PS2 时钟 (K5)
    input ps2_data,      // PS2 数据 (L4)
    input sw0,           // 总开关/全局复位 (P5)
    input sw1,           // 自动演奏开关 (N4)
    output audio_pwm,    // 音频 PWM 输出 (T1)
    output audio_sd,     // 音频芯片使能 (M6)
    output [7:0] seg0,   
    output [7:0] seg1,   
    output [7:0] seg_en  
);
    // --- 内部信号定义 ---
    assign audio_sd = sw0; 
    
    // PS2 接收相关
    reg [3:0]  ps2_cnt = 0;
    reg [10:0] ps2_buffer = 0;
    reg [7:0]  key_code = 0;
    reg        key_valid = 0;
    reg        ps2_clk_sync, ps2_clk_last;
    reg        is_break = 0;

    // 自动播放相关
    reg [24:0] beat_cnt = 0;      // 0.25秒计数器 (100M / 4)
    reg [5:0]  score_ptr = 0;     // 乐谱指针
    reg [7:0]  auto_key_code = 0; // 自动输出的键值

    // 核心控制信号
    reg [17:0] period_reg = 0; 
    reg [17:0] pwm_cnt = 0;
    reg        pwm_out = 0;
    reg [3:0]  display_num = 4'h0;
    reg [3:0]  octave_num = 4'h0;

    // --- 新增：模式切换检测与复位逻辑 ---
    reg sw1_reg;
    always @(posedge clk) sw1_reg <= sw1;
    // 当 sw1 状态改变（拨动开关）时产生一个周期的复位脉冲
    wire mode_change_reset = (sw1 ^ sw1_reg); 

    // 选择当前的输入源
    wire [7:0] current_key = (sw1) ? auto_key_code : key_code;
    // 增加逻辑：切换模式时强制 valid 为 0，直到下一个节拍
    wire       current_valid = (mode_change_reset) ? 1'b0 : ((sw1) ? (beat_cnt == 25'd1) : key_valid);

    // --- 自动演奏断奏逻辑 ---
    // 定义前 20,000,000 周期为发声时间，后 5,000,000 周期为静音间隔
    wire auto_mute = (sw1 && beat_cnt > 25'd20_000_000); 

    // 修改输出赋值：模式切换瞬间或静音期强制输出 0
    assign audio_pwm = pwm_out & sw0 & !auto_mute & !mode_change_reset; 

    // --- 1. PS2 接收逻辑 ---
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_last <= ps2_clk_sync;
    end
    wire ps2_fall = (ps2_clk_last && !ps2_clk_sync);

    always @(posedge clk) begin
        if (!sw0 || mode_change_reset) begin // 增加模式切换复位
            ps2_cnt <= 4'd0;
            key_valid <= 1'b0;
        end else if (ps2_fall) begin
            ps2_buffer[ps2_cnt] <= ps2_data;
            if (ps2_cnt == 4'd10) begin
                ps2_cnt <= 4'd0;
                key_code <= ps2_buffer[8:1];
                key_valid <= 1'b1;
            end else ps2_cnt <= ps2_cnt + 4'd1;
        end else key_valid <= 1'b0;
    end

    parameter K1=8'h15, K2=8'h1D, K3=8'h24, K4=8'h2D, K5=8'h2C, K6=8'h35, K7=8'h3C, NO=8'hF0;

    always @(posedge clk) begin
        if (!sw1 || !sw0 || mode_change_reset) begin // 增加模式切换复位
            beat_cnt <= 0;
            score_ptr <= 0;
        end else begin
            if (beat_cnt >= 25_000_000) begin
                beat_cnt <= 0;
                score_ptr <= (score_ptr >= 6'd32) ? 0 : score_ptr + 1;
            end else beat_cnt <= beat_cnt + 1;
        end
    end

    always @(*) begin
        case(score_ptr)
            0: auto_key_code = K1; 1: auto_key_code = K1; 2: auto_key_code = K5; 3: auto_key_code = K5;
            4: auto_key_code = K6; 5: auto_key_code = K6; 6: auto_key_code = K5; 7: auto_key_code = NO;
            8: auto_key_code = K4; 9: auto_key_code = K4; 10: auto_key_code = K3; 11: auto_key_code = K3;
            12: auto_key_code = K2; 13: auto_key_code = K2; 14: auto_key_code = K1; 15: auto_key_code = NO;
            16: auto_key_code = K5; 17: auto_key_code = K5; 18: auto_key_code = K4; 19: auto_key_code = K4;
            20: auto_key_code = K3; 21: auto_key_code = K3; 22: auto_key_code = K2; 23: auto_key_code = NO;
            24: auto_key_code = K5; 25: auto_key_code = K5; 26: auto_key_code = K4; 27: auto_key_code = K4;
            28: auto_key_code = K3; 29: auto_key_code = K3; 30: auto_key_code = K2; 31: auto_key_code = NO;
            default: auto_key_code = NO;
        endcase
    end

    // --- 3. 频率映射逻辑 ---
    always @(posedge clk) begin
        if (!sw0 || mode_change_reset) begin // 增加模式切换复位
            period_reg <= 18'd0;
            display_num <= 4'h0;
            octave_num <= 4'h0;
            is_break <= 1'b0;
        end else if (current_valid) begin
            if (current_key == 8'hF0) is_break <= 1'b1;
            else if (is_break && !sw1) begin 
                period_reg <= 18'd0;
                display_num <= 4'h0;
                octave_num <= 4'h0;
                is_break <= 1'b0;
            end else begin
                is_break <= 1'b0;
                case (current_key)
                    8'h16: begin period_reg <= 18'd191113; display_num <= 4'h1; octave_num <= 4'h1; end 
                    8'h1E: begin period_reg <= 18'd170262; display_num <= 4'h2; octave_num <= 4'h1; end 
                    8'h26: begin period_reg <= 18'd151685; display_num <= 4'h3; octave_num <= 4'h1; end 
                    8'h25: begin period_reg <= 18'd143172; display_num <= 4'h4; octave_num <= 4'h1; end 
                    8'h2E: begin period_reg <= 18'd127553; display_num <= 4'h5; octave_num <= 4'h1; end 
                    8'h36: begin period_reg <= 18'd113636; display_num <= 4'h6; octave_num <= 4'h1; end 
                    8'h3D: begin period_reg <= 18'd101239; display_num <= 4'h7; octave_num <= 4'h1; end 

                    8'h15: begin period_reg <= 18'd95556;  display_num <= 4'h1; octave_num <= 4'h2; end 
                    8'h1D: begin period_reg <= 18'd85131;  display_num <= 4'h2; octave_num <= 4'h2; end 
                    8'h24: begin period_reg <= 18'd75842;  display_num <= 4'h3; octave_num <= 4'h2; end 
                    8'h2D: begin period_reg <= 18'd71586;  display_num <= 4'h4; octave_num <= 4'h2; end 
                    8'h2C: begin period_reg <= 18'd63776;  display_num <= 4'h5; octave_num <= 4'h2; end 
                    8'h35: begin period_reg <= 18'd56818;  display_num <= 4'h6; octave_num <= 4'h2; end 
                    8'h3C: begin period_reg <= 18'd50619;  display_num <= 4'h7; octave_num <= 4'h2; end 

                    8'h1C: begin period_reg <= 18'd47778;  display_num <= 4'h1; octave_num <= 4'h3; end 
                    8'h1B: begin period_reg <= 18'd42566;  display_num <= 4'h2; octave_num <= 4'h3; end 
                    8'h23: begin period_reg <= 18'd37921;  display_num <= 4'h3; octave_num <= 4'h3; end 
                    8'h2B: begin period_reg <= 18'd35793;  display_num <= 4'h4; octave_num <= 4'h3; end 
                    8'h34: begin period_reg <= 18'd31888;  display_num <= 4'h5; octave_num <= 4'h3; end 
                    8'h33: begin period_reg <= 18'd28409;  display_num <= 4'h6; octave_num <= 4'h3; end 
                    8'h3B: begin period_reg <= 18'd25309;  display_num <= 4'h7; octave_num <= 4'h3; end 
                    
                    default: if(sw1) begin period_reg <= 0; display_num <= 0; octave_num <= 0; end
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (!sw0 || period_reg == 18'd0 || mode_change_reset) begin
            pwm_cnt <= 18'd0;
            pwm_out <= 1'b0;
        end else if (pwm_cnt >= period_reg) begin
            pwm_cnt <= 18'd0;
            pwm_out <= !pwm_out;
        end else pwm_cnt <= pwm_cnt + 18'd1;
    end

    function [7:0] decode(input [3:0] n);
        case(n)
            1: decode = 8'h06; 2: decode = 8'h5B; 3: decode = 8'h4F;
            4: decode = 8'h66; 5: decode = 8'h6D; 6: decode = 8'h7D;
            7: decode = 8'h07; default: decode = 8'h00;
        endcase
    endfunction

    assign seg0 = (sw0) ? decode(display_num) : 8'h00;
    assign seg1 = (sw0) ? decode(octave_num) : 8'h00;
    assign seg_en = (display_num != 4'h0 && sw0) ? 8'b00011000 : 8'b00000000;

endmodule