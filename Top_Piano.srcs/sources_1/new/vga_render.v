module vga_render(
    input clk_100m,
    input [3:0] display_num,
    input [3:0] octave_num,
    input note_trigger_toggle, 
    input sw1,
    output reg [3:0] vga_r, vga_g, vga_b,
    output vga_hs, vga_vs
);
    // --- 1. 时钟与同步 ---
    reg [1:0] clk_div;
    always @(posedge clk_100m) clk_div <= clk_div + 1;
    wire pix_clk = clk_div[1];

    parameter H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOTAL = 800;
    parameter V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOTAL = 525;
    reg [9:0] h_cnt = 0, v_cnt = 0;
    always @(posedge pix_clk) begin
        if (h_cnt == H_TOTAL - 1) begin h_cnt <= 0;
            if (v_cnt == V_TOTAL - 1) v_cnt <= 0; else v_cnt <= v_cnt + 1;
        end else h_cnt <= h_cnt + 1;
    end

    assign vga_hs = ~(h_cnt >= (H_ACTIVE + H_FP) && h_cnt < (H_ACTIVE + H_FP + H_SYNC));
    assign vga_vs = ~(v_cnt >= (V_ACTIVE + V_FP) && v_cnt < (V_ACTIVE + V_FP + V_SYNC));
    wire video_en = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    // --- 2. 坐标与位置参数 ---
    localparam KEY_W = 30;
    localparam START_X = 5;
    // 计算当前扫描点对应的琴键索引
    wire [4:0] current_key_idx = (h_cnt >= START_X && h_cnt < START_X + 630) ? (h_cnt - START_X) / KEY_W : 5'd31;
    // 计算当前发声琴键的索引
    wire [4:0] active_key_index = (octave_num >= 1 && display_num >= 1) ? ((octave_num - 1) * 7 + (display_num - 1)) : 5'd31;
    
    wire [9:0] rel_x = (h_cnt >= START_X) ? (h_cnt - START_X) : 10'd0;
    wire [7:0] x_in_octave = rel_x % (KEY_W * 7);

    // --- 3. 瀑布流逻辑 (保持你的 12路并发) ---
    localparam MAX_EFF = 12;
    localparam EFF_HEIGHT = 60;
    reg [9:0] eff_y [0:MAX_EFF-1];
    reg [4:0] eff_x [0:MAX_EFF-1];
    reg [MAX_EFF-1:0] eff_active = 0;
    
    reg trig_sync_1, trig_sync_2;
    always @(posedge vga_vs) begin
        trig_sync_1 <= note_trigger_toggle;
        trig_sync_2 <= trig_sync_1;
    end

    reg [3:0] display_last;
    always @(posedge vga_vs) display_last <= display_num;
    wire press_trigger = (trig_sync_1 ^ trig_sync_2) || (!sw1 && display_num != 0 && display_num != display_last);

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
            endcase
        end
    end

    // --- 4. 渲染逻辑 (优化防破碎) ---
    
    // 黑键区域判定
    wire is_black_key = (v_cnt >= 300 && v_cnt < 410) && (
        (x_in_octave >= 22  && x_in_octave <= 38)  || 
        (x_in_octave >= 52  && x_in_octave <= 68)  || 
        (x_in_octave >= 112 && x_in_octave <= 128) || 
        (x_in_octave >= 142 && x_in_octave <= 158) || 
        (x_in_octave >= 172 && x_in_octave <= 188)
    );

    // 预计算特效判定 (减少大 always 块负担)
    reg in_effect;
    always @(*) begin
        in_effect = 1'b0;
        for (i = 0; i < MAX_EFF; i = i + 1) begin
            if (eff_active[i] && current_key_idx == eff_x[i] && v_cnt >= eff_y[i] && v_cnt < (eff_y[i] + EFF_HEIGHT))
                in_effect = 1'b1;
        end
    end

    always @(*) begin
        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0; // 默认黑色
        
        if (video_en) begin
            // 1. 顶部状态栏
            if (v_cnt < 50) begin
                {vga_r, vga_g, vga_b} = sw1 ? 12'h0A5 : 12'h555;
            end 
            // 2. 钢琴区域 (300 - 475)
            else if (v_cnt >= 300 && v_cnt < 475) begin
                if (h_cnt >= START_X && h_cnt < START_X + 630) begin
                    if (is_black_key) begin
                        {vga_r, vga_g, vga_b} = 12'h000; // 黑键
                    end else if (rel_x % KEY_W == 0) begin
                        {vga_r, vga_g, vga_b} = 12'h444; // 琴键边框
                    end else if (display_num != 0 && current_key_idx == active_key_index) begin
                        // 高亮当前按下的键
                        case(octave_num)
                            4'd1: {vga_r, vga_g, vga_b} = 12'hF50; 
                            4'd2: {vga_r, vga_g, vga_b} = 12'h0DF; 
                            4'd3: {vga_r, vga_g, vga_b} = 12'hA5F;
                            default: {vga_r, vga_g, vga_b} = 12'h0DF;
                        endcase
                    end else begin
                        {vga_r, vga_g, vga_b} = 12'hEEE; // 普通白键
                    end
                end else begin
                    {vga_r, vga_g, vga_b} = 12'h112; // 钢琴区域外的背景
                end
            end
            // 3. 特效区域 (50 - 300)
            else if (v_cnt >= 50 && v_cnt < 300) begin
                if (in_effect) begin
                    vga_r = 4'hF; vga_g = 4'hC; vga_b = v_cnt[7:4]; // 特效颜色
                end else begin
                    {vga_r, vga_g, vga_b} = 12'h112; // 默认背景
                end
            end
            // 4. 其余背景
            else begin
                {vga_r, vga_g, vga_b} = 12'h112;
            end
        end
    end

endmodule