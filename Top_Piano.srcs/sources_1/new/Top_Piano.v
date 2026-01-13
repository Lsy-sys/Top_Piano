module Top_Piano(
    input clk,           // 100MHz 系统时钟
    input ps2_clk,       
    input ps2_data,      
    input sw0,           // 总开关
    input sw1,           // 自动模式开关 (N4)
    input btn_s4,        // 播放歌曲1 (U4)
    input btn_r11,       // 播放歌曲2 (R11)
    output audio_pwm,   
    output audio_sd,     
    output [7:0] seg0,   
    output [7:0] seg1,   
    output [7:0] seg_en  
);

    assign audio_sd = sw0;

    // --- 内部寄存器 ---
    reg [3:0]  ps2_cnt = 0;
    reg [10:0] ps2_buffer = 0;
    reg [7:0]  key_code = 0;
    reg        key_valid = 0;
    reg        ps2_clk_sync, ps2_clk_last;
    reg [19:0] timeout_cnt = 0;
    
    reg        play_en = 0;    
    reg [1:0]  song_select = 0;  // 1: 星星, 2: 新旋律
    reg [24:0] beat_cnt = 0;
    reg [5:0]  score_ptr = 0;
    reg [7:0]  auto_key_code = 0;

    reg [17:0] period_reg = 0;
    reg [17:0] pwm_cnt = 0;
    reg        pwm_out = 0;
    reg [3:0]  display_num = 4'h0;
    reg [3:0]  octave_num = 4'h0;
    reg        is_break = 0;
    reg [7:0]  playing_key = 0;

    // 模式切换检测
    reg sw1_reg;
    always @(posedge clk) sw1_reg <= sw1;
    wire mode_change_reset = (sw1 ^ sw1_reg);

    // --- 1. 播放触发与节拍控制 (合并所有 beat_cnt/score_ptr 驱动) ---
    always @(posedge clk) begin
        if (!sw0 || !sw1 || mode_change_reset) begin
            play_en <= 1'b0;
            song_select <= 2'd0;
            beat_cnt <= 0;
            score_ptr <= 0;
        end else begin
            // 按钮触发优先级逻辑
            if (btn_s4) begin
                play_en <= 1'b1;
                song_select <= 2'd1; 
                beat_cnt <= 0;
                score_ptr <= 0;
            end else if (btn_r11) begin
                play_en <= 1'b1;
                song_select <= 2'd2; 
                beat_cnt <= 0;
                score_ptr <= 0;
            end else if (play_en) begin
                // 正常播放时的计数逻辑
                if (beat_cnt >= 25_000_000) begin
                    beat_cnt <= 0;
                    score_ptr <= score_ptr + 1;
                end else begin
                    beat_cnt <= beat_cnt + 1;
                end

                // 自动停止逻辑
                if (song_select == 2'd1 && score_ptr == 6'd31 && beat_cnt >= 25_000_000) begin
                    play_en <= 1'b0;
                    song_select <= 2'd0;
                end else if (song_select == 2'd2 && score_ptr == 6'd39 && beat_cnt >= 25_000_000) begin
                    play_en <= 1'b0;
                    song_select <= 2'd0;
                end
            end else begin
                beat_cnt <= 0;
                score_ptr <= 0;
            end
        end
    end

    // --- 2. PS2 接收驱动 ---
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_last <= ps2_clk_sync;
    end
    wire ps2_fall = (ps2_clk_last && !ps2_clk_sync);

    always @(posedge clk) begin
        if (!sw0 || mode_change_reset) begin
            ps2_cnt <= 0;
            key_valid <= 0; timeout_cnt <= 0;
        end else if (ps2_fall) begin
            ps2_buffer[ps2_cnt] <= ps2_data;
            timeout_cnt <= 0;
            if (ps2_cnt == 4'd10) begin
                ps2_cnt <= 0;
                key_code <= ps2_buffer[8:1]; key_valid <= 1'b1;
            end else ps2_cnt <= ps2_cnt + 1;
        end else begin
            key_valid <= 1'b0;
            if (ps2_cnt != 0) begin
                if (timeout_cnt >= 20'd1_000_000) begin ps2_cnt <= 0;
                timeout_cnt <= 0; end
                else timeout_cnt <= timeout_cnt + 1;
            end
        end
    end

    // --- 3. 乐谱内容定义 ---
    parameter NO=8'h00;
    parameter L5=8'h2E, L6=8'h36, L7=8'h3D; 
    parameter K1=8'h15, K2=8'h1D, K3=8'h24, K4=8'h2D, K5=8'h2C, K6=8'h35, K7=8'h3C;
    parameter H1=8'h1C; 

    always @(*) begin
        auto_key_code = NO;
        if (song_select == 2'd1) begin
            case(score_ptr)
                0,1: auto_key_code = K1; 2,3: auto_key_code = K5;
                4,5: auto_key_code = K6; 6: auto_key_code = K5; 7: auto_key_code = NO;
                8,9: auto_key_code = K4; 10,11: auto_key_code = K3;
                12,13: auto_key_code = K2; 14: auto_key_code = K1; 15: auto_key_code = NO;
                16,17: auto_key_code = K5; 18,19: auto_key_code = K4;
                20,21: auto_key_code = K3; 22: auto_key_code = K2; 23: auto_key_code = NO;
                24,25: auto_key_code = K5; 26,27: auto_key_code = K4;
                28,29: auto_key_code = K3; 30: auto_key_code = K2; 31: auto_key_code = NO;
                default: auto_key_code = NO;
            endcase
        end else if (song_select == 2'd2) begin
            case(score_ptr)
                0: auto_key_code = L5; 1,2,3,4: auto_key_code = K3; 5: auto_key_code = K4; 6: auto_key_code = K5; 7: auto_key_code = K2; 8: auto_key_code = NO;
                9: auto_key_code = L5; 10,11,12,13: auto_key_code = K2; 14: auto_key_code = K3; 15: auto_key_code = K4; 16: auto_key_code = K3; 17: auto_key_code = NO;
                18: auto_key_code = K1; 19,20,21,22: auto_key_code = L6; 23: auto_key_code = L7; 24: auto_key_code = H1; 25: auto_key_code = K5; 26: auto_key_code = K4; 27: auto_key_code = K3; 28: auto_key_code = NO;
                29: auto_key_code = L6; 30,31,32,33: auto_key_code = K4; 34: auto_key_code = K5; 35: auto_key_code = L6; 36: auto_key_code = K5; 37: auto_key_code = K2; 38: auto_key_code = NO;
                default: auto_key_code = NO;
            endcase
        end
    end

    // --- 4. 频率与有效性逻辑 ---
    wire [7:0] current_key = (sw1) ? (play_en ? auto_key_code : 8'h00) : key_code;
    wire       current_valid = (mode_change_reset) ? 1'b0 :
                               ((sw1) ? (play_en && beat_cnt == 25'd1) : key_valid);

    always @(posedge clk) begin
        if (!sw0 || mode_change_reset) begin
            period_reg <= 0; display_num <= 0; octave_num <= 0; is_break <= 0; playing_key <= 0;
        end else if (sw1 && !play_en) begin
            period_reg <= 0; display_num <= 0; octave_num <= 0; playing_key <= 0;
        end else if (current_valid) begin
            if (current_key == 8'hF0) begin
                is_break <= 1'b1;
            end else if (current_key == 8'h00) begin
                period_reg <= 0; display_num <= 0; octave_num <= 0; playing_key <= 0; is_break <= 1'b0;
            end else if (is_break) begin
                if (current_key == playing_key || sw1) begin 
                    period_reg <= 0; display_num <= 0; octave_num <= 0; playing_key <= 0;
                end
                is_break <= 1'b0;
            end else begin
                is_break <= 1'b0;
                playing_key <= current_key;
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
                    default: begin period_reg <= 0; display_num <= 0; octave_num <= 0; end
                endcase
            end
        end
    end

    // --- 5. PWM 产生与音频使能 ---
    wire auto_mute = (sw1 && play_en && beat_cnt > 20_000_000);
    assign audio_pwm = pwm_out & sw0 & !auto_mute & !mode_change_reset;

    always @(posedge clk) begin
        if (!sw0 || period_reg == 0 || mode_change_reset) begin
            pwm_cnt <= 0; pwm_out <= 0;
        end else if (pwm_cnt >= period_reg) begin
            pwm_cnt <= 0; pwm_out <= !pwm_out;
        end else pwm_cnt <= pwm_cnt + 1;
    end

    // --- 6. 数码管译码 ---
    function [7:0] decode(input [3:0] n);
        case(n)
            1: decode = 8'h06; 2: decode = 8'h5B; 3: decode = 8'h4F;
            4: decode = 8'h66; 5: decode = 8'h6D; 6: decode = 8'h7D; 7: decode = 8'h07;
            default: decode = 8'h00;
        endcase
    endfunction

    assign seg0 = (sw0) ? decode(display_num) : 8'h00;
    assign seg1 = (sw0) ? decode(octave_num) : 8'h00;
    assign seg_en = (display_num != 4'h0 && sw0) ? 8'b00011000 : 8'b00000000;

endmodule