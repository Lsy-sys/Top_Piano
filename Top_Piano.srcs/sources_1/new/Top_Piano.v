module Top_Piano(
    input clk,            // 100MHz 系统时钟
    input ps2_clk,       
    input ps2_data,      
    input sw0,            // 总开关
    input sw1,            // 自动模式开关
    input sw2,            // 音色切换
    input btn_s4,         // 小星星触发
    input btn_r11,        // 传邮万里触发
    input btn_r17,        // 恭喜发财触发
    output audio_pwm,   
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output vga_hs,
    output vga_vs,
    output audio_sd,     
    output [7:0] seg0,   
    output [7:0] seg1,   
    output [7:0] seg_en  
);

    assign audio_sd = sw0;

    // --- 1. 内部寄存器与连线 ---
    reg [3:0]  ps2_cnt = 0;
    reg [10:0] ps2_buffer = 0;
    reg [7:0]  key_code = 0;
    reg        key_valid = 0;
    reg        ps2_clk_sync, ps2_clk_last;
    reg [19:0] timeout_cnt = 0;
    reg        play_en = 0;
    reg [1:0]  song_select = 0;
    reg [27:0] beat_cnt = 0; // 扩展位宽支持 1s
    reg [6:0]  score_ptr = 0;
    reg [7:0]  auto_key_code = 0;
    reg [27:0] current_note_duration = 0; // 动态时长寄存器
    reg [17:0] period_reg = 0;
    reg [3:0]  display_num = 4'h0;
    reg [3:0]  octave_num = 4'h0;
    reg        is_break = 0;
    reg [7:0]  playing_key = 0;

    // 预定义时钟周期常量 (100MHz)
    localparam LEN_1   = 100_000_000; // 1 拍
    localparam LEN_1_2 = 50_000_000;  // 1/2 拍
    localparam LEN_1_4 = 25_000_000;  // 1/4 拍
    localparam LEN_1_8 = 12_500_000;  // 1/8 拍

    reg sw1_reg;
    always @(posedge clk) sw1_reg <= sw1;
    wire mode_change_reset = (sw1 ^ sw1_reg);

    // --- 2. 自动播放与动态节拍控制 ---
    always @(posedge clk) begin
        if (!sw0 || !sw1 || mode_change_reset) begin
            play_en <= 1'b0; song_select <= 2'd0; beat_cnt <= 0; score_ptr <= 0;
        end else begin
            if (btn_s4) begin play_en <= 1'b1; song_select <= 2'd1; beat_cnt <= 0; score_ptr <= 0; end
            else if (btn_r11) begin play_en <= 1'b1; song_select <= 2'd2; beat_cnt <= 0; score_ptr <= 0; end
            else if (btn_r17) begin play_en <= 1'b1; song_select <= 2'd3; beat_cnt <= 0; score_ptr <= 0; end
            else if (play_en) begin
                if (beat_cnt >= current_note_duration) begin // 动态时长判断
                    beat_cnt <= 0;
                    score_ptr <= score_ptr + 1;
                end else beat_cnt <= beat_cnt + 1;
                
                // 停止逻辑
                if ((song_select == 2'd1 && score_ptr >= 32) || 
                    (song_select == 2'd2 && score_ptr >= 40) ||
                    (song_select == 2'd3 && score_ptr >= 48)) begin
                    play_en <= 1'b0; song_select <= 2'd0;
                end
            end else begin beat_cnt <= 0; score_ptr <= 0; end
        end
    end

    // --- 3. PS2 接收驱动 ---
    always @(posedge clk) begin ps2_clk_sync <= ps2_clk; ps2_clk_last <= ps2_clk_sync; end
    wire ps2_fall = (ps2_clk_last && !ps2_clk_sync);
    always @(posedge clk) begin
        if (!sw0 || mode_change_reset) begin ps2_cnt <= 0; key_valid <= 0; timeout_cnt <= 0; end
        else if (ps2_fall) begin
            ps2_buffer[ps2_cnt] <= ps2_data; timeout_cnt <= 0;
            if (ps2_cnt == 10) begin ps2_cnt <= 0; key_code <= ps2_buffer[8:1]; key_valid <= 1'b1; end
            else ps2_cnt <= ps2_cnt + 1;
        end else begin
            key_valid <= 1'b0;
            if (ps2_cnt != 0) begin
                if (timeout_cnt >= 20'd1_000_000) begin ps2_cnt <= 0; timeout_cnt <= 0; end
                else timeout_cnt <= timeout_cnt + 1;
            end
        end
    end

    // --- 4. 乐谱存储 (音符与时长定义) ---
    parameter NO=8'h00;
    parameter L5=8'h2E, L6=8'h36, L7=8'h3D;
    parameter K1=8'h15, K2=8'h1D, K3=8'h24, K4=8'h2D, K5=8'h2C, K6=8'h35, K7=8'h3C;
    parameter H1=8'h1C;

    always @(*) begin
        auto_key_code = NO; current_note_duration = LEN_1_4;
        if (song_select == 2'd1) begin // 小星星完整完善版
            case(score_ptr)
                0: begin auto_key_code = K1; current_note_duration = LEN_1_2; end
                1: begin auto_key_code = K1; current_note_duration = LEN_1_2; end
                2: begin auto_key_code = K5; current_note_duration = LEN_1_2; end
                3: begin auto_key_code = K5; current_note_duration = LEN_1_2; end
                4: begin auto_key_code = K6; current_note_duration = LEN_1_2; end
                5: begin auto_key_code = K6; current_note_duration = LEN_1_2; end
                6: begin auto_key_code = K5; current_note_duration = LEN_1;   end // 长音
                7: begin auto_key_code = K4; current_note_duration = LEN_1_2; end
                8: begin auto_key_code = K4; current_note_duration = LEN_1_2; end
                9: begin auto_key_code = K3; current_note_duration = LEN_1_2; end
                10:begin auto_key_code = K3; current_note_duration = LEN_1_2; end
                11:begin auto_key_code = K2; current_note_duration = LEN_1_2; end
                12:begin auto_key_code = K2; current_note_duration = LEN_1_2; end
                13:begin auto_key_code = K1; current_note_duration = LEN_1;   end
                14:begin auto_key_code = K5; current_note_duration = LEN_1_2; end
                15:begin auto_key_code = K5; current_note_duration = LEN_1_2; end
                16:begin auto_key_code = K4; current_note_duration = LEN_1_2; end
                17:begin auto_key_code = K4; current_note_duration = LEN_1_2; end
                18:begin auto_key_code = K3; current_note_duration = LEN_1_2; end
                19:begin auto_key_code = K3; current_note_duration = LEN_1_2; end
                20:begin auto_key_code = K2; current_note_duration = LEN_1;   end
                21:begin auto_key_code = K5; current_note_duration = LEN_1_2; end
                22:begin auto_key_code = K5; current_note_duration = LEN_1_2; end
                23:begin auto_key_code = K4; current_note_duration = LEN_1_2; end
                24:begin auto_key_code = K4; current_note_duration = LEN_1_2; end
                25:begin auto_key_code = K3; current_note_duration = LEN_1_2; end
                26:begin auto_key_code = K3; current_note_duration = LEN_1_2; end
                27:begin auto_key_code = K2; current_note_duration = LEN_1;   end
                default: auto_key_code = NO;
            endcase
        end else if (song_select == 2'd2) begin // 默认1/2拍
            current_note_duration = LEN_1_2;
            case(score_ptr)
                0: auto_key_code = L5; 1,2,3,4: auto_key_code = K3; 5: auto_key_code = K4; 
                6: auto_key_code = K5; 7: auto_key_code = K2; 8: auto_key_code = NO;
                default: auto_key_code = NO;
            endcase
        end else if (song_select == 2'd3) begin // 默认1/2拍
            current_note_duration = LEN_1_2;
            case(score_ptr)
                0,1: auto_key_code = K1; 2,3: auto_key_code = K2; 4,5: auto_key_code = K3;
                default: auto_key_code = NO;
            endcase
        end
    end

    // --- 5. 频率控制查找表 (补全所有音程) ---
    wire [7:0] current_key = (sw1) ? (play_en ? auto_key_code : 8'h00) : key_code;
    wire       current_valid = (mode_change_reset) ? 1'b0 : ((sw1) ? (play_en && beat_cnt == 28'd1) : key_valid);

    always @(posedge clk) begin
        if (!sw0 || mode_change_reset || (sw1 && !play_en)) begin
            period_reg <= 0; display_num <= 0; octave_num <= 0; playing_key <= 0; is_break <= 0;
        end else if (current_valid) begin
            if (current_key == 8'hF0) is_break <= 1'b1;
            else if (current_key == 8'h00) begin 
                period_reg <= 0; display_num <= 0; octave_num <= 0; playing_key <= 0; is_break <= 0;
            end else if (is_break) begin
                if (current_key == playing_key || sw1) begin period_reg <= 0; display_num <= 0; octave_num <= 0; playing_key <= 0; end
                is_break <= 1'b0;
            end else begin
                is_break <= 1'b0; playing_key <= current_key;
                case (current_key)
                    // L1-L7
                    8'h16: begin period_reg <= 191113; display_num <= 1; octave_num <= 1; end
                    8'h1E: begin period_reg <= 170262; display_num <= 2; octave_num <= 1; end
                    8'h26: begin period_reg <= 151685; display_num <= 3; octave_num <= 1; end
                    8'h25: begin period_reg <= 143172; display_num <= 4; octave_num <= 1; end
                    8'h2E: begin period_reg <= 127553; display_num <= 5; octave_num <= 1; end
                    8'h36: begin period_reg <= 113636; display_num <= 6; octave_num <= 1; end
                    8'h3D: begin period_reg <= 101239; display_num <= 7; octave_num <= 1; end
                    // M1-M7
                    8'h15: begin period_reg <= 95556;  display_num <= 1; octave_num <= 2; end
                    8'h1D: begin period_reg <= 85131;  display_num <= 2; octave_num <= 2; end
                    8'h24: begin period_reg <= 75842;  display_num <= 3; octave_num <= 2; end
                    8'h2D: begin period_reg <= 71586;  display_num <= 4; octave_num <= 2; end
                    8'h2C: begin period_reg <= 63776;  display_num <= 5; octave_num <= 2; end
                    8'h35: begin period_reg <= 56818;  display_num <= 6; octave_num <= 2; end
                    8'h3C: begin period_reg <= 50619;  display_num <= 7; octave_num <= 2; end
                    // H1-H7 
                    8'h1C: begin period_reg <= 47778;  display_num <= 1; octave_num <= 3; end
                    8'h1B: begin period_reg <= 42566;  display_num <= 2; octave_num <= 3; end
                    8'h23: begin period_reg <= 37921;  display_num <= 3; octave_num <= 3; end
                    8'h2B: begin period_reg <= 35793;  display_num <= 4; octave_num <= 3; end
                    8'h34: begin period_reg <= 31888;  display_num <= 5; octave_num <= 3; end
                    8'h33: begin period_reg <= 28409;  display_num <= 6; octave_num <= 3; end
                    8'h3B: begin period_reg <= 25309;  display_num <= 7; octave_num <= 3; end
                    default: begin period_reg <= 0; display_num <= 0; octave_num <= 0; end
                endcase
            end
        end
    end

    // --- 6. 波形生成 ---
    reg [7:0] sine_rom [0:255];
    initial $readmemh("sine_table.txt", sine_rom);
    reg [17:0] sq_cnt = 0; reg sq_wave = 0;
    always @(posedge clk) begin
        if (period_reg == 0) begin sq_cnt <= 0; sq_wave <= 0; end
        else if (sq_cnt >= period_reg) begin sq_cnt <= 0; sq_wave <= !sq_wave; end
        else sq_cnt <= sq_cnt + 1;
    end
    reg [7:0] sine_ptr = 0; reg [17:0] sine_acc = 0;
    always @(posedge clk) begin
        if (period_reg == 0) begin sine_acc <= 0; sine_ptr <= 0; end
        else if (sine_acc >= (period_reg >> 7)) begin sine_acc <= 0; sine_ptr <= sine_ptr + 1; end
        else sine_acc <= sine_acc + 1;
    end
    reg [9:0] pwm_carrier = 0; reg sine_pwm_out;
    always @(posedge clk) begin pwm_carrier <= pwm_carrier + 1;
    sine_pwm_out <= (pwm_carrier < {sine_rom[sine_ptr], 2'b00}); end

    wire final_wave = sw2 ? sine_pwm_out : sq_wave;
    wire auto_mute = (sw1 && play_en && beat_cnt > (current_note_duration - 5_000_000));
    assign audio_pwm = final_wave & sw0 & !auto_mute & !mode_change_reset;

    // --- 7. 显示逻辑 ---
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

    vga_render u_vga_inst (
        .clk_100m(clk), .display_num(display_num), .octave_num(octave_num), .sw1(sw1),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_hs(vga_hs), .vga_vs(vga_vs)
    );
endmodule