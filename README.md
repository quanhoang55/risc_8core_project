# Mô Phỏng CPU RISC-V 8 Lõi Với Pipeline 5 Tầng

Đây là đồ án mô phỏng một hệ thống CPU RISC-V 8 lõi ở mức RTL bằng Verilog. Phiên bản hiện tại đã chuyển lõi xử lý từ mô hình multi-cycle sang kiến trúc pipeline 5 tầng:

```text
IF -> ID -> EX -> MEM -> WB
```

Hệ thống dùng 8 lõi pipeline chạy song song, mỗi lõi có bộ nhớ lệnh riêng và cùng truy cập một bộ nhớ dữ liệu dùng chung thông qua `bus_ctrl` và `arbiter` Round-Robin.

## Thành Viên

- Hoàng Anh Quân, 202418969
- Trương Tùng Dương, 202418885
- Nguyễn Minh Hoàng, 202418904
- Bùi Thị Mai Linh, 20227240

## Trạng Thái Hiện Tại

Hệ thống hiện đã hoàn thành ở mức mô phỏng đồ án Kiến trúc máy tính:

- Mô phỏng được CPU RISC-V 8 lõi.
- Mỗi lõi là một core pipeline 5 tầng.
- Có các thanh ghi pipeline: `if_id`, `id_ex`, `ex_mem`, `mem_wb`.
- Có xử lý hazard cơ bản: forwarding, load-use stall, branch/jump flush.
- Có bộ nhớ lệnh riêng cho từng core.
- Có bộ nhớ dữ liệu dùng chung 4 KB.
- Có `bus_ctrl` và `arbiter` Round-Robin để điều phối truy cập RAM.
- Có testbench cho một core và cho toàn hệ thống 8 core.
- Có file waveform `.vcd` để xem trên GTKWave.

Kết quả mô phỏng gần nhất:

```text
core_tb:
SUMMARY: 7 PASSED, 0 FAILED

system_tb:
TONG KET: 10 PASSED, 0 FAILED
```

## Kiến Trúc Tổng Thể

```text
              +-------------+
Core 0 -----> |             |
Core 1 -----> |             |
Core 2 -----> |             |
Core 3 -----> |             |
Core 4 -----> |  bus_ctrl   | ----> data_mem
Core 5 -----> |             |
Core 6 -----> |             |
Core 7 -----> |             |
              +-------------+
                     ^
                     |
                +---------+
                | arbiter |
                +---------+
```

Các khối chính:

- `top_8core`: module top-level, khởi tạo 8 core pipeline và các khối liên kết.
- `risc_core`: lõi CPU RISC-V pipeline 5 tầng.
- `instr_mem`: bộ nhớ lệnh riêng cho mỗi core.
- `data_mem`: RAM dữ liệu dùng chung.
- `bus_ctrl`: điều khiển giao dịch giữa core và RAM.
- `arbiter`: cấp quyền truy cập bus theo Round-Robin.
- `control_unit`: giải mã lệnh RISC-V và tạo tín hiệu điều khiển.
- `reg_file`: 32 thanh ghi 32-bit, trong đó `x0` luôn bằng 0.
- `alu`: thực hiện các phép toán số học và logic.

## Pipeline 5 Tầng

Mỗi `risc_core` được chia thành 5 tầng:

```text
IF  -> ID  -> EX  -> MEM -> WB
Fetch Decode ALU   Bus    Writeback
```

Ý nghĩa từng tầng:

- `IF`: lấy lệnh từ instruction memory theo địa chỉ PC.
- `ID`: giải mã lệnh, đọc register file, tạo immediate và control signals.
- `EX`: thực hiện ALU, tính địa chỉ bộ nhớ, xử lý branch/jump.
- `MEM`: truy cập shared data memory thông qua bus.
- `WB`: ghi kết quả về register file.

Các cơ chế pipeline đã có:

- Forwarding từ `EX/MEM` và `MEM/WB` về tầng `EX`.
- Writeback bypass trong `reg_file` để xử lý phụ thuộc WB-to-ID.
- Load-use stall khi lệnh sau cần dữ liệu vừa load.
- Flush khi branch/jump đổi PC.
- Stall ở tầng `MEM` khi core phải chờ bus hoặc chờ `mem_ready`.

## Tập Lệnh Hỗ Trợ

Hệ thống hỗ trợ một tập con của RV32I:

