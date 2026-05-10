// hexa-rtsc/firmware/hdl/calorimetry_daq.v
// Calorimetry rig FPGA — heat-pulse DAC + 24-bit ADC streaming
// (§A.6.1 Stage D+ deliverable per .roadmap.hexa_rtsc)
//
// Spec   : doc/calorimetry_rig_v0.md (Stage A)
// Sim    : firmware/sim/calorimetry_ctrl.hexa (Stage D+ companion)
// Target : Xilinx Artix-7 XC7A35T-1CSG324C, 50 MHz system clock
//          (slow on purpose — 24-bit ΣΔ ADC oversampling at 16 kHz)
// Tool   : Vivado 2024.2 (verified-compile path)
//
// Pipeline:
//   1. heat-pulse DAC (16-bit, AD5660 SPI) — programmable pulse height + width
//   2. Pt-RTD 4-wire excitation + 24-bit ΣΔ ADC (LTC2400) → T(t) trace
//   3. Streaming output via UART (FT232H USB-serial) at 1 Mbaud
//   4. n=6 anchor: pulse width = τ(6) ms = 4 ms baseline
//
// Honesty: skeleton only. Verified-compile via:
//   iverilog -o tb_cal tb_calorimetry_daq.v calorimetry_daq.v   (TBD)
//   vivado -mode batch -source build.tcl                         (TBD)

`timescale 1ns / 1ps
`default_nettype none

module calorimetry_daq #(
    // 16 kHz oversampling; ΣΔ decimation 256 → 62.5 Hz output rate
    parameter integer ADC_OVERSAMPLE = 256,
    // Heat pulse default width (ms; matches τ(6)=4 anchor)
    parameter integer HEAT_PULSE_MS_DEFAULT = 4,
    // 50 MHz / 50,000 = 1 kHz tick base; HEAT_PULSE_MS uses this
    parameter integer CLK_HZ = 50_000_000
)(
    input  wire        clk_50mhz_i,
    input  wire        rst_n_i,

    // Host control (8-bit register interface, e.g. UART command)
    input  wire        cmd_pulse_start_i,    // pulse-start trigger
    input  wire [15:0] cmd_pulse_height_i,   // DAC code 0..65535
    input  wire [15:0] cmd_pulse_width_ms_i, // 1..1000 ms

    // Heat-pulse DAC SPI (AD5660 16-bit)
    output reg         dac_sclk_o,
    output reg         dac_sync_n_o,
    output reg         dac_sdi_o,

    // 24-bit ΣΔ ADC SPI (LTC2400 — actually returns 24-bit data after conversion)
    output reg         adc_cs_n_o,
    output reg         adc_sclk_o,
    input  wire        adc_sdo_i,            // also serves as conversion-done /CS

    // Streaming output (UART TX via FT232H bridge — 1 Mbaud)
    output reg         uart_tx_o,

    // Status
    output reg         pulse_active_o,
    output reg [23:0]  last_adc_sample_o,
    output reg         adc_valid_o
);

// ─── tick generator (1 kHz from 50 MHz) ─────────────────────────────────

reg [15:0] tick_div;
reg        tick_1khz;

