// hexa-cern/firmware/hdl/testbench/timing_ctrl_top_tb.v
//
// §A.6.1 step E1.2 — system-level testbench. Wishbone-programs the
// register file, then watches the datapath generate ticks + triggers
// + IRQs end-to-end. Compressed sim time (TICK_HZ=1MHz) so iverilog
// runs in seconds.

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl_top_tb;

    localparam integer CLK_HZ_TB = 100_000_000;
    localparam integer TICK_HZ_TB = 1_000_000;     // 1 µs/tick for sim speed

    reg         clk;
    reg         rstn;

    reg         hv_ok;
    reg         vacuum_ok;
    reg         water_ok;
    reg         shutter_ok;

    reg         wb_cyc;
    reg         wb_stb;
    reg         wb_we;
    reg [31:0]  wb_adr;
    reg [31:0]  wb_dat_i;
    reg [3:0]   wb_sel;
    wire        wb_ack;
    wire        wb_err;
    wire [31:0] wb_dat_o;

    wire        tick;
    wire        trigger;
    wire        gate;
    wire [31:0] tick_count;
    wire        interlock_ok;
    wire        irq;

    timing_ctrl_top #(
        .CLK_HZ        (CLK_HZ_TB),
        .TICK_HZ       (TICK_HZ_TB),
        .DEFAULT_DTRIG (10),
        .DEFAULT_GATEW (5)
    ) dut (
        .clk_i             (clk),
        .rstn_i            (rstn),
        .hv_ok_i           (hv_ok),
        .vacuum_ok_i       (vacuum_ok),
        .water_ok_i        (water_ok),
        .laser_shutter_ok_i(shutter_ok),
        .wb_cyc_i          (wb_cyc),
        .wb_stb_i          (wb_stb),
        .wb_we_i           (wb_we),
        .wb_adr_i          (wb_adr),
        .wb_dat_i          (wb_dat_i),
        .wb_sel_i          (wb_sel),
        .wb_ack_o          (wb_ack),
        .wb_err_o          (wb_err),
        .wb_dat_o          (wb_dat_o),
        .tick_o            (tick),
        .trigger_o         (trigger),
        .gate_o            (gate),
        .tick_count_o      (tick_count),
        .interlock_ok_o    (interlock_ok),
        .irq_o             (irq)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;
    integer ticks_seen = 0;
    integer triggers_seen = 0;

    // count tick + trigger pulses
    always @(posedge clk) begin
        if (tick)    ticks_seen    = ticks_seen + 1;
        if (trigger) triggers_seen = triggers_seen + 1;
    end

    task wb_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            wb_adr   <= {24'd0, addr};
            wb_dat_i <= data;
            wb_we    <= 1'b1;
            wb_sel   <= 4'b1111;
            wb_cyc   <= 1'b1;
            wb_stb   <= 1'b1;
            @(posedge clk);
            while (!wb_ack) @(posedge clk);
            wb_cyc <= 1'b0; wb_stb <= 1'b0; wb_we <= 1'b0;
            @(posedge clk);
        end
    endtask

    task wb_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            wb_adr <= {24'd0, addr};
            wb_we  <= 1'b0;
            wb_sel <= 4'b1111;
            wb_cyc <= 1'b1;
            wb_stb <= 1'b1;
            @(posedge clk);
            while (!wb_ack) @(posedge clk);
            data = wb_dat_o;
            wb_cyc <= 1'b0; wb_stb <= 1'b0;
            @(posedge clk);
        end
    endtask

    task check(input [255:0] tag, input cond);
        begin
            if (cond) begin
                $display("[TB PASS] %0s", tag);
                pass_count = pass_count + 1;
            end else begin
                $display("[TB FAIL] %0s", tag);
                fail_count = fail_count + 1;
            end
        end
    endtask

    reg [31:0] rd;

    initial begin
        rstn = 0;
        wb_cyc = 0; wb_stb = 0; wb_we = 0;
        wb_adr = 0; wb_dat_i = 0; wb_sel = 0;
        hv_ok = 1; vacuum_ok = 1; water_ok = 1; shutter_ok = 1;
        ticks_seen = 0;
        triggers_seen = 0;
        #100;
        rstn = 1;
        @(posedge clk);

        // Stage 1: pre-enable, disabled — no ticks should fire
        repeat (20) @(posedge clk);
        check("disabled — no ticks fired", ticks_seen == 0);

        // Stage 2: read N_TIER_LOCK to confirm bus is alive
        wb_read(8'h28, rd);
        check("N_TIER_LOCK == J₂ = 24", rd == 32'h0000_0018);

        // Stage 3: enable the controller via CTRL.bit0
        wb_write(8'h00, 32'h0000_0001);
        // Wait for ~5 ticks (5 µs at 1 MHz tick)
        repeat (5 * (CLK_HZ_TB / TICK_HZ_TB) + 100) @(posedge clk);
        check("after enable, ticks_seen >= 4", ticks_seen >= 4);
        check("triggers fired with ticks", triggers_seen >= 4);

        // Stage 4: TICK_COUNT register reflects datapath
        wb_read(8'h08, rd);
        check("TICK_COUNT register matches datapath", rd >= 4 && rd == tick_count);

        // Stage 5: drop interlock — ticks should freeze
        hv_ok = 0;
        repeat (20) @(posedge clk);
        wb_read(8'h04, rd);
        check("STATUS.interlock_ok cleared", rd[0] == 1'b0);
        wb_read(8'h18, rd);
        check("INTERLOCK_RAW reflects hv drop", rd[3:0] == 4'b1110);

        // Stage 6: with interlock down, set IRQ_MASK=interlock_drop, expect irq
        wb_write(8'h1C, 32'h0000_0001);    // mask interlock-drop
        repeat (5) @(posedge clk);
        check("IRQ asserted on interlock drop", irq == 1'b1);

        // W1C clears
        wb_write(8'h20, 32'h0000_0001);
        repeat (5) @(posedge clk);
        check("IRQ cleared after W1C", irq == 1'b0);

        // Stage 7: re-enable interlock, ticks resume
        hv_ok = 1;
        ticks_seen = 0;
        repeat (3 * (CLK_HZ_TB / TICK_HZ_TB) + 100) @(posedge clk);
        check("after interlock recovery, ticks resume", ticks_seen >= 2);

        // Stage 8: software disable via CTRL.enable=0 stops ticks
        wb_write(8'h00, 32'h0000_0000);
        repeat (10) @(posedge clk);
        ticks_seen = 0;
        repeat (3 * (CLK_HZ_TB / TICK_HZ_TB) + 100) @(posedge clk);
        check("CTRL.enable=0 stops new ticks", ticks_seen == 0);

        $display("");
        $display("================================================");
        $display("  timing_ctrl_top_tb: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("================================================");
        if (fail_count == 0) begin
            $display("[TB PASS] timing_ctrl_top end-to-end integration");
            $finish(0);
        end else begin
            $display("[TB FAIL] %0d check(s) failed", fail_count);
            $finish(1);
        end
    end

    initial begin
        #10_000_000;     // 10 ms
        $display("[TB FAIL] timeout");
        $finish(2);
    end

endmodule

`default_nettype wire
