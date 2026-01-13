module Top_Piano(
    input clk,           // 系统时钟 P17
    input ps2_clk,       // PS2时钟 K5
    input ps2_data,      // PS2数据 L4
    output audio_pwm,    // PWM输出 T1
    output audio_sd,     // 音频使能 M6
    // 数码管管脚
    output [7:0] seg0,   // {DP0, G0, F0, E0, D0, C0, B0, A0}
    output [7:0] seg1,   // {DP1, G1, F1, E1, D1, C1, B1, A1}
    output [7:0] seg_en  // {DN1_K4~K1, DN0_K4~K1}
);

    assign audio_sd = 1'b1; // 启用音频
    assign seg1 = 8'h00;    // 第二组数码管默认不亮
    
    // --- 逻辑信号 ---
    reg [3:0]  ps2_cnt = 0;
    reg [10:0] ps2_buffer = 0;
    reg [7:0]  key_code = 0;
    reg        key_valid = 0;
    reg        ps2_clk_sync, ps2_clk_last;
    
    reg [17:0] period_reg = 0; 
    reg [17:0] pwm_cnt = 0;    
    reg        pwm_out = 0;
    reg        is_break = 0;
    reg [3:0]  display_num = 4'h0; // 存储当前按下的数字

    assign audio_pwm = pwm_out;

    // --- PS2 接收 ---
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_last <= ps2_clk_sync;
    end
    wire ps2_fall = (ps2_clk_last && !ps2_clk_sync);

    always @(posedge clk) begin
        if (ps2_fall) begin
            ps2_buffer[ps2_cnt] <= ps2_data;
            if (ps2_cnt == 4'd10) begin
                ps2_cnt <= 4'd0;
                key_code <= ps2_buffer[8:1];
                key_valid <= 1'b1;
            end else begin
                ps2_cnt <= ps2_cnt + 4'd1;
                key_valid <= 1'b0;
            end
        end else key_valid <= 1'b0;
    end

    // --- 音阶映射与数字映射 ---
    always @(posedge clk) begin
        if (key_valid) begin
            if (key_code == 8'hF0) is_break <= 1'b1;
            else if (is_break) begin
                period_reg <= 18'd0;
                display_num <= 4'h0;
                is_break <= 1'b0;
            end else begin
                case (key_code)
                    8'h16: begin period_reg <= 18'd191113; display_num <= 4'h1; end // 1
                    8'h1E: begin period_reg <= 18'd170262; display_num <= 4'h2; end // 2
                    8'h26: begin period_reg <= 18'd151685; display_num <= 4'h3; end // 3
                    8'h25: begin period_reg <= 18'd143173; display_num <= 4'h4; end // 4
                    8'h2E: begin period_reg <= 18'd127553; display_num <= 4'h5; end // 5
                    8'h36: begin period_reg <= 18'd113636; display_num <= 4'h6; end // 6
                    8'h3D: begin period_reg <= 18'd101238; display_num <= 4'h7; end // 7
                    default: ;
                endcase
            end
        end
    end

    // --- PWM 发生 ---
    always @(posedge clk) begin
        if (period_reg == 18'd0) begin pwm_cnt <= 18'd0; pwm_out <= 1'b0; end
        else if (pwm_cnt >= period_reg) begin pwm_cnt <= 18'd0; pwm_out <= !pwm_out; end
        else pwm_cnt <= pwm_cnt + 18'd1;
    end

    // --- 数码管显示驱动 (8421译码) ---
    reg [7:0] seg_data;
    always @(*) begin
        case (display_num) // 共阴极：高电平点亮段
            4'h0: seg_data = 8'h3F; // 0 (不按键时不显示或显示0)
            4'h1: seg_data = 8'h06; // 1
            4'h2: seg_data = 8'h5B; // 2
            4'h3: seg_data = 8'h4F; // 3
            4'h4: seg_data = 8'h66; // 4
            4'h5: seg_data = 8'h6D; // 5
            4'h6: seg_data = 8'h7D; // 6
            4'h7: seg_data = 8'h07; // 7
            default: seg_data = 8'h00;
        endcase
    end
    assign seg0 = seg_data;
    // 位选：高电平使能对应位（DN0_K1为最低位）
    assign seg_en = (display_num == 0) ? 8'h00 : 8'h01; 

endmodule