module Top_Piano(
    input clk,           // 系统时钟 P17
    input ps2_clk,       // PS2时钟 K5
    input ps2_data,      // PS2数据 L4
    input sw0,           // 总开关/全局复位 SW0 (R1)
    output audio_pwm,    // PWM输出 T1
    output audio_sd,     // 音频使能 M6
    output [7:0] seg0,   // 数码管段选0
    output [7:0] seg1,   // 数码管段选1
    output [7:0] seg_en  // 数码管位选
);

    // --- 静态输出控制 ---
    assign audio_sd = sw0; 
    assign seg1 = 8'h00;   
    
    // --- 寄存器定义 ---
    reg [3:0]  ps2_cnt = 0;
    reg [10:0] ps2_buffer = 0;
    reg [7:0]  key_code = 0;
    reg        key_valid = 0;
    reg        ps2_clk_sync, ps2_clk_last;
    
    reg [17:0] period_reg = 0; 
    reg [17:0] pwm_cnt = 0;    
    reg        pwm_out = 0;
    reg        is_break = 0;
    reg [3:0]  display_num = 4'h0; 

    // 只有开关开启且有PWM输出时才驱动
    assign audio_pwm = pwm_out & sw0;

    // --- PS2 边沿检测 ---
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_last <= ps2_clk_sync;
    end
    wire ps2_fall = (ps2_clk_last && !ps2_clk_sync);

    // --- PS2 接收逻辑 (加入 sw0 强置初始态) ---
    always @(posedge clk) begin
        if (!sw0) begin
            ps2_cnt <= 4'd0;
            ps2_buffer <= 11'd0;
            key_valid <= 1'b0;
        end else if (ps2_fall) begin
            ps2_buffer[ps2_cnt] <= ps2_data;
            if (ps2_cnt == 4'd10) begin
                ps2_cnt <= 4'd0;
                key_code <= ps2_buffer[8:1];
                key_valid <= 1'b1;
            end else begin
                ps2_cnt <= ps2_cnt + 4'd1;
            end
        end else begin
            key_valid <= 1'b0;
        end
    end

    // --- 音阶映射与状态控制 ---
    always @(posedge clk) begin
        if (!sw0) begin
            // 开关关闭时，立即清空所有播放状态
            period_reg <= 18'd0;
            display_num <= 4'h0;
            is_break <= 1'b0;
        end else if (key_valid) begin 
            if (key_code == 8'hF0) begin
                is_break <= 1'b1;
            end else if (is_break) begin
                period_reg <= 18'd0;
                display_num <= 4'h0;
                is_break <= 1'b0;
            end else begin
                case (key_code)
                    // --- 低八度: 数字键 1-7 ---
                    8'h16: begin period_reg <= 18'd191113; display_num <= 4'h1; end 
                    8'h1E: begin period_reg <= 18'd170262; display_num <= 4'h2; end 
                    8'h26: begin period_reg <= 18'd151685; display_num <= 4'h3; end 
                    8'h25: begin period_reg <= 18'd143173; display_num <= 4'h4; end 
                    8'h2E: begin period_reg <= 18'd127553; display_num <= 4'h5; end 
                    8'h36: begin period_reg <= 18'd113636; display_num <= 4'h6; end 
                    8'h3D: begin period_reg <= 18'd101238; display_num <= 4'h7; end 

                    // --- 中八度: QWERTYU ---
                    8'h15: begin period_reg <= 18'd95556;  display_num <= 4'h1; end 
                    8'h1D: begin period_reg <= 18'd85131;  display_num <= 4'h2; end 
                    8'h24: begin period_reg <= 18'd75842;  display_num <= 4'h3; end 
                    8'h2D: begin period_reg <= 18'd71586;  display_num <= 4'h4; end 
                    8'h2C: begin period_reg <= 18'd63776;  display_num <= 4'h5; end 
                    8'h35: begin period_reg <= 18'd56818;  display_num <= 4'h6; end 
                    8'h3C: begin period_reg <= 18'd50619;  display_num <= 4'h7; end 

                    // --- 高八度: ASDFGHJ ---
                    8'h1C: begin period_reg <= 18'd47778;  display_num <= 4'h1; end 
                    8'h1B: begin period_reg <= 18'd42566;  display_num <= 4'h2; end 
                    8'h23: begin period_reg <= 18'd37921;  display_num <= 4'h3; end 
                    8'h2B: begin period_reg <= 18'd35793;  display_num <= 4'h4; end 
                    8'h34: begin period_reg <= 18'd31888;  display_num <= 4'h5; end 
                    8'h33: begin period_reg <= 18'd28409;  display_num <= 4'h6; end 
                    8'h3B: begin period_reg <= 18'd25309;  display_num <= 4'h7; end 
                    default: ;
                endcase
            end
        end
    end

    // --- PWM 发生器 (50%占空比) ---
    always @(posedge clk) begin
        if (!sw0 || period_reg == 18'd0) begin
            pwm_cnt <= 18'd0;
            pwm_out <= 1'b0;
        end else if (pwm_cnt >= period_reg) begin
            pwm_cnt <= 18'd0;
            pwm_out <= !pwm_out;
        end else begin
            pwm_cnt <= pwm_cnt + 18'd1;
        end
    end

    // --- 数码管显示逻辑 ---
    reg [7:0] seg_data;
    always @(*) begin
        if (sw0) begin
            case (display_num)
                4'h1: seg_data = 8'h06; 4'h2: seg_data = 8'h5B; 4'h3: seg_data = 8'h4F;
                4'h4: seg_data = 8'h66; 4'h5: seg_data = 8'h6D; 4'h6: seg_data = 8'h7D;
                4'h7: seg_data = 8'h07; default: seg_data = 8'h00;
            endcase
        end else begin
            seg_data = 8'h00;
        end
    end
    
    assign seg0 = seg_data;
    // 位选信号：只有开启开关且有音符时点亮第一位
    assign seg_en = (display_num != 4'h0 && sw0) ? 8'h01 : 8'h00; 

endmodule