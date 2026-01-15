module vga_render(
    input clk_100m,         // 系统 100MHz 时钟
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

    // --- B. 键盘参数计算 (在 always 块外声明 wire) ---
    localparam KEY_W = 30;    // 每个白键宽度
    localparam START_X = 5;   // 整体左偏移
    
    // 计算当前像素属于 21 个键中的第几个 (0-20)
    wire [4:0] current_key_idx = (h_cnt >= START_X) ? (h_cnt - START_X) / KEY_W : 5'd31;
    // 将输入的音符转为 0-20 的索引位置
    wire [4:0] active_key_index = (octave_num >= 1 && display_num >= 1) ? ((octave_num - 1) * 7 + (display_num - 1)) : 5'd31;
    
    // 用于黑键判断的坐标
    wire [9:0] rel_x = (h_cnt >= START_X) ? (h_cnt - START_X) : 10'd0;
    wire [7:0] x_in_octave = rel_x % (KEY_W * 7); // 每个八度周期 210 像素

    // --- C. UI 渲染逻辑 ---
    parameter BG_COLOR    = 12'h112; 
    parameter KEY_WHITE   = 12'hEEE; 
    parameter KEY_ACTIVE  = 12'h0DF; 
    parameter BORDER      = 12'h444; 

    always @(*) begin
        if (!video_en) begin
            {vga_r, vga_g, vga_b} = 12'h000;
        end else begin
            // 默认背景色
            {vga_r, vga_g, vga_b} = BG_COLOR; 

            // 1. 顶部状态栏 (0-50像素)
            if (v_cnt < 50) begin
                if (sw1) {vga_r, vga_g, vga_b} = 12'h0A5; 
                else {vga_r, vga_g, vga_b} = 12'h555;     
            end
            
            // 2. 钢琴键盘区 (300-470像素)
            else if (v_cnt >= 300 && v_cnt < 470) begin
                if (h_cnt >= START_X && h_cnt < (START_X + 630)) begin
                    
                    // --- 优先判断黑键 (叠加在白键上层) ---
                    // 黑键高度较短 (300-410)，逻辑不再依赖 current_key_idx 以防断裂
                    if (v_cnt < 410 && (
                        (x_in_octave >= 22  && x_in_octave <= 38)  || // 1-2 键缝隙
                        (x_in_octave >= 52  && x_in_octave <= 68)  || // 2-3 键缝隙
                        (x_in_octave >= 112 && x_in_octave <= 128) || // 4-5 键缝隙
                        (x_in_octave >= 142 && x_in_octave <= 158) || // 5-6 键缝隙
                        (x_in_octave >= 172 && x_in_octave <= 188)    // 6-7 键缝隙
                    )) begin
                        {vga_r, vga_g, vga_b} = 12'h000; 
                    end
                    
                    // --- 绘制白键 (底层) ---
                    else begin
                        if (rel_x % KEY_W == 0) begin
                            {vga_r, vga_g, vga_b} = BORDER; 
                        end else if (display_num != 0 && current_key_idx == active_key_index) begin
                            // 根据音程显示不同高亮颜色
                            case(octave_num)
                                4'd1: {vga_r, vga_g, vga_b} = 12'hF50; // 低音橙色
                                4'd2: {vga_r, vga_g, vga_b} = 12'h0DF; // 中音青色
                                4'd3: {vga_r, vga_g, vga_b} = 12'hA5F; // 高音紫色
                                default: {vga_r, vga_g, vga_b} = KEY_ACTIVE;
                            endcase
                        end else begin
                            {vga_r, vga_g, vga_b} = KEY_WHITE;
                        end
                    end
                end
            end
        end
    end
endmodule