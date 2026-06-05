# Bằng Chứng Mô Phỏng Pipeline

Tài liệu này ghi lại các bằng chứng cho thấy hệ thống hiện tại đã được chuyển từ lõi multi-cycle sang lõi RISC-V pipeline 5 tầng, đồng thời vẫn chạy được trong cấu hình 8 core.

## 1. Pipeline 5 Tầng

Lõi chính nằm ở:

```text
rtl/core/risc_core.v
```

Pipeline gồm 5 tầng:

```text
IF  -> ID  -> EX  -> MEM -> WB
Fetch Decode ALU   Bus    Writeback
```

Ý nghĩa:

- `IF`: lấy lệnh từ instruction memory theo địa chỉ `pc`.
- `ID`: giải mã lệnh, đọc register file, sinh immediate và tín hiệu điều khiển.
- `EX`: thực hiện ALU, forwarding, quyết định branch/jump.
- `MEM`: truy cập shared memory thông qua bus.
- `WB`: ghi kết quả về register file.

Các thanh ghi pipeline trong code:

- `if_id_*`: nối tầng IF và ID.
- `id_ex_*`: nối tầng ID và EX.
- `ex_mem_*`: nối tầng EX và MEM.
- `mem_wb_*`: nối tầng MEM và WB.

Đây là bằng chứng rõ nhất cho thấy core hiện tại không còn là FSM multi-cycle kiểu `FETCH -> EXECUTE -> MEMORY`, mà đã có pipeline register thật.

## 2. Cơ Chế Xử Lý Hazard

Các cơ chế đã triển khai:

- Forwarding từ `EX/MEM` và `MEM/WB` về tầng `EX`.
- Writeback bypass trong `reg_file` để xử lý phụ thuộc WB-to-ID.
- Load-use stall khi lệnh ngay sau `LW` cần dữ liệu vừa load.
- Flush khi branch hoặc jump đổi PC.
- Memory stall khi core phải chờ bus hoặc `mem_ready`.

Các counter debug dùng để chứng minh:

- `retired_count`: số lệnh đã đi qua pipeline.
- `mem_stall_count`: số chu kỳ chờ memory/bus.
- `load_use_stall_count`: số lần stall do load-use hazard.
- `flush_count`: số lần flush do branch/jump.

Các counter này được dump vào file `.vcd`, nên có thể chụp waveform trong GTKWave.

## 3. Chạy Test Một Core

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
CORE TEST RESULTS
x1 (expect 10) = 10
x2 (expect 20) = 20
x3 (expect 30) = 30
x4 (expect 30) = 30
x5 (expect 1)  = 1
mem[0] (expect 30) = 30

PIPELINE EVIDENCE
retired=67 mem_stall=4 load_use_stall=1 flush=62

SUMMARY: 7 PASSED, 0 FAILED
```

Ý nghĩa:

- Register và RAM đúng chứng minh core thực thi đúng các lệnh cơ bản.
- `load_use_stall=1` chứng minh pipeline có xử lý load-use hazard.
- `flush=62` chứng minh có cơ chế flush khi branch/jump.
- `retired=67` chứng minh có lệnh đi qua pipeline và được commit.

## 4. Chạy Test Full System 8 Core

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
Core 0: grant=3 retired=163 mem_stall=13 load_use_stall=0 flush=159
Core 1: grant=3 retired=163 mem_stall=14 load_use_stall=0 flush=159
Core 2: grant=3 retired=163 mem_stall=15 load_use_stall=0 flush=158
Core 3: grant=3 retired=162 mem_stall=16 load_use_stall=0 flush=158
Core 4: grant=3 retired=162 mem_stall=17 load_use_stall=0 flush=158
Core 5: grant=3 retired=162 mem_stall=18 load_use_stall=0 flush=157
Core 6: grant=4 retired=161 mem_stall=19 load_use_stall=0 flush=157
Core 7: grant=4 retired=161 mem_stall=20 load_use_stall=0 flush=157

TONG KET: 10 PASSED, 0 FAILED
```

Ý nghĩa:

- `mem[0] = 42`: các core đã ghi dữ liệu đúng vào shared memory.
- `mem[1] = 99`: các core đã đi tới marker hoàn thành.
- `grant > 0`: mỗi core đều từng được arbiter cấp quyền truy cập bus.
- `retired > 0`: mỗi core đều có lệnh được commit.
- `mem_stall > 0`: có hiện tượng chờ bus/memory, đúng với hệ thống shared memory.
- `flush > 0`: có branch/jump flush trong pipeline.

## 5. Tín Hiệu Nên Chụp Trong GTKWave

Mở waveform:

```bash
gtkwave tb/system_tb.vcd
```

Các tín hiệu nên đưa vào ảnh minh họa:

- `clk`, `reset`
- `dut.gen_core[0].u_core.pc`
- `if_id_valid`
- `id_ex_valid`
- `ex_mem_valid`
- `mem_wb_valid`
- `mem_req`
- `mem_ready`
- `mem_addr`
- `dut.u_arbiter.request`
- `dut.u_arbiter.grant`
- `dut.u_arbiter.grant_id`
- `retired_count`
- `mem_stall_count`
- `load_use_stall_count`
- `flush_count`

## 6. Câu Nói Gọn Khi Trình Bày

Có thể nói với thầy:

"Phiên bản hiện tại đã chuyển lõi `risc_core` sang pipeline 5 tầng. Bằng chứng trong RTL là các pipeline register `if_id`, `id_ex`, `ex_mem`, `mem_wb`. Bằng chứng khi mô phỏng là testbench in ra `retired`, `mem_stall`, `load_use_stall`, `flush`, đồng thời full-system 8 core vẫn pass với `mem[0] = 42`, `mem[1] = 99` và mỗi core đều có `grant > 0`."

