// firmware/hdl/raptor_cluster.v — HEXA-RAPTOR-01 Kintex US top
//
// Phase D skeleton (compiles in Vivado 2024.1+ for XCKU040 KCU105 board;
// not yet flashable — boards TBD per .roadmap §A.6 Phase E).
// Spec source: firmware/sim/raptor_cluster.hexa (11/11 PASS).

`timescale 1ns / 1ps

module raptor_cluster_top (
    // ── 200 MHz Wenzel OCXO ref (shared family with launch_telemetry) ──
    input  wire         ref_200m_p,
    input  wire         ref_200m_n,
    input  wire         rst_n,

    // ── HDMI 1080p60 capture (TMDS clock + 3 lanes) ───
    input  wire         hdmi_clk_p,
    input  wire         hdmi_clk_n,
    input  wire [2:0]   hdmi_data_p,
    input  wire [2:0]   hdmi_data_n,

    // ── 33-channel deconv data path (one per Raptor; chained from PS) ──
    input  wire [33*16-1:0] engine_telemetry_flat,  // 33 × 16-bit packed
    input  wire             engine_valid,

    // ── status / interlock ───
    output wire [2:0]   state_dbg,
    output wire         safety_interlock,
    output wire [31:0]  cluster_thrust_kn   // total cluster thrust kN
);

    // ── n=6 lattice constants ───
    localparam [31:0] HEXA_REG_ID    = 32'h060C_0402;
    localparam [5:0]  CLUSTER_N      = 6'd33;          // σ·n/φ−3
    localparam [4:0]  RING_INNER     = 5'd3;
    localparam [4:0]  RING_MID       = 5'd10;
    localparam [4:0]  RING_OUTER     = 5'd20;          // J₂−τ

    // ── 7-state controller ───
    localparam [2:0]
        S_IDLE             = 3'd0,
        S_ARMED            = 3'd1,
        S_CAPTURE          = 3'd2,
        S_OCR              = 3'd3,
        S_DECONVOLVE       = 3'd4,
        S_CLUSTER_VALIDATE = 3'd5,
        S_REPORT           = 3'd6;

    reg [2:0] state, state_n;

    // ── PLL: 200 MHz → pix_clk_124m (HDMI 1080p60) ───
    wire pix_clk_124m;
    wire mmcm_locked;
    clk_wiz_raptor clk_inst (
        .clk_in1_p(ref_200m_p), .clk_in1_n(ref_200m_n),
        .clk_out1(pix_clk_124m), .reset(~rst_n), .locked(mmcm_locked)
    );
    wire rst_sync = ~(rst_n & mmcm_locked);

    // ── safety interlock (≤ 50 ms — 6.2 M cycles @ 124 MHz) ───
    reg [22:0] interlock_ctr;
    reg        interlock_q;
    always @(posedge pix_clk_124m or posedge rst_sync) begin
        if (rst_sync)                        interlock_q <= 1'b1;
        else if (state == S_REPORT)          interlock_q <= 1'b0;
        else if (interlock_ctr == 23'd6_220_000) interlock_q <= 1'b1;
        else                                 interlock_ctr <= interlock_ctr + 1'b1;
    end
    assign safety_interlock = interlock_q;

    // ── state machine ───
    always @(*) begin
        case (state)
            S_IDLE:             state_n = mmcm_locked ? S_ARMED : S_IDLE;
            S_ARMED:            state_n = /* hdmi_lk */ S_CAPTURE;
            S_CAPTURE:          state_n = /* fr_done */ S_OCR;
            S_OCR:              state_n = /* ocr_d  */  S_DECONVOLVE;
            S_DECONVOLVE:       state_n = /* dc_d   */  S_CLUSTER_VALIDATE;
            S_CLUSTER_VALIDATE: state_n = /* cv_d   */  S_REPORT;
            S_REPORT:           state_n = engine_valid ? S_IDLE : S_REPORT;
            default:            state_n = S_IDLE;
        endcase
    end
    always @(posedge pix_clk_124m or posedge rst_sync) begin
        if (rst_sync) state <= S_IDLE;
        else          state <= state_n;
    end
    assign state_dbg = state;

    // ── 33-channel cluster sum (combinational; placeholder for Stage-1) ──
    integer i;
    reg [31:0] sum_kn;
    always @(*) begin
        sum_kn = 32'd0;
        for (i = 0; i < 33; i = i + 1) begin
            sum_kn = sum_kn + engine_telemetry_flat[i*16 +: 16];
        end
    end
    assign cluster_thrust_kn = sum_kn;

endmodule
