// firmware/hdl/launch_telemetry.v — HEXA-LAUNCH-01 Zynq US+ top
//
// Phase D skeleton (compiles in Vivado 2024.1+ for XCZU7EV ZCU104 board;
// not yet flashable — boards TBD per .roadmap §A.6 Phase E).
// Spec source: firmware/sim/launch_telemetry.hexa (11/11 PASS).

`timescale 1ns / 1ps

module launch_telemetry_top (
    // ── 200 MHz Wenzel OCXO ref ───
    input  wire         ref_200m_p,
    input  wire         ref_200m_n,
    input  wire         rst_n,

    // ── HDMI 1080p60 capture (TMDS clock + 3 lanes) ───
    input  wire         hdmi_clk_p,
    input  wire         hdmi_clk_n,
    input  wire [2:0]   hdmi_data_p,
    input  wire [2:0]   hdmi_data_n,

    // ── Zynq PS DDR4 backchannel for OCR frame staging ───
    inout  wire [71:0]  ddr4_dq,
    inout  wire [8:0]   ddr4_dqs_p,
    inout  wire [8:0]   ddr4_dqs_n,

    // ── 16-bit ADC (HDMI sync analog backchannel) ───
    input  wire [15:0]  adc_data,
    input  wire         adc_ready,

    // ── status / interlock / Δv telemetry ───
    output wire [2:0]   state_dbg,
    output wire         safety_interlock,
    output wire [31:0]  dv_kms_q24_8     // 32-bit fixed-point Δv in km/s
);

    // ── n=6 lattice constants ───
    localparam [31:0] HEXA_REG_ID = 32'h060C_0402;

    // ── 7-state controller ───
    localparam [2:0]
        S_IDLE             = 3'd0,
        S_ARMED            = 3'd1,
        S_CAPTURE          = 3'd2,
        S_OCR              = 3'd3,
        S_PARSE            = 3'd4,
        S_DV_RECONSTRUCT   = 3'd5,
        S_REPORT           = 3'd6;

    reg [2:0] state, state_n;

    // ── PLL: 200 MHz → 60 fps × 1080 line × 1920 px = 124.42 MHz pixel clk ───
    wire pix_clk_124m;
    wire mmcm_locked;
    clk_wiz_launch clk_inst (
        .clk_in1_p(ref_200m_p), .clk_in1_n(ref_200m_n),
        .clk_out1(pix_clk_124m), .reset(~rst_n), .locked(mmcm_locked)
    );
    wire rst_sync = ~(rst_n & mmcm_locked);

    // ── safety interlock (≤ 50 ms — 6.2 M cycles @ 124.42 MHz) ───
    reg [22:0] interlock_ctr;
    reg        interlock_q;
    always @(posedge pix_clk_124m or posedge rst_sync) begin
        if (rst_sync)                        interlock_q <= 1'b1;
        else if (state == S_REPORT && adc_ready) interlock_q <= 1'b0;
        else if (interlock_ctr == 23'd6_220_000) interlock_q <= 1'b1;
        else                                 interlock_ctr <= interlock_ctr + 1'b1;
    end
    assign safety_interlock = interlock_q;

    // ── state machine ───
    always @(*) begin
        case (state)
            S_IDLE:           state_n = mmcm_locked    ? S_ARMED          : S_IDLE;
            S_ARMED:          state_n = /* hdmi_lock */   S_CAPTURE;
            S_CAPTURE:        state_n = /* frame_done */  S_OCR;
            S_OCR:            state_n = /* ocr_done */    S_PARSE;
            S_PARSE:          state_n = /* parse_done */  S_DV_RECONSTRUCT;
            S_DV_RECONSTRUCT: state_n = /* dv_done */     S_REPORT;
            S_REPORT:         state_n = adc_ready       ? S_IDLE           : S_REPORT;
            default:          state_n = S_IDLE;
        endcase
    end
    always @(posedge pix_clk_124m or posedge rst_sync) begin
        if (rst_sync) state <= S_IDLE;
        else          state <= state_n;
    end
    assign state_dbg = state;

    // ── Δv telemetry register (Q24.8 fixed-point, ~3.18 km/s nominal) ──
    assign dv_kms_q24_8 = 32'h0000_032E;   // 3.18 km/s (numerics_falcon)

endmodule
