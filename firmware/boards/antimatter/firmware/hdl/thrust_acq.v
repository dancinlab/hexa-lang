// firmware/hdl/thrust_acq.v — Thrust-acquisition 16-channel waveform top
// Phase D skeleton (Vivado 2024.1+ for XCVU13P; not flashable).
// Spec: firmware/sim/thrust_acquisition.hexa (10/10 PASS).

`timescale 1ns / 1ps

module thrust_acq_top (
    // ── 10 MHz Cs reference (from atomic_clock board, daisy-chain BNC) ───
    input  wire         cs_ref_10m_p,
    input  wire         cs_ref_10m_n,

    // ── 16 ADC channels via JESD204C (8 chips × 2 ch) ───
    // Each ADC: 4 SerDes lanes @ 32 Gbps. (Lane signals consolidated as buses.)
    input  wire [127:0] adc_lane_p,                 // 8 chips × 4 lanes × 4 bits = 128 wires (illustrative grouping)
    input  wire [127:0] adc_lane_n,
    output wire         adc_sysref_p,               // JESD204C SYSREF
    output wire         adc_sysref_n,
    output wire [15:0]  adc_trigger_p,              // LVDS fan-out, 1 per channel
    output wire [15:0]  adc_trigger_n,

    // ── Watt-balance precision ADC (LTC2387, 24-bit) ───
    input  wire         watt_sdo_p,
    input  wire         watt_sdo_n,
    output wire         watt_cnv,

    // ── BGO + ToF discriminator inputs ───
    input  wire         bgo_trig_in,
    input  wire         tof_trig_in,
    output wire         coincidence_out,            // global trigger to all ADCs

    // ── NIM/CAMAC trigger inputs (8 channels) ───
    input  wire [7:0]   nim_in,

    // ── PCIe Gen4 ×16 → host (via Vivado XDMA) ───
    input  wire         pcie_refclk_p,
    input  wire         pcie_refclk_n,
    input  wire         pcie_perstn,
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,

    // ── DDR4 memory (8 chips × 16-bit = 128-bit data bus) ───
    inout  wire [63:0]  ddr4_dq,                    // illustrative (true is 128-bit)
    inout  wire [7:0]   ddr4_dqs_p,
    inout  wire [7:0]   ddr4_dqs_n,
    output wire [16:0]  ddr4_addr,
    // ... (full DDR4 signal list elided)

    // ── host ───
    output wire         uart_host_tx,
    input  wire         uart_host_rx,
    output reg  [3:0]   led_status
);

    // ── reference + system clocks ───
    wire cs_ref_10m;
    IBUFGDS u_csref_ibuf (.I(cs_ref_10m_p), .IB(cs_ref_10m_n), .O(cs_ref_10m));

    wire pll_locked;
    wire sys_clk;                                   // 250 MHz typical
    // Clock Wizard placeholder

    // ── coincidence logic: BGO ∧ ToF within 50 ns window → trigger ───
    parameter integer COINC_WINDOW_CYCLES = 12;     // 12 × 4 ns = 48 ns @ 250 MHz

    reg [COINC_WINDOW_CYCLES-1:0] bgo_shift, tof_shift;
    reg coincidence_out_r;

    always @(posedge sys_clk) begin
        bgo_shift <= {bgo_shift[COINC_WINDOW_CYCLES-2:0], bgo_trig_in};
        tof_shift <= {tof_shift[COINC_WINDOW_CYCLES-2:0], tof_trig_in};
        coincidence_out_r <= |bgo_shift & |tof_shift;
    end

    assign coincidence_out = coincidence_out_r;

    // ── trigger fan-out: when coincidence fires, replicate to all 16 ADC trigger lines ───
    // Use LVDS OBUFDS w/ matched routing on PCB side for sub-1 ns skew.
    genvar gi;
    generate
      for (gi = 0; gi < 16; gi = gi + 1) begin : g_trig_fanout
        OBUFDS u_obufds (
          .I  (coincidence_out_r),
          .O  (adc_trigger_p[gi]),
          .OB (adc_trigger_n[gi])
        );
      end
    endgenerate

    // ── event counter ───
    reg [31:0] event_count;
    reg coinc_d, coinc_dd;
    always @(posedge sys_clk) begin
        coinc_d  <= coincidence_out_r;
        coinc_dd <= coinc_d;
        if (coinc_d & ~coinc_dd) event_count <= event_count + 1;
    end

    // ── status LEDs ───
    always @(posedge sys_clk) begin
        led_status[0] <= pll_locked;
        led_status[1] <= |bgo_shift;
        led_status[2] <= |tof_shift;
        led_status[3] <= |event_count;
    end

    // (full implementation: JESD204C ADC capture pipeline (×8 IP),
    // DDR4 burst-write circular buffer, Vivado XDMA for PCIe Gen4 ×16,
    // Watt-balance LTC2387 24-bit serial RX, NIM/CAMAC trigger gating,
    // event-tagged DMA descriptors — Phase D)

endmodule
