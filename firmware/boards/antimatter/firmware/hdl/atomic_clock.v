// firmware/hdl/atomic_clock.v — CPT bench atomic-clock counter top
// Phase D skeleton (Vivado 2024.1+ for XCKU040; not flashable).
// Spec: firmware/sim/atomic_clock_counter.hexa (11/11 PASS).

`timescale 1ns / 1ps

module atomic_clock_top (
    // ── 10 MHz Cs reference ───
    input  wire         cs_ref_10m_p,
    input  wire         cs_ref_10m_n,
    input  wire         cs_pps_in,                  // 1 PPS from Cs

    // ── TDC7201 SPI + start/stop ───
    output wire         tdc_csb,
    output wire         tdc_sclk,
    output wire         tdc_din,
    input  wire         tdc_dout,
    input  wire         tdc_int,
    output wire         tdc_start,
    input  wire         tdc_stop1,                  // ν_c phase
    input  wire         tdc_stop2,                  // Cs cycle ref

    // ── LTC2387 (24-bit) ADC for analog laser-error ───
    input  wire         ltc_sdo_p,
    input  wire         ltc_sdo_n,
    output wire         ltc_cnv,
    input  wire         ltc_clkout,

    // ── ADF4356 LO synth SPI ───
    output wire         adf_ce,
    output wire         adf_data,
    output wire         adf_le,
    input  wire         adf_muxout,                 // PLL lock

    // ── laser-lock error feedback DAC (SPI) ───
    output wire         laser_dac_cs,
    output wire         laser_dac_sck,
    output wire         laser_dac_mosi,

    // ── photodiode pulse (1S-2S fluorescence event) ───
    input  wire         photodiode_pulse,

    // ── host ───
    output wire         uart_host_tx,
    input  wire         uart_host_rx,
    output reg  [3:0]   led_status
);

    // ── 10 MHz reference → 100 MHz system clock via Clock Wizard ───
    wire cs_ref_10m;
    IBUFGDS u_csref_ibuf (.I(cs_ref_10m_p), .IB(cs_ref_10m_n), .O(cs_ref_10m));

    wire pll_locked;
    wire sys_clk;
    // Clock Wizard IP placeholder

    // ── ν_c counter: count Cs ref cycles between TDC start/stop1 events ───
    // Goal: cumulative count over 1000 s gives σ_y ≤ 1e-15 (Cs spec).

    reg [63:0] nu_c_phase_count;           // 64-bit accumulator
    reg        tdc_int_d, tdc_int_dd;       // edge-detect TDC done

    always @(posedge sys_clk) begin
        if (~pll_locked) begin
            nu_c_phase_count <= 0;
            tdc_int_d  <= 0;
            tdc_int_dd <= 0;
        end else begin
            tdc_int_d  <= tdc_int;
            tdc_int_dd <= tdc_int_d;
            // rising edge of tdc_int → latch result via SPI (handler in PS)
            if (tdc_int_d & ~tdc_int_dd) begin
                // (PS-side reads result via SPI; FPGA increments tally)
                nu_c_phase_count <= nu_c_phase_count + 1;
            end
        end
    end

    // ── photodiode pulse counter (1S-2S events) ───
    reg [31:0] pd_event_count;
    reg pd_d, pd_dd;
    always @(posedge sys_clk) begin
        pd_d  <= photodiode_pulse;
        pd_dd <= pd_d;
        if (pd_d & ~pd_dd) pd_event_count <= pd_event_count + 1;
    end

    // ── PLL lock status indicator ───
    always @(posedge sys_clk) begin
        led_status[0] <= pll_locked;
        led_status[1] <= adf_muxout;       // LO PLL lock
        led_status[2] <= |nu_c_phase_count;
        led_status[3] <= |pd_event_count;
    end

    // (full implementation: TDC SPI controller, ADF4356 init sequencer,
    // PI laser-lock controller w/ LTC2387 input → laser DAC output,
    // Allan deviation accumulator — Phase D)

endmodule
