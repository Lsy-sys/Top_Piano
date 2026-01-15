module vga_render(
    input clk_100m,
    input [3:0] display_num,
    input [3:0] octave_num,
    input note_trigger_toggle, 
    input sw1,
    output reg [3:0] vga_r, vga_g, vga_b,
    output vga_hs, vga_vs
);
    // --- 1. 时钟与同步 (增加三级同步消除亚稳态) ---
    reg [1:0] clk_div;
    always @(posedge clk_100m) clk_div <= clk_div + 1;
    wire pix_clk = clk_div[1];

    parameter H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOTAL = 800;
    parameter V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOTAL = 525;
    
    reg [9:0] h_cnt = 0, v_cnt = 0;
    always @(posedge pix_clk) begin
        if (h_cnt == H_TOTAL - 1) begin
            h_cnt <= 0;
            if (v_cnt == V_TOTAL - 1) v_cnt <= 0; else v_cnt <= v_cnt + 1;
        end else h_cnt <= h_cnt + 1;
    end

    assign vga_hs = ~(h_cnt >= (H_ACTIVE + H_FP) && h_cnt < (H_ACTIVE + H_FP + H_SYNC));
    assign vga_vs = ~(v_cnt >= (V_ACTIVE + V_FP) && v_cnt < (V_ACTIVE + V_FP + V_SYNC));
    wire video_en = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    // --- 2. 坐标与位置参数 (严格限定范围) ---
    localparam KEY_W = 30;
    localparam START_X = 5;
    localparam PIANO_WIDTH = 630; // 21个键 * 30像素

    // 只有在有效钢琴宽度内才计算索引，否则强制为无效值(31)
    wire in_piano_x = (h_cnt >= START_X && h_cnt < (START_X + PIANO_WIDTH));
    wire [4:0] current_key_idx = in_piano_x ? (h_cnt - START_X) / KEY_W : 5'd31;
    
    // 当前按下键的索引
    wire [4:0] active_key_index = (octave_num >= 1 && display_num >= 1) ? 
                                  ((octave_num - 1) * 7 + (display_num - 1)) : 5'd31;
    
    wire [9:0] rel_x = in_piano_x ? (h_cnt - START_X) : 10'd0;
    wire [7:0] x_in_octave = rel_x % (KEY_W * 7);

    // --- 3. 跨时钟域触发同步 (消除竞争冒险) ---
    reg t_sync_0, t_sync_1, t_sync_2;
    always @(posedge vga_vs) begin
        t_sync_0 <= note_trigger_toggle;
        t_sync_1 <= t_sync_0;
        t_sync_2 <= t_sync_1;
    end
    
    // 手动模式下的变化检测也需要同步
    reg [3:0] d_num_sync;
    always @(posedge vga_vs) d_num_sync <= display_num;
    reg [3:0] d_num_last;
    always @(posedge vga_vs) d_num_last <= d_num_sync;

    // 触发判断：翻转电平改变 OR 手动模式下音符非零且改变
    wire press_trigger = (t_sync_1 ^ t_sync_2) || 
                         (!sw1 && d_num_sync != 0 && d_num_sync != d_num_last);

    // --- 4. 瀑布流逻辑 ---
    localparam MAX_EFF = 12;
    localparam EFF_HEIGHT = 60;
    reg [9:0] eff_y [0:MAX_EFF-1];
    reg [4:0] eff_x [0:MAX_EFF-1];
    reg [MAX_EFF-1:0] eff_active = 0;

    integer i;
    always @(posedge vga_vs) begin
        for (i = 0; i < MAX_EFF; i = i + 1) begin
            if (eff_active[i]) begin
                if (eff_y[i] <= 10'd45) // 略早于顶部边界消失，防止溢出
                    eff_active[i] <= 1'b0;
                else 
                    eff_y[i] <= eff_y[i] - 10'd4;
            end
        end
        
        if (press_trigger) begin
            // 采用优先级编码分配空闲通道
            casex (eff_active)
                12'bxxxx_xxxx_xxx0: begin eff_active[0] <= 1; eff_x[0] <= active_key_index; eff_y[0] <= 10'd300; end
                12'bxxxx_xxxx_xx01: begin eff_active[1] <= 1; eff_x[1] <= active_key_index; eff_y[1] <= 10'd300; end
                12'bxxxx_xxxx_x011: begin eff_active[2] <= 1; eff_x[2] <= active_key_index; eff_y[2] <= 10'd300; end
                12'bxxxx_xxxx_0111: begin eff_active[3] <= 1; eff_x[3] <= active_key_index; eff_y[3] <= 10'd300; end
                12'bxxxx_xxx0_1111: begin eff_active[4] <= 1; eff_x[4] <= active_key_index; eff_y[4] <= 10'd300; end
                12'bxxxx_xx01_1111: begin eff_active[5] <= 1; eff_x[5] <= active_key_index; eff_y[5] <= 10'd300; end
                12'bxxxx_x011_1111: begin eff_active[6] <= 1; eff_x[6] <= active_key_index; eff_y[6] <= 10'd300; end
                12'bxxxx_0111_1111: begin eff_active[7] <= 1; eff_x[7] <= active_key_index; eff_y[7] <= 10'd300; end
                12'bxxx0_1111_1111: begin eff_active[8] <= 1; eff_x[8] <= active_key_index; eff_y[8] <= 10'd300; end
                12'bxx01_1111_1111: begin eff_active[9] <= 1; eff_x[9] <= active_key_index; eff_y[9] <= 10'd300; end
                12'bx011_1111_1111: begin eff_active[10] <= 1; eff_x[10] <= active_key_index; eff_y[10] <= 10'd300; end
                12'b0111_1111_1111: begin eff_active[11] <= 1; eff_x[11] <= active_key_index; eff_y[11] <= 10'd300; end
                default: ; // 通道全满则忽略本次触发
            endcase
        end
    end

    // --- 5. 渲染逻辑 (Pipeline 优化) ---
    wire is_black_key = (v_cnt >= 300 && v_cnt < 410) && in_piano_x && (
        (x_in_octave >= 22  && x_in_octave <= 38)  || 
        (x_in_octave >= 52  && x_in_octave <= 68)  || 
        (x_in_octave >= 112 && x_in_octave <= 128) || 
        (x_in_octave >= 142 && x_in_octave <= 158) || 
        (x_in_octave >= 172 && x_in_octave <= 188)
    );

    // 特效判定：增加范围锁死，防止两侧溢出
    reg in_effect;
    integer j;
    always @(*) begin
        in_effect = 1'b0;
        if (in_piano_x && v_cnt >= 50 && v_cnt < 300) begin
            for (j = 0; j < MAX_EFF; j = j + 1) begin
                if (eff_active[j] && (current_key_idx == eff_x[j]) && 
                    (v_cnt >= eff_y[j]) && (v_cnt < eff_y[j] + EFF_HEIGHT))
                    in_effect = 1'b1;
            end
        end
    end

    // 最终色彩分配
    always @(*) begin
        if (!video_en) begin
            {vga_r, vga_g, vga_b} = 12'h000;
        end else begin
            // 默认背景色
            {vga_r, vga_g, vga_b} = 12'h112;

            // 1. 顶部状态栏
            if (v_cnt < 50) begin
                {vga_r, vga_g, vga_b} = sw1 ? 12'h0A5 : 12'h555;
            end 
            // 2. 特效区域 (带 X 范围锁)
            else if (v_cnt >= 50 && v_cnt < 300) begin
                if (in_effect)
                    {vga_r, vga_g, vga_b} = {4'hF, 4'hC, v_cnt[7:4]};
            end
            // 3. 钢琴区域
            else if (v_cnt >= 300 && v_cnt < 475) begin
                if (in_piano_x) begin
                    if (is_black_key) 
                        {vga_r, vga_g, vga_b} = 12'h000;
                    else if (rel_x % KEY_W == 0)
                        {vga_r, vga_g, vga_b} = 12'h444;
                    else if (display_num != 0 && current_key_idx == active_key_index) begin
                        case(octave_num)
                            4'd1: {vga_r, vga_g, vga_b} = 12'hF50; 
                            4'd2: {vga_r, vga_g, vga_b} = 12'h0DF; 
                            4'd3: {vga_r, vga_g, vga_b} = 12'hA5F;
                            default: {vga_r, vga_g, vga_b} = 12'h0DF;
                        endcase
                    end else 
                        {vga_r, vga_g, vga_b} = 12'hEEE;
                end
            end
        end
    end
endmodule