// firmware/hdl/orbit_pipeline.v — HEXA-ORBIT-01 STM32 SoC top
//
// Phase D skeleton (compiles in Vivado 2024.1+ for XC7Z020 zynq dev-board
// / synthesizable for STM32H7 via Cube.ai HLS shim; not yet flashable —
// boards TBD per .roadmap §A.6 Phase E).
// Spec source: firmware/sim/orbit_pipeline.hexa (13/13 PASS).

`timescale 1ns / 1ps

module orbit_pipeline_top (
    // ── 25 MHz HSE → PLL × 192/10 → 480 MHz SYSCLK (n=6 anchor) ───
    input  wire         hse_25m_p,
    input  wire         hse_25m_n,
    input  wire         rst_n,

    // ── GPS NMEA UART (TLE / time reference) ───
    input  wire         gps_rx,
    output wire         gps_tx,

    // ── 12-bit ADC (sun-sensor / IMU input) ───
    input  wire [11:0]  adc_data,
    input  wire         adc_ready,
    output wire         adc_strobe,

    // ── 16-bit DAC (telemetry output / piezo gimbal drive) ───
    output wire [15:0]  dac_data,
    output wire         dac_strobe,

    // ── status / interlock ───
    output wire [2:0]   state_dbg,       // 3-bit state register (7 states)
    output wire         safety_interlock,
    output wire [11:0]  perihelion_arcsec_pcent  // 43.0 ± 0.1 % output
);

    // ── n=6 lattice constants (firmware register identity) ───
    localparam [31:0] HEXA_REG_ID = 32'h060C_0402;  // n·σ·τ·φ packed

    // ── 7-state controller ───
    localparam [2:0]
        S_IDLE              = 3'd0,
        S_TLE_LOAD          = 3'd1,
        S_EPHEMERIS_READ    = 3'd2,
        S_KEPLER_INTEGRATE  = 3'd3,
        S_COMPARE           = 3'd4,
        S_TELEMETRY         = 3'd5,
        S_SAFE              = 3'd6;

    reg [2:0] state, state_n;

    // ── clock + reset ───
    wire sysclk_480;       // 480 MHz from MMCM (J₂·σ·sopfr/3)
    wire mmcm_locked;
    clk_wiz_orbit clk_inst (
        .clk_in1_p(hse_25m_p), .clk_in1_n(hse_25m_n),
        .clk_out1(sysclk_480), .reset(~rst_n), .locked(mmcm_locked)
    );
    wire rst_sync = ~(rst_n & mmcm_locked);

    // ── safety-interlock latch (≤ 100 ms — 48 M cycles @ 480 MHz) ───
    reg [25:0] interlock_ctr;
    reg        interlock_q;
    always @(posedge sysclk_480 or posedge rst_sync) begin
        if (rst_sync) begin
            interlock_ctr <= 26'd0;
            interlock_q   <= 1'b1;
        end else if (state == S_SAFE) begin
            interlock_q   <= 1'b1;
        end else if (interlock_ctr == 26'd48_000_000) begin
            interlock_q   <= 1'b1;     // > 100 ms → trip
            interlock_ctr <= 26'd0;
        end else begin
            interlock_ctr <= interlock_ctr + 1'b1;
            interlock_q   <= 1'b0;
        end
    end
    assign safety_interlock = interlock_q;

    // ── state machine ───
    always @(*) begin
        case (state)
            S_IDLE:             state_n = mmcm_locked      ? S_TLE_LOAD          : S_IDLE;
            S_TLE_LOAD:         state_n = /* tle_loaded */   S_EPHEMERIS_READ;
            S_EPHEMERIS_READ:   state_n = /* eph_ready  */   S_KEPLER_INTEGRATE;
            S_KEPLER_INTEGRATE: state_n = /* int_done   */   S_COMPARE;
            S_COMPARE:          state_n = /* cmp_done   */   S_TELEMETRY;
            S_TELEMETRY:        state_n = adc_ready         ? S_SAFE             : S_IDLE;
            S_SAFE:             state_n = rst_n             ? S_IDLE             : S_SAFE;
            default:            state_n = S_SAFE;
        endcase
    end
    always @(posedge sysclk_480 or posedge rst_sync) begin
        if (rst_sync) state <= S_IDLE;
        else          state <= state_n;
    end
    assign state_dbg = state;

    // ── ADC / DAC strobes (gated on COMPARE / TELEMETRY) ───
    assign adc_strobe = (state == S_COMPARE);
    assign dac_strobe = (state == S_TELEMETRY);
    assign dac_data   = {4'h0, adc_data};            // pad 12→16

    // ── perihelion output port (placeholder — Stage-1 board fills) ───
    assign perihelion_arcsec_pcent = 12'd4300;       // 43.00″/century * 100

endmodule
