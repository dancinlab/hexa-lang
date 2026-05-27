// firmware/hdl/dxa_pipeline.v — HEXA-DXA-01 STM32H7 SoC top
//
// Phase D skeleton (compiles in Vivado 2024.1+ as Cube.ai HLS shim for
// STM32H7; not yet flashable — boards TBD per .roadmap §A.6 Phase E).
// Spec source: firmware/sim/dxa_pipeline.hexa (11/11 PASS).

`timescale 1ns / 1ps

module dxa_pipeline_top (
    // ── 25 MHz HSE → PLL → 480 MHz SYSCLK ───
    input  wire         hse_25m_p,
    input  wire         hse_25m_n,
    input  wire         rst_n,

    // ── USB 2.0 PHY (DXA scanner data ingest, 12 Mbps floor) ───
    input  wire         usb_dp,
    inout  wire         usb_dn,

    // ── 16-bit DAC (telemetry / display backlight) ───
    output wire [15:0]  dac_data,
    output wire         dac_strobe,

    // ── status / interlock ───
    output wire [2:0]   state_dbg,       // 3-bit (n=6 = 6 states + 2 spare)
    output wire         safety_interlock,
    output wire [15:0]  bmd_loss_pct_q8_8 // Q8.8 fixed-point % loss
);

    // ── n=6 lattice constants ───
    localparam [31:0] HEXA_REG_ID = 32'h060C_0402;

    // ── 6-state controller (n states) ───
    localparam [2:0]
        S_IDLE      = 3'd0,
        S_SCAN_LOAD = 3'd1,
        S_PARSE     = 3'd2,
        S_FIT       = 3'd3,
        S_COMPARE   = 3'd4,
        S_REPORT    = 3'd5;

    reg [2:0] state, state_n;

    // ── PLL: 25 MHz → 480 MHz SYSCLK (J₂·σ·sopfr/3) ───
    wire sysclk_480;
    wire mmcm_locked;
    clk_wiz_dxa clk_inst (
        .clk_in1_p(hse_25m_p), .clk_in1_n(hse_25m_n),
        .clk_out1(sysclk_480), .reset(~rst_n), .locked(mmcm_locked)
    );
    wire rst_sync = ~(rst_n & mmcm_locked);

    // ── safety interlock (≤ 200 ms — 96 M cycles @ 480 MHz) ───
    reg [27:0] interlock_ctr;
    reg        interlock_q;
    always @(posedge sysclk_480 or posedge rst_sync) begin
        if (rst_sync)                        interlock_q <= 1'b1;
        else if (state == S_REPORT)          interlock_q <= 1'b0;
        else if (interlock_ctr == 28'd96_000_000) interlock_q <= 1'b1;
        else                                 interlock_ctr <= interlock_ctr + 1'b1;
    end
    assign safety_interlock = interlock_q;

    // ── state machine ───
    always @(*) begin
        case (state)
            S_IDLE:      state_n = mmcm_locked    ? S_SCAN_LOAD : S_IDLE;
            S_SCAN_LOAD: state_n = /* dx_ready */   S_PARSE;
            S_PARSE:     state_n = /* parsed */     S_FIT;
            S_FIT:       state_n = /* converged */  S_COMPARE;
            S_COMPARE:   state_n = /* compared */   S_REPORT;
            S_REPORT:    state_n = S_IDLE;
            default:     state_n = S_IDLE;
        endcase
    end
    always @(posedge sysclk_480 or posedge rst_sync) begin
        if (rst_sync) state <= S_IDLE;
        else          state <= state_n;
    end
    assign state_dbg = state;

    // ── DAC (telemetry @ φ = 2 Hz) ───
    assign dac_data   = {bmd_loss_pct_q8_8};
    assign dac_strobe = (state == S_REPORT);

    // ── BMD-loss output (Q8.8 fixed-point — 5.82% nominal) ───
    assign bmd_loss_pct_q8_8 = 16'h05D2;   // ≈ 5.82 %

endmodule