always @(posedge clk_50mhz_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        tick_div  <= 16'd0;
        tick_1khz <= 1'b0;
    end else if (tick_div == 16'd49999) begin
        tick_div  <= 16'd0;
        tick_1khz <= 1'b1;
    end else begin
        tick_div  <= tick_div + 16'd1;
        tick_1khz <= 1'b0;
    end
end

// ─── pulse-width counter ────────────────────────────────────────────────

reg [15:0] pulse_remaining_ms;

always @(posedge clk_50mhz_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        pulse_active_o     <= 1'b0;
        pulse_remaining_ms <= 16'd0;
    end else if (cmd_pulse_start_i && !pulse_active_o) begin
        pulse_active_o     <= 1'b1;
        pulse_remaining_ms <= cmd_pulse_width_ms_i;
    end else if (pulse_active_o && tick_1khz) begin
        if (pulse_remaining_ms <= 16'd1) begin
            pulse_active_o     <= 1'b0;
            pulse_remaining_ms <= 16'd0;
        end else begin
            pulse_remaining_ms <= pulse_remaining_ms - 16'd1;
        end
    end
end

// ─── DAC SPI driver (AD5660 — 24-bit shift, MSB first) ──────────────────
// Simplified: shift 24 bits whenever pulse_active_o transitions or starts.

reg [23:0] dac_shift;
reg [4:0]  dac_bit_count;
reg [1:0]  dac_state;
localparam DAC_IDLE = 2'd0, DAC_LOAD = 2'd1, DAC_SHIFT = 2'd2;

always @(posedge clk_50mhz_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        dac_state     <= DAC_IDLE;
        dac_sclk_o    <= 1'b0;
        dac_sync_n_o  <= 1'b1;
        dac_sdi_o     <= 1'b0;
        dac_bit_count <= 5'd0;
    end else case (dac_state)
        DAC_IDLE: begin
            dac_sync_n_o <= 1'b1;
            dac_sclk_o   <= 1'b0;
            if (cmd_pulse_start_i || (pulse_active_o == 1'b0 && pulse_remaining_ms == 16'd1)) begin
                // load DAC code at pulse-start (height) or pulse-end (zero)
                dac_shift <= pulse_active_o ? {8'h00, cmd_pulse_height_i} : 24'h000000;
                dac_state <= DAC_LOAD;
            end
        end
        DAC_LOAD: begin
            dac_sync_n_o  <= 1'b0;
            dac_bit_count <= 5'd24;
            dac_state     <= DAC_SHIFT;
        end
        DAC_SHIFT: begin
            dac_sclk_o <= ~dac_sclk_o;
            if (dac_sclk_o) begin   // negedge: shift
                dac_sdi_o  <= dac_shift[23];
                dac_shift  <= {dac_shift[22:0], 1'b0};
                dac_bit_count <= dac_bit_count - 5'd1;
                if (dac_bit_count == 5'd1) dac_state <= DAC_IDLE;
            end
        end
    endcase
end

// ─── ADC SPI driver (LTC2400 — 24-bit conversion + readout) ────────────
// LTC2400 takes ~133 ms per conversion; we trigger every 16 ms and
// stream when /CS goes low (= conversion complete).

reg [23:0] adc_shift;
reg [4:0]  adc_bit_count;
reg [1:0]  adc_state;
localparam ADC_IDLE = 2'd0, ADC_TRIGGER = 2'd1, ADC_WAIT = 2'd2, ADC_READ = 2'd3;

reg [3:0] adc_tick_count;

always @(posedge clk_50mhz_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        adc_state         <= ADC_IDLE;
        adc_cs_n_o        <= 1'b1;
        adc_sclk_o        <= 1'b0;
        adc_bit_count     <= 5'd0;
        last_adc_sample_o <= 24'd0;
        adc_valid_o       <= 1'b0;
        adc_tick_count    <= 4'd0;
    end else case (adc_state)
        ADC_IDLE: begin
            adc_cs_n_o  <= 1'b1;
            adc_valid_o <= 1'b0;
            if (tick_1khz) begin
                if (adc_tick_count == 4'd15) begin   // 16 ms
                    adc_tick_count <= 4'd0;
                    adc_state      <= ADC_TRIGGER;
                end else begin
                    adc_tick_count <= adc_tick_count + 4'd1;
                end
            end
        end
        ADC_TRIGGER: begin
            adc_cs_n_o <= 1'b0;
            adc_state  <= ADC_WAIT;
        end
        ADC_WAIT: begin
            // Wait for SDO to go low = conversion done
            if (adc_sdo_i == 1'b0) begin
                adc_bit_count <= 5'd24;
                adc_state     <= ADC_READ;
                adc_shift     <= 24'd0;
            end
        end
        ADC_READ: begin
            adc_sclk_o <= ~adc_sclk_o;
            if (adc_sclk_o) begin   // negedge: sample SDO
                adc_shift     <= {adc_shift[22:0], adc_sdo_i};
                adc_bit_count <= adc_bit_count - 5'd1;
                if (adc_bit_count == 5'd1) begin
                    last_adc_sample_o <= {adc_shift[22:0], adc_sdo_i};
                    adc_valid_o       <= 1'b1;
                    adc_state         <= ADC_IDLE;
                end
            end
        end
    endcase
end

// ─── UART TX (1 Mbaud, 8N1) — sends ADC sample on each adc_valid_o ─────
// Simplified: TX engine omitted; placeholder always-1 (idle).
// Real implementation: 24-bit sample → 3 bytes → 30 bit-times @ 50 MHz/50.

always @(posedge clk_50mhz_i or negedge rst_n_i) begin
    if (!rst_n_i) uart_tx_o <= 1'b1;
    else          uart_tx_o <= 1'b1;   // TX engine TBD
end

endmodule

`default_nettype wire