- R-type: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SLT`.
- I-type: `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLLI`, `SRLI`.
- Load/store: `LW`, `SW`.
- Branch: `BEQ`, `BNE`, `BLT`, `BGE`.
- Jump: `JAL`, `JALR`.
- U-type: `LUI`, `AUIPC`.
- Atomic: có đường tín hiệu và logic bus cho `LR`, `SC`, `AMO`, nhưng phần kiểm thử atomic đầy đủ nên được xem là hướng mở rộng nếu báo cáo không demo riêng.

## Cấu Trúc Thư Mục

```text
risc_8core_project/
├── rtl/
│   ├── core/
│   │   ├── alu.v
│   │   ├── control_unit.v
│   │   ├── reg_file.v
│   │   ├── pc_logic.v
│   │   └── risc_core.v
│   ├── interconnect/
│   │   ├── arbiter.v
│   │   └── bus_ctrl.v
│   ├── memory/
│   │   ├── instr_mem.v
│   │   └── data_mem.v
│   └── top_8core.v
├── software/
│   ├── program.asm
│   ├── program.hex
│   ├── system_program.asm
│   └── system_program.hex
├── tb/
│   ├── core_tb.v
│   ├── system_tb.v
│   ├── alu_tb.v
│   ├── interconnect_tb.v
│   └── pc_logic_tb.v
├── docs/
│   └── pipeline_evidence.md
├── scripts/
│   ├── compile.bat
│   └── compile.sh
├── huong_dan.md
└── README.md
```

## Chương Trình Test 8 Core

Chương trình hệ thống nằm ở:

- `software/system_program.asm`
- `software/system_program.hex`

Assembly:

```asm
addi x1, x0, 42
sw   x1, 0(x0)
lw   x2, 0(x0)
addi x3, x0, 99
sw   x3, 4(x0)
jal  x0, halt
```

Ý nghĩa:

- Mỗi core ghi `42` vào `mem[0]`.
- Mỗi core đọc lại `mem[0]`.
- Mỗi core ghi marker `99` vào `mem[1]`.
- Nếu cuối mô phỏng `mem[0] = 42` và `mem[1] = 99`, hệ thống chạy đúng và không deadlock.

## Cách Chạy Mô Phỏng

### Chạy full system 8 core

Từ thư mục gốc:

```bash
iverilog -g2012 -o tb/system_test.vvp \
  -I rtl/core -I rtl/interconnect -I rtl/memory \
  rtl/core/alu.v \
  rtl/core/control_unit.v \
  rtl/core/pc_logic.v \
  rtl/core/reg_file.v \
  rtl/core/risc_core.v \
  rtl/memory/data_mem.v \
  rtl/memory/instr_mem.v \
  rtl/interconnect/arbiter.v \
  rtl/interconnect/bus_ctrl.v \
  rtl/top_8core.v \
  tb/system_tb.v

cd tb
vvp system_test.vvp
```

Kết quả mong đợi:

```text
BAT DAU MO PHONG HE THONG 8 LOI PIPELINE
Kiem tra mem[0] (Ky vong: 42) = 42
[PASS] Shared memory data dung.
Kiem tra mem[1] addr 4 (Ky vong: 99) = 99
[PASS] 8 core hoan thanh chuong trinh khong deadlock.

PIPELINE / BUS EVIDENCE
Core 0: grant=... retired=... mem_stall=... load_use_stall=... flush=...
...
TONG KET: 10 PASSED, 0 FAILED
```

### Chạy test một core

Từ thư mục gốc:

```bash
iverilog -g2012 -o tb/core_test.vvp \
  -I rtl/core -I rtl/memory \
  rtl/core/alu.v \
  rtl/core/control_unit.v \
  rtl/core/reg_file.v \
  rtl/core/risc_core.v \
  rtl/memory/data_mem.v \
  rtl/memory/instr_mem.v \
  tb/core_tb.v

cd tb
vvp core_test.vvp
```

Kết quả mong đợi:

```text
PIPELINE EVIDENCE
retired=67 mem_stall=4 load_use_stall=1 flush=62
SUMMARY: 7 PASSED, 0 FAILED
```

### Chạy bằng script

Trên Linux, macOS, Git Bash hoặc MSYS:

```bash
./scripts/compile.sh
```

Trên Windows CMD/PowerShell:

```powershell
.\scripts\compile.bat
```

## Xem Waveform

Sau khi chạy testbench, các file waveform được sinh ra:

```text
tb/core_tb.vcd
tb/system_tb.vcd
```

Mở bằng GTKWave:

```bash
gtkwave tb/system_tb.vcd
```

Các tín hiệu nên quan sát:

- `clk`, `reset`
- `pc`
- `if_id_valid`, `id_ex_valid`, `ex_mem_valid`, `mem_wb_valid`
- `mem_req`, `mem_ready`, `mem_addr`, `mem_we`, `mem_re`
- `grant`, `grant_id`
- `retired_count`
- `mem_stall_count`
- `load_use_stall_count`
- `flush_count`

## Bằng Chứng Cho Báo Cáo Và Slide

Các điểm nên đưa vào slide:

- Core đã có pipeline register `if_id`, `id_ex`, `ex_mem`, `mem_wb`.
- Test một core cho thấy có `retired`, `load_use_stall`, `flush`.
- Test 8 core cho thấy tất cả core đều có `grant > 0` và `retired > 0`.
- RAM cuối mô phỏng có `mem[0] = 42`, `mem[1] = 99`.
- Full-system test kết thúc với `10 PASSED, 0 FAILED`.

Tài liệu chi tiết hơn nằm ở:

- `huong_dan.md`
- `docs/pipeline_evidence.md`

## Hạn Chế Và Hướng Phát Triển

Hạn chế hiện tại:

- Chưa có cache.
- Chưa có cache coherence.
- Chưa có interrupt/exception/CSR đầy đủ.
- Chưa hỗ trợ toàn bộ RISC-V ISA.
- Chưa có assembler tự động từ `.asm` sang `.hex`.
- Atomic `LR/SC/AMO` chưa có bộ test đầy đủ ở mức báo cáo chính.

Hướng phát triển:

- Thêm cache L1 cho từng core.
- Nghiên cứu cache coherence.
- Hoàn thiện kiểm thử atomic.
- Mở rộng tập lệnh.
- Viết assembler nhỏ cho subset đang hỗ trợ.
- Tối ưu pipeline để giảm stall/flush.

## Kết Luận

Dự án đã mô phỏng thành công một hệ thống CPU RISC-V 8 lõi theo kiến trúc pipeline 5 tầng. Hệ thống thể hiện được các nguyên lý quan trọng của môn Kiến trúc máy tính: datapath, control unit, register file, ALU, pipeline, hazard handling, shared memory, bus arbitration và mô phỏng RTL bằng Verilog.
