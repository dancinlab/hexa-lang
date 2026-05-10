// firmware/hdl/cyclotron_trigger.v — placeholder (PET cyclotron board is MCU-only)
//
// HEXA-PET-FW-01 has no FPGA — it's STM32H743-based.  See
// firmware/mcu/pet_cyclotron.rs for the controller logic.
//
// This file exists as a Phase D inventory placeholder so that all 4
// boards have a parallel `firmware/hdl/<board>.v` slot if a future
// revision adds an FPGA companion (e.g., for high-speed NaI counting
// at > 100 MHz event rate that exceeds STM32 EXTI throughput).

`timescale 1ns / 1ps

module cyclotron_trigger_placeholder (
    input  wire clk,
    output reg  led_idle
);
    always @(posedge clk) led_idle <= 1'b1;
    // (no-op; see firmware/mcu/pet_cyclotron.rs for real implementation)
endmodule
