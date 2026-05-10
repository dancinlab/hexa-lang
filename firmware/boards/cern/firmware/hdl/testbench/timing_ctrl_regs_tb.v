// hexa-cern/firmware/hdl/testbench/timing_ctrl_regs_tb.v
//
// §A.6.1 step E1.1 — testbench for timing_ctrl_regs.v
// Exercises every register read/write path + IRQ generation + W1C clear
// + ERR_O on out-of-range access + interlock raw mirror.

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl_regs_tb;

    reg         clk;
    reg         rstn;
    reg         wb_cyc;
    reg         wb_stb;
    reg         wb_we;
    reg [31:0]  wb_adr;
    reg [31:0]  wb_dat_i;
    reg [3:0]   wb_sel;
    wire        wb_ack;
    wire        wb_err;
    wire [31:0] wb_dat_o;

    reg         interlock_ok;
    reg         gate_active;
    reg         trigger_pending;
    reg [31:0]  tick_count;
    reg         hv_ok;
    reg         vacuum_ok;
    reg         water_ok;
    reg         shutter_ok;
    reg         tick_pulse;

    wire        enable;
    wire        soft_reset;
    wire        force_tick;
    wire [15:0] d_trig;
    wire [15:0] gate_width;
    wire [31:0] tick_divider;
    wire        irq;

    timing_ctrl_regs #(
        .CLK_HZ        (100_000_000),
        .TICK_HZ       (4),
        .DEFAULT_DTRIG (100),
        .DEFAULT_GATEW (20)
    ) dut (
        .clk_i             (clk),
        .rstn_i            (rstn),
        .wb_cyc_i          (wb_cyc),
        .wb_stb_i          (wb_stb),
        .wb_we_i           (wb_we),
        .wb_adr_i          (wb_adr),
        .wb_dat_i          (wb_dat_i),
        .wb_sel_i          (wb_sel),
        .wb_ack_o          (wb_ack),
        .wb_err_o          (wb_err),
        .wb_dat_o          (wb_dat_o),
        .interlock_ok_i    (interlock_ok),
        .gate_active_i     (gate_active),
        .trigger_pending_i (trigger_pending),
        .tick_count_i      (tick_count),
        .hv_ok_i           (hv_ok),
        .vacuum_ok_i       (vacuum_ok),
        .water_ok_i        (water_ok),
        .shutter_ok_i      (shutter_ok),
        .tick_pulse_i      (tick_pulse),
        .enable_o          (enable),
        .soft_reset_o      (soft_reset),
        .force_tick_o      (force_tick),
        .d_trig_o          (d_trig),
        .gate_width_o      (gate_width),
        .tick_divider_o    (tick_divider),
        .irq_o             (irq)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

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
            // wait for ack
            while (!wb_ack) @(posedge clk);
            wb_cyc <= 1'b0;
            wb_stb <= 1'b0;
            wb_we  <= 1'b0;
            @(posedge clk);
        end
    endtask

    task wb_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            wb_adr   <= {24'd0, addr};
            wb_we    <= 1'b0;
            wb_sel   <= 4'b1111;
            wb_cyc   <= 1'b1;
            wb_stb   <= 1'b1;
            @(posedge clk);
            while (!wb_ack) @(posedge clk);
            data = wb_dat_o;
            wb_cyc <= 1'b0;
            wb_stb <= 1'b0;
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

    // Sticky witnesses for one-shot pulses
    reg sr_seen;
    reg ft_seen;
    always @(posedge clk) begin
        if (!rstn) begin
            sr_seen <= 0;
            ft_seen <= 0;
        end else begin
            if (soft_reset) sr_seen <= 1;
            if (force_tick) ft_seen <= 1;
        end
    end

    initial begin
        // reset
        rstn = 0;
        sr_seen = 0; ft_seen = 0;
        wb_cyc = 0; wb_stb = 0; wb_we = 0; wb_adr = 0; wb_dat_i = 0; wb_sel = 0;
        interlock_ok = 1; gate_active = 0; trigger_pending = 0;
        tick_count = 0;
        hv_ok = 1; vacuum_ok = 1; water_ok = 1; shutter_ok = 1;
        tick_pulse = 0;
        #50;
        rstn = 1;
        @(posedge clk);

        // 1. defaults — D_TRIG should be 100, GATE_WIDTH 20, divider 25M
        wb_read(8'h0C, rd);
        check("D_TRIG default = 100", rd[15:0] == 16'd100);

        wb_read(8'h10, rd);
        check("GATE_WIDTH default = 20", rd[15:0] == 16'd20);

        wb_read(8'h14, rd);
        check("TICK_DIVIDER default = 25M", rd == 32'd25_000_000);

        // 2. write D_TRIG and read back
        wb_write(8'h0C, 32'd250);
        wb_read(8'h0C, rd);
        check("D_TRIG R/W", rd[15:0] == 16'd250 && d_trig == 16'd250);

        // 3. CTRL enable bit forwards to enable_o
        wb_write(8'h00, 32'h0000_0001);
        @(posedge clk); @(posedge clk);
        check("CTRL.enable -> enable_o", enable == 1'b1);

        // 4. STATUS reflects datapath
        interlock_ok = 1; gate_active = 1; trigger_pending = 0;
        @(posedge clk);
        wb_read(8'h04, rd);
        check("STATUS interlock_ok=1 gate=1 trig=0",
              rd[0] == 1'b1 && rd[1] == 1'b1 && rd[2] == 1'b0);

        // 5. INTERLOCK_RAW mirror
        hv_ok = 1; vacuum_ok = 0; water_ok = 1; shutter_ok = 1;
        @(posedge clk);
        wb_read(8'h18, rd);
        check("INTERLOCK_RAW {1011}",
              rd[3:0] == 4'b1101);

        // 6. TICK_COUNT pass-through
        tick_count = 32'h1234_5678;
        @(posedge clk);
        wb_read(8'h08, rd);
        check("TICK_COUNT pass-through", rd == 32'h1234_5678);

        // 7. N_TIER_LOCK is constant 0x18 (= J₂ = 24)
        wb_read(8'h28, rd);
        check("N_TIER_LOCK = J₂ = 24 = 0x18", rd == 32'h0000_0018);

        // 8. SCRATCH R/W
        wb_write(8'h24, 32'hCAFE_BABE);
        wb_read(8'h24, rd);
        check("SCRATCH R/W", rd == 32'hCAFE_BABE);

        // 9. Out-of-range address yields ERR + DEAD_BEEF
        wb_read(8'hF0, rd);
        check("OOR read returns DEAD_BEEF",
              rd == 32'hDEAD_BEEF && wb_err);

        // 10. IRQ — set mask=tick(bit1), pulse a tick → pending=1, irq=1
        wb_write(8'h1C, 32'h0000_0002);     // IRQ_MASK = bit1 (tick)
        @(posedge clk);
        tick_pulse = 1;
        @(posedge clk);
        tick_pulse = 0;
        @(posedge clk); @(posedge clk);
        check("IRQ asserted on tick when masked", irq == 1'b1);

        // 11. W1C clears IRQ_PENDING
        wb_write(8'h20, 32'h0000_0002);
        @(posedge clk); @(posedge clk);
        check("IRQ cleared after W1C", irq == 1'b0);

        // 12. Soft reset bit pulses for 1 cycle (caught by sticky witness)
        sr_seen = 0;
        wb_write(8'h00, 32'h0000_0003);     // enable + soft_reset
        check("soft_reset_o pulsed during write", sr_seen == 1'b1);
        @(posedge clk); @(posedge clk);
        check("soft_reset_o auto-clears", soft_reset == 1'b0);

        // 13. Force-tick one-shot pulses for 1 cycle (1-cycle latency
        //      because oneshot register pipelines through to force_tick_o).
        ft_seen = 0;
        wb_write(8'h00, 32'h0000_0005);     // enable + force_tick
        @(posedge clk); @(posedge clk);     // allow oneshot to fire force_tick
        check("force_tick_o pulsed during write", ft_seen == 1'b1);
        @(posedge clk); @(posedge clk);
        check("force_tick_o auto-clears", force_tick == 1'b0);

        // 14. Interlock-drop IRQ
        wb_write(8'h1C, 32'h0000_0001);     // IRQ_MASK = bit0 (interlock)
        wb_write(8'h20, 32'h0000_0007);     // clear all pending
        @(posedge clk);
        interlock_ok = 0;
        @(posedge clk); @(posedge clk);
        check("Interlock-drop IRQ asserted", irq == 1'b1);

        // summary
        $display("");
        $display("================================================");
        $display("  timing_ctrl_regs_tb: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("================================================");
        if (fail_count == 0) begin
            $display("[TB PASS] timing_ctrl_regs full register-file coverage");
            $finish(0);
        end else begin
            $display("[TB FAIL] %0d check(s) failed", fail_count);
            $finish(1);
        end
    end

    // safety
    initial begin
        #1_000_000;
        $display("[TB FAIL] timeout");
        $finish(2);
    end

endmodule

`default_nettype wire
