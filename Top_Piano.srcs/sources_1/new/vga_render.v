module vga_render(
    input clk_100m,          // 系统 100MHz 时钟
    input [3:0] display_num, // 来自 Top_Piano 的当前音符 (1-7)
    input [3:0] octave_num,  // 来自 Top_Piano 的当前音程 (1-3)
    input sw1,               // 自动模式状态
    output reg [3:0] vga_r, vga_g, vga_b,
    output vga_hs, vga_vs
);

    // --- A. 时钟与同步信号 ---
    reg [1:0] clk_div;
    always @(posedge clk_100m) clk_div <= clk_div + 1;
    wire pix_clk = clk_div[1];

    parameter H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOTAL = 800;
    parameter V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOTAL = 525;

    reg [9:0] h_cnt = 0, v_cnt = 0;
    always @(posedge pix_clk) begin
        if (h_cnt == H_TOTAL - 1) begin
            h_cnt <= 0;
            if (v_cnt == V_TOTAL - 1) v_cnt <= 0;
            else v_cnt <= v_cnt + 1;
        end else h_cnt <= h_cnt + 1;
    end

    assign vga_hs = ~(h_cnt >= (H_ACTIVE + H_FP) && h_cnt < (H_ACTIVE + H_FP + H_SYNC));
    assign vga_vs = ~(v_cnt >= (V_ACTIVE + V_FP) && v_cnt < (V_ACTIVE + V_FP + V_SYNC));
    wire video_en = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    // --- B. 位置参数 ---
    localparam KEY_W = 30;
    localparam START_X = 5;
    wire [4:0] current_key_idx = (h_cnt >= START_X) ? (h_cnt - START_X) / KEY_W : 5'd31;
    wire [4:0] active_key_index = (octave_num >= 1 && display_num >= 1) ? ((octave_num - 1) * 7 + (display_num - 1)) : 5'd31;
    wire [9:0] rel_x = (h_cnt >= START_X) ? (h_cnt - START_X) : 10'd0;
    wire [7:0] x_in_octave = rel_x % (KEY_W * 7);

    // --- C. 特效逻辑 (保持之前的稳定分配版) ---
    localparam MAX_EFF = 12;        
    localparam EFF_HEIGHT = 60;     
    reg [9:0] eff_y [0:MAX_EFF-1];  
    reg [4:0] eff_x [0:MAX_EFF-1];  
    reg [MAX_EFF-1:0] eff_active = 0; 
    
    reg [3:0] note_q1, note_q2;
    always @(posedge vga_vs) begin
        note_q1 <= display_num;
        note_q2 <= note_q1;
    end
    wire press_trigger = (note_q1 != 4'd0 && note_q1 != note_q2);

    integer i;
    always @(posedge vga_vs) begin
        for (i = 0; i < MAX_EFF; i = i + 1) begin
            if (eff_active[i]) begin
                if (eff_y[i] <= 10'd51) eff_active[i] <= 1'b0;
                else eff_y[i] <= eff_y[i] - 10'd4;
            end
        end
        if (press_trigger) begin
            case(1'b0)
                eff_active[0]:  begin eff_active[0] <= 1; eff_x[0] <= active_key_index; eff_y[0] <= 10'd300; end
                eff_active[1]:  begin eff_active[1] <= 1; eff_x[1] <= active_key_index; eff_y[1] <= 10'd300; end
                eff_active[2]:  begin eff_active[2] <= 1; eff_x[2] <= active_key_index; eff_y[2] <= 10'd300; end
                eff_active[3]:  begin eff_active[3] <= 1; eff_x[3] <= active_key_index; eff_y[3] <= 10'd300; end
                eff_active[4]:  begin eff_active[4] <= 1; eff_x[4] <= active_key_index; eff_y[4] <= 10'd300; end
                eff_active[5]:  begin eff_active[5] <= 1; eff_x[5] <= active_key_index; eff_y[5] <= 10'd300; end
                eff_active[6]:  begin eff_active[6] <= 1; eff_x[6] <= active_key_index; eff_y[6] <= 10'd300; end
                eff_active[7]:  begin eff_active[7] <= 1; eff_x[7] <= active_key_index; eff_y[7] <= 10'd300; end
                eff_active[8]:  begin eff_active[8] <= 1; eff_x[8] <= active_key_index; eff_y[8] <= 10'd300; end
                eff_active[9]:  begin eff_active[9] <= 1; eff_x[9] <= active_key_index; eff_y[9] <= 10'd300; end
                eff_active[10]: begin eff_active[10] <= 1; eff_x[10] <= active_key_index; eff_y[10] <= 10'd300; end
                eff_active[11]: begin eff_active[11] <= 1; eff_x[11] <= active_key_index; eff_y[11] <= 10'd300; end
                default: ; 
            endcase
        end
    end

    // --- D. 渲染逻辑 (修复黑杠问题) ---
    reg [11:0] pix_data;
    wire is_black_key = (v_cnt >= 300 && v_cnt < 410) && (
        (x_in_octave >= 22  && x_in_octave <= 38)  || 
        (x_in_octave >= 52  && x_in_octave <= 68)  || 
        (x_in_octave >= 112 && x_in_octave <= 128) || 
        (x_in_octave >= 142 && x_in_octave <= 158) || 
        (x_in_octave >= 172 && x_in_octave <= 188)
    );

    always @(*) begin
        pix_data = 12'h112; // 默认深色背景

        if (!video_en) begin
            pix_data = 12'h000;
        end else begin
            // 1. 顶部状态栏
            if (v_cnt < 50) begin
                pix_data = sw1 ? 12'h0A5 : 12'h555;
            end 
            // 2. 钢琴区域渲染 (包括白键、高亮和黑键)
            else if (v_cnt >= 300 && v_cnt < 475) begin
                if (h_cnt >= START_X && h_cnt < (START_X + 630)) begin
                    if (is_black_key) begin
                        pix_data = 12'h000; // 黑键最高优先级，遮盖一切
                    end else begin
                        // 白键及高亮判断
                        if (rel_x % KEY_W == 0) begin
                            pix_data = 12'h444; // 琴键边框
                        end else if (display_num != 0 && current_key_idx == active_key_index) begin
                            case(octave_num)
                                4'd1: pix_data = 12'hF50;
                                4'd2: pix_data = 12'h0DF;
                                4'd3: pix_data = 12'hA5F;
                                default: pix_data = 12'h0DF;
                            endcase
                        end else begin
                            pix_data = 12'hEEE; // 普通白键
                        end
                    end
                end
            end
            // 3. 瀑布流特效区域 (放在最后判断，但优先级低于黑键)
            else if (v_cnt >= 50 && v_cnt < 300) begin
                for (i = 0; i < MAX_EFF; i = i + 1) begin
                    if (eff_active[i] && current_key_idx == eff_x[i] && 
                        v_cnt >= eff_y[i] && v_cnt < (eff_y[i] + EFF_HEIGHT)) begin
                        pix_data = {4'hF, 4'hC, v_cnt[7:4]}; 
                    end
                end
            end
        end
        // 最终输出
        vga_r = pix_data[11:8];
        vga_g = pix_data[7:4];
        vga_b = pix_data[3:0];
    end
endmodule