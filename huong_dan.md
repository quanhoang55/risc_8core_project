# Hướng Dẫn Trình Bày Hệ Thống Mô Phỏng CPU RISC-V 8 Core Pipeline 5 Tầng

Tài liệu này dùng để giúp nhóm trình bày với thầy từ A đến Z: hệ thống đã làm được gì, cơ sở lý thuyết là gì, kiến trúc chạy ra sao, cách mô phỏng thế nào, và nên viết báo cáo theo bố cục nào.

## 1. Hệ Thống Đã Hoàn Thành Chưa?

Có. Ở mức độ đồ án môn Kiến trúc máy tính, hệ thống đã hoàn thành mô phỏng CPU RISC-V 8 core theo kiến trúc pipeline 5 tầng.

Bằng chứng trong project:

- `rtl/core/risc_core.v` là core RISC-V pipeline 5 tầng.
- Core có các pipeline register: `if_id`, `id_ex`, `ex_mem`, `mem_wb`.
- `rtl/top_8core.v` khởi tạo 8 core pipeline.
- 8 core dùng chung `data_mem` thông qua `bus_ctrl` và `arbiter`.
- `tb/core_tb.v` kiểm tra một core pipeline.
- `tb/system_tb.v` kiểm tra toàn hệ thống 8 core.
- Testbench in ra các counter chứng minh pipeline và bus hoạt động.
- Có waveform `.vcd` để xem trên GTKWave.

Kết quả mong đợi:

```text
core_tb:
SUMMARY: 7 PASSED, 0 FAILED

system_tb:
TONG KET: 10 PASSED, 0 FAILED
```

Cách nói ngắn gọn:

"Hệ thống đã mô phỏng thành công CPU RISC-V 8 lõi. Mỗi lõi là một pipeline 5 tầng, các lõi cùng truy cập bộ nhớ dữ liệu dùng chung thông qua bus controller và arbiter Round-Robin. Kết quả mô phỏng cho thấy 8 core đều chạy, đều truy cập bus, ghi/đọc RAM đúng và không bị deadlock."

Ghi chú trung thực:

Đây là mô hình RTL phục vụ học tập, chưa phải CPU công nghiệp. Hệ thống chưa có cache, cache coherence, interrupt/exception/CSR đầy đủ, hệ điều hành, hoặc hỗ trợ toàn bộ RISC-V ISA.

## 2. Mục Tiêu Đề Tài

Mục tiêu chính:

- Thiết kế một hệ thống CPU RISC-V 8 core bằng Verilog.
- Chuyển lõi xử lý từ multi-cycle sang pipeline 5 tầng.
- Mỗi core thực thi chương trình RISC-V đơn giản.
- 8 core cùng dùng chung một bộ nhớ dữ liệu.
- Điều phối tranh chấp RAM bằng arbiter Round-Robin.
- Mô phỏng bằng Icarus Verilog.
- Xuất waveform `.vcd` để quan sát bằng GTKWave.
- Có bằng chứng terminal và waveform để đưa vào báo cáo/slide.

Các câu hỏi báo cáo cần trả lời:

- RISC-V là gì?
- Pipeline 5 tầng hoạt động như thế nào?
- Một lệnh đi qua các tầng pipeline ra sao?
- Hazard trong pipeline là gì?
- Forwarding, stall và flush dùng để làm gì?
- 8 core tranh chấp RAM dùng chung như thế nào?
- Arbiter Round-Robin cấp quyền bus ra sao?
- Kết quả mô phỏng chứng minh điều gì?

## 3. Tổng Quan Kiến Trúc Hệ Thống

Sơ đồ mức cao:

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

Ý tưởng chính:

- Hệ thống có 8 core pipeline.
- Mỗi core có instruction memory riêng.
- Tất cả core dùng chung data memory.
- Khi nhiều core muốn truy cập RAM cùng lúc, arbiter sẽ chọn một core được phục vụ.
- Bus controller đưa giao dịch của core được chọn vào data memory và trả `mem_ready`.

Các file quan trọng:

| File | Vai trò |
|---|---|
| `rtl/top_8core.v` | Ghép 8 core với bus, arbiter và RAM |
| `rtl/core/risc_core.v` | Core RISC-V pipeline 5 tầng |
| `rtl/core/control_unit.v` | Giải mã lệnh RISC-V |
| `rtl/core/alu.v` | Khối tính toán số học/logic |
| `rtl/core/reg_file.v` | 32 thanh ghi RISC-V |
| `rtl/memory/instr_mem.v` | Bộ nhớ lệnh riêng cho từng core |
| `rtl/memory/data_mem.v` | RAM dữ liệu dùng chung |
| `rtl/interconnect/arbiter.v` | Cấp quyền bus Round-Robin |
| `rtl/interconnect/bus_ctrl.v` | Điều khiển giao dịch core-RAM |
| `tb/core_tb.v` | Test một core |
| `tb/system_tb.v` | Test toàn hệ thống 8 core |

## 4. Cơ Sở Lý Thuyết RISC-V

RISC-V là một kiến trúc tập lệnh mở theo triết lý RISC.

Đặc điểm chính:

- Lệnh đơn giản, dễ giải mã.
- Kiến trúc load/store: chỉ `LW`, `SW` truy cập bộ nhớ.
- Các phép toán ALU làm việc chủ yếu trên thanh ghi.
- Có 32 thanh ghi tổng quát `x0` đến `x31`.
- Thanh ghi `x0` luôn bằng 0.
- Lệnh cơ bản có độ dài 32 bit.

Trong project này, CPU hỗ trợ một tập con của RV32I:

- R-type: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SLT`.
- I-type: `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLLI`, `SRLI`.
- Memory: `LW`, `SW`.
- Branch: `BEQ`, `BNE`, `BLT`, `BGE`.
- Jump: `JAL`, `JALR`.
- U-type: `LUI`, `AUIPC`.

Nên nói rõ trong báo cáo:

"Project hỗ trợ một tập con của RV32I đủ để minh họa datapath, control, pipeline, memory access và branch/jump. Đây chưa phải bộ xử lý RISC-V đầy đủ theo chuẩn công nghiệp."

## 5. Pipeline 5 Tầng

Pipeline chia quá trình thực thi lệnh thành nhiều tầng. Thay vì đợi một lệnh chạy xong hoàn toàn mới chạy lệnh tiếp theo, pipeline cho phép nhiều lệnh cùng tồn tại trong CPU ở các tầng khác nhau.

Năm tầng trong hệ thống:

```text
IF  -> ID  -> EX  -> MEM -> WB
```

Ý nghĩa:

- `IF` - Instruction Fetch: lấy lệnh từ instruction memory theo PC.
- `ID` - Instruction Decode: giải mã lệnh, đọc register file, tạo immediate.
- `EX` - Execute: ALU tính toán, xử lý branch/jump, tính địa chỉ memory.
- `MEM` - Memory Access: đọc/ghi data memory qua bus.
- `WB` - Write Back: ghi kết quả về register file.

Ví dụ với lệnh:

```asm
addi x1, x0, 42
```

Luồng hoạt động:

```text
IF  : lấy mã lệnh addi
ID  : giải mã, đọc x0, tạo immediate = 42
EX  : ALU tính x0 + 42
MEM : không truy cập RAM
WB  : ghi 42 vào x1
```

Ví dụ với lệnh:

```asm
sw x1, 0(x0)
```

Luồng hoạt động:

```text
IF  : lấy mã lệnh sw
ID  : đọc x1 và x0, tạo immediate = 0
EX  : tính địa chỉ x0 + 0
MEM : gửi request ghi RAM qua bus
WB  : không ghi thanh ghi
```

## 6. Hazard Trong Pipeline

Pipeline giúp tăng thông lượng nhưng tạo ra hazard. Đây là phần nên trình bày kỹ, vì nó chứng minh nhóm hiểu bản chất pipeline chứ không chỉ đổi tên module.

### 6.1. Data Hazard

Data hazard xảy ra khi một lệnh cần dùng kết quả của lệnh trước, nhưng kết quả đó chưa kịp ghi về register file.

Ví dụ:

```asm
addi x1, x0, 10
add  x3, x1, x2
```

Lệnh `add` cần giá trị mới của `x1`, nhưng lệnh `addi` có thể chưa đến tầng `WB`.

Cách xử lý trong hệ thống:

- Forwarding từ `EX/MEM` về `EX`.
- Forwarding từ `MEM/WB` về `EX`.
- Writeback bypass trong `reg_file`.

### 6.2. Load-Use Hazard

Load-use hazard xảy ra khi lệnh ngay sau `LW` dùng thanh ghi vừa load.

Ví dụ trong `software/program.asm`:

```asm
lw   x4, 0(x0)
beq  x3, x4, pass
```

Dữ liệu của `x4` chỉ có sau khi load từ memory, nên pipeline phải chèn stall.

Bằng chứng khi chạy `core_tb`:

```text
load_use_stall=1
```

### 6.3. Control Hazard

Control hazard xảy ra với branch hoặc jump. CPU có thể đã fetch lệnh tiếp theo trước khi biết nhánh có được lấy hay không.

Cách xử lý:

- Branch/jump được quyết định ở tầng `EX`.
- Nếu PC đổi, pipeline flush các lệnh sai đường.

Bằng chứng:

```text
flush=62
```

### 6.4. Structural Hazard

Structural hazard xảy ra khi nhiều thành phần cần dùng cùng một tài nguyên.

Trong hệ thống này:

- 8 core cùng dùng chung `data_mem`.
- RAM chỉ phục vụ một giao dịch tại một thời điểm.
- Core chưa được phục vụ sẽ phải chờ ở tầng `MEM`.

Cách xử lý:

- `arbiter` chọn core được cấp bus.
- `bus_ctrl` đưa giao dịch của core đó vào RAM.
- Các core còn lại tiếp tục giữ request và stall.

Bằng chứng:

```text
mem_stall > 0
grant > 0 cho từng core
```

## 7. Luồng Hoạt Động Từ A Đến Z

### 7.1. Khi Reset

Khi `reset = 1`:

- PC của mỗi core về 0.
- Các pipeline register bị xóa.
- Register file được reset.
- Data memory được reset.
- Arbiter và bus controller về trạng thái ban đầu.

Khi `reset = 0`, 8 core bắt đầu fetch lệnh từ địa chỉ 0.

### 7.2. Một Lệnh Đi Qua Core

Luồng đi của một lệnh:

```text
PC
-> instr_mem
-> IF/ID
-> control_unit + reg_file
-> ID/EX
-> ALU hoặc branch logic
-> EX/MEM
-> data_mem nếu là load/store
-> MEM/WB
-> reg_file
```

Trong `risc_core.v`, các thanh ghi pipeline tương ứng là:

- `if_id_valid`, `if_id_pc`, `if_id_instr`.
- `id_ex_valid`, `id_ex_rs1_data`, `id_ex_rs2_data`, `id_ex_imm`.
- `ex_mem_valid`, `ex_mem_result`, `ex_mem_store_data`.
- `mem_wb_valid`, `mem_wb_write_data`.

### 7.3. 8 Core Cùng Chạy

Trong `top_8core.v`, hệ thống tạo 8 instance:

```text
gen_core[0].u_core
gen_core[1].u_core
...
gen_core[7].u_core
```

Tất cả core chạy cùng chương trình:

```text
software/system_program.hex
```

Assembly tương ứng:

```asm
addi x1, x0, 42
sw   x1, 0(x0)
lw   x2, 0(x0)
addi x3, x0, 99
sw   x3, 4(x0)
jal  x0, halt
```

Ý nghĩa:

- Mỗi core tạo giá trị 42.
- Mỗi core ghi 42 vào `mem[0]`.
- Mỗi core đọc lại `mem[0]`.
- Mỗi core tạo marker 99.
- Mỗi core ghi 99 vào `mem[1]`.
- Cuối cùng core vào vòng lặp halt.

### 7.4. Core Truy Cập RAM

Khi core gặp `LW` hoặc `SW`, nó phát các tín hiệu:

```text
mem_req
mem_addr
mem_wdata
mem_we
mem_re
```

Luồng truy cập RAM:

```text
Core -> bus_ctrl -> arbiter -> data_mem -> bus_ctrl -> Core
```

Chi tiết:

1. Core bật `mem_req`.
2. `bus_ctrl` chuyển request sang `arbiter`.
3. `arbiter` chọn một core theo Round-Robin.
4. `bus_ctrl` đưa địa chỉ/dữ liệu của core được chọn vào `data_mem`.
5. `data_mem` đọc hoặc ghi.
6. `bus_ctrl` trả `core_ready[core_id]`.
7. Core tiếp tục pipeline.

## 8. Arbiter Round-Robin

Vì 8 core cùng truy cập shared memory, cần một bộ phân xử bus.

Round-Robin hoạt động như sau:

- Nếu nhiều core cùng request, arbiter chọn một core theo thứ tự xoay vòng.
- Sau khi cấp quyền cho core `i`, lần sau ưu tiên bắt đầu từ core `i + 1`.
- Cách này tránh việc một core chiếm bus mãi.

Trong output `system_tb`, cột `grant` cho biết mỗi core được cấp bus bao nhiêu lần.

Ví dụ:

```text
Core 0: grant=3 retired=163 mem_stall=13 load_use_stall=0 flush=159
Core 1: grant=3 retired=163 mem_stall=14 load_use_stall=0 flush=159
...
Core 7: grant=4 retired=161 mem_stall=20 load_use_stall=0 flush=157
```

Cách giải thích:

"Mỗi core đều có `grant > 0`, nghĩa là tất cả 8 core đều từng được cấp quyền truy cập shared memory. Hệ thống không bị starvation và không bị deadlock trong mô phỏng."

## 9. Quy Trình Chạy Mô Phỏng

### 9.1. Công Cụ

Cần có:

- Icarus Verilog: `iverilog`
- Runtime mô phỏng: `vvp`
- GTKWave nếu muốn xem waveform: `gtkwave`

Kiểm tra:

```bash
iverilog -V
vvp -V
gtkwave --version
```

### 9.2. Chạy Mô Phỏng 8 Core

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

Kết quả cần thấy:

```text
TONG KET: 10 PASSED, 0 FAILED
```

### 9.3. Chạy Mô Phỏng Một Core

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

Kết quả cần thấy:

```text
SUMMARY: 7 PASSED, 0 FAILED
```

### 9.4. Xem Waveform

Sau khi mô phỏng, có thể mở:

```bash
gtkwave tb/system_tb.vcd
```

Các tín hiệu nên chụp:

- `clk`, `reset`
- `pc`
- `if_id_valid`
- `id_ex_valid`
- `ex_mem_valid`
- `mem_wb_valid`
- `mem_req`
- `mem_ready`
- `grant`
- `grant_id`
- `retired_count`
- `mem_stall_count`
- `load_use_stall_count`
- `flush_count`

## 10. Cách Trình Bày Với Thầy

### Bước 1: Giới thiệu bài toán

"Nhóm em xây dựng hệ thống CPU RISC-V 8 lõi bằng Verilog. Mỗi lõi được phát triển thành pipeline 5 tầng. Các core chạy song song và cùng truy cập bộ nhớ dữ liệu dùng chung."

### Bước 2: Giới thiệu RISC-V

"RISC-V là kiến trúc load/store. Các phép toán ALU làm việc trên register, còn truy cập bộ nhớ thông qua `LW` và `SW`. Project hỗ trợ một subset của RV32I để minh họa datapath, control và pipeline."

### Bước 3: Giới thiệu pipeline

"Mỗi core có 5 tầng: IF, ID, EX, MEM, WB. Nhiều lệnh có thể cùng tồn tại trong pipeline ở các tầng khác nhau, giúp tăng thông lượng so với multi-cycle."

### Bước 4: Giải thích hazard

"Pipeline tạo ra data hazard, load-use hazard, control hazard và structural hazard. Nhóm xử lý bằng forwarding, writeback bypass, stall, flush và bus arbitration."

### Bước 5: Giải thích 8 core

"Top-level generate 8 instance của `risc_core`. Mỗi core có instruction memory riêng nhưng dùng chung data memory. Khi core cần RAM, nó gửi `mem_req`; arbiter chọn core được grant; bus controller đưa giao dịch vào RAM và trả `mem_ready`."

### Bước 6: Giải thích chương trình test

"Chương trình test cho mỗi core ghi 42 vào `mem[0]`, đọc lại, rồi ghi marker 99 vào `mem[1]`. Nếu cuối mô phỏng có `mem[0] = 42`, `mem[1] = 99`, hệ thống đã chạy đúng và không deadlock."

### Bước 7: Đưa bằng chứng

"Testbench in `TONG KET: 10 PASSED, 0 FAILED`. Mỗi core đều có `grant > 0` và `retired > 0`, chứng minh cả 8 core đều chạy và đều truy cập bus. Các counter `mem_stall`, `load_use_stall`, `flush` chứng minh pipeline có xử lý stall và flush."

## 11. Bố Cục Báo Cáo Gợi Ý

### Chương 1: Giới thiệu

- Lý do chọn đề tài.
- Mục tiêu mô phỏng CPU RISC-V 8 core.
- Phạm vi: RTL, pipeline 5 tầng, shared memory, arbiter.

### Chương 2: Cơ sở lý thuyết

- Tổng quan RISC-V.
- RV32I subset.
- Datapath CPU.
- Pipeline 5 tầng.
- Hazard trong pipeline.
- Shared memory và bus arbitration.

### Chương 3: Thiết kế hệ thống

- Sơ đồ top-level 8 core.
- Core pipeline.
- Register file, ALU, control unit.
- Instruction memory và data memory.
- Bus controller và arbiter.

### Chương 4: Thiết kế pipeline core

- Các pipeline register.
- Luồng đi của lệnh.
- Forwarding.
- Load-use stall.
- Branch/jump flush.
- Memory stall.

### Chương 5: Mô phỏng và kiểm thử

- Công cụ: Icarus Verilog, VVP, GTKWave.
- Test một core.
- Test full system 8 core.
- Kết quả pass/fail.
- Waveform minh họa.

### Chương 6: Đánh giá và hạn chế

Đã làm được:

- Mô phỏng CPU RISC-V 8 core.
- Chuyển core sang pipeline 5 tầng.
- Có forwarding, stall, flush.
- Có shared memory và arbiter.
- Có testbench và waveform.

Hạn chế:

- Chưa có cache.
- Chưa có cache coherence.
- Chưa có interrupt/exception/CSR đầy đủ.
- Chưa hỗ trợ toàn bộ RISC-V ISA.
- Chưa có assembler tự động từ `.asm` sang `.hex`.
- Atomic `LR/SC/AMO` chưa có bộ test đầy đủ trong demo chính.

### Chương 7: Kết luận

Kết luận gợi ý:

"Đề tài đã xây dựng và mô phỏng thành công hệ thống CPU RISC-V 8 lõi theo kiến trúc pipeline 5 tầng. Kết quả mô phỏng cho thấy các core có thể cùng thực thi chương trình, truy cập RAM dùng chung thông qua bus controller và arbiter, đồng thời pipeline có cơ chế xử lý hazard như forwarding, stall và flush."

## 12. Gợi Ý Slide

Slide 1: Tên đề tài.

Slide 2: Mục tiêu.

Slide 3: Tổng quan RISC-V.

Slide 4: Pipeline 5 tầng.

Slide 5: Datapath một core.

Slide 6: Hazard và cách xử lý.

Slide 7: Kiến trúc 8 core.

Slide 8: Bus controller và arbiter.

Slide 9: Chương trình test.

Slide 10: Kết quả mô phỏng.

Slide 11: Waveform và pipeline counters.

Slide 12: Hạn chế và hướng phát triển.

## 13. Câu Trả Lời Nhanh Khi Bị Hỏi

Hỏi: "Hệ thống là multi-cycle hay pipeline?"

Trả lời: "Phiên bản hiện tại là pipeline 5 tầng. Trong `risc_core.v` có các pipeline register `if_id`, `id_ex`, `ex_mem`, `mem_wb`."

Hỏi: "Bằng chứng pipeline hoạt động là gì?"

Trả lời: "Testbench in ra `retired`, `mem_stall`, `load_use_stall`, `flush`. Waveform cũng có các pipeline valid signal."

Hỏi: "8 core có thật sự chạy không?"

Trả lời: "Có. Trong `system_tb`, mỗi core đều có `grant > 0` và `retired > 0`, chứng minh từng core có thực thi lệnh và từng truy cập shared memory."

Hỏi: "Nếu 8 core cùng truy cập RAM thì xử lý thế nào?"

Trả lời: "Arbiter Round-Robin chọn một core được truy cập bus tại một thời điểm. Bus controller đưa giao dịch của core đó vào RAM và trả `mem_ready`."

Hỏi: "Tại sao `mem[0] = 42`, `mem[1] = 99` lại chứng minh chạy đúng?"

Trả lời: "Vì chương trình test bắt buộc mỗi core phải ghi 42, đọc lại, rồi ghi marker 99. Nếu RAM cuối mô phỏng đúng hai giá trị này và test không timeout, nghĩa là hệ thống chạy đúng qua đường memory và không deadlock."

## 14. Checklist Trước Khi Trình Bày

- Chạy `core_tb` và chụp `SUMMARY: 7 PASSED, 0 FAILED`.
- Chạy `system_tb` và chụp `TONG KET: 10 PASSED, 0 FAILED`.
- Chụp phần `PIPELINE / BUS EVIDENCE`.
- Mở `system_tb.vcd` bằng GTKWave.
- Chụp waveform có `pc`, pipeline valid, `mem_req`, `grant`, `mem_ready`.
- Đưa sơ đồ `IF -> ID -> EX -> MEM -> WB` vào slide.
- Đưa sơ đồ `8 cores -> bus_ctrl -> data_mem` vào slide.
- Nêu rõ hạn chế và hướng phát triển.

