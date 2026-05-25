# Pipeline Simulation Evidence

This project now uses a 5-stage pipelined `risc_core` behind the same 8-core
top-level bus interface.

## Pipeline Stages

```text
IF  -> ID  -> EX  -> MEM -> WB
fetch decode ALU   bus    regfile
```

- `IF`: reads the per-core instruction memory using `pc`.
- `ID`: decodes the instruction and reads the register file.
- `EX`: runs the ALU, branch/jump decision, and forwarding.
- `MEM`: holds the shared bus transaction until `mem_ready`.
- `WB`: commits the result to the register file.

Implemented pipeline controls:

- EX/MEM and MEM/WB forwarding for ALU dependencies.
- Register-file writeback bypass for WB-to-ID dependencies.
- Load-use stall detection.
- Branch/jump flush from the EX stage.
- Shared-memory structural stall while a core waits for `mem_ready`.

## 8-Core Evidence

Run from the repository root:

```powershell
iverilog -g2012 -o tb\system_test.vvp -I rtl\core -I rtl\interconnect -I rtl\memory rtl\core\alu.v rtl\core\control_unit.v rtl\core\pc_logic.v rtl\core\reg_file.v rtl\core\risc_core.v rtl\memory\data_mem.v rtl\memory\instr_mem.v rtl\interconnect\arbiter.v rtl\interconnect\bus_ctrl.v rtl\top_8core.v tb\system_tb.v
cd tb
vvp system_test.vvp
```

Expected output excerpt:

```text
BAT DAU MO PHONG HE THONG 8 LOI PIPELINE
Kiem tra mem[0] (Ky vong: 42) = 42
[PASS] Shared memory data dung.
Kiem tra mem[1] addr 4 (Ky vong: 99) = 99
[PASS] 8 core hoan thanh chuong trinh khong deadlock.

PIPELINE / BUS EVIDENCE
Core 0: grant=3 retired=... mem_stall=... load_use_stall=... flush=...
...
TONG KET: 10 PASSED, 0 FAILED
```

The `grant` column proves each core accessed the shared bus. The `retired`,
`mem_stall`, `load_use_stall`, and `flush` counters are internal pipeline
counters dumped into `tb/system_tb.vcd` for waveform screenshots.

## Single-Core Evidence

Run:

```powershell
iverilog -g2012 -o tb\core_test.vvp -I rtl\core -I rtl\memory rtl\core\alu.v rtl\core\control_unit.v rtl\core\reg_file.v rtl\core\risc_core.v rtl\memory\data_mem.v rtl\memory\instr_mem.v tb\core_tb.v
cd tb
vvp core_test.vvp
```

Expected result:

```text
PIPELINE EVIDENCE
retired=67 mem_stall=4 load_use_stall=1 flush=62
SUMMARY: 7 PASSED, 0 FAILED
```

This checks ALU execution, store/load, load-use branch behavior, and jump flush.

## Slide Talking Points

- The old `risc_core` FSM was replaced by pipeline registers: `if_id`,
  `id_ex`, `ex_mem`, and `mem_wb`.
- The 8-core top-level did not need a bus-interface redesign because the
  pipelined core preserves the original memory request protocol.
- Hazards are visible in waveform through `load_use_stall_count`,
  `mem_stall_count`, and `flush_count`.
- The full-system simulation still passes shared-memory checks after the
  architecture change.
