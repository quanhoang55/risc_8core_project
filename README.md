# Khung Báo Cáo Mô Phỏng CPU RISC-V 8 Lõi

* **Thành Viên:**
  - Hoàng Anh Quân, 202418969
  - Trương Tùng Dương, 202418885
  - Nguyễn Minh Hoàng, 202418904
  - Bùi Thị Mai Linh, 20227240

  ## 1. Giới Thiệu

Trình bày mục tiêu đề tài:

- Thiết kế và mô phỏng hệ thống CPU RISC-V 8 lõi bằng Verilog.
- Mỗi lõi có thể thực thi chương trình riêng trong instruction memory.
- Các lõi cùng truy cập data memory dùng chung thông qua bus controller và arbiter.
- Kiểm chứng hoạt động hệ thống bằng testbench và mô phỏng trên Icarus Verilog.

Nên nêu phạm vi rõ ràng:

- Đây là mô hình mô phỏng kiến trúc CPU đa lõi ở mức RTL.
- Tập lệnh hỗ trợ là một phần của RV32I, có thêm tín hiệu cho LR/SC/AMO.
- Mục tiêu chính là minh họa fetch, decode, execute, memory access, ghi thanh ghi và tranh chấp tài nguyên giữa 8 core.

## 2. Tổng Quan Kiến Trúc Hệ Thống

Trình bày sơ đồ tổng thể:

```text
              +-------------+
Core 0 -----> |             |
Core 1 -----> |             |
Core 2 -----> |             |
...           |  bus_ctrl   | ----> data_mem
Core 7 -----> |             |
              +-------------+
                     ^
                     |
                +---------+
                | arbiter |
                +---------+
```

Các khối chính:

- `top_8core`: module top-level, khởi tạo 8 core, arbiter, bus controller và RAM dùng chung.
- `risc_core`: một lõi CPU RISC-V đơn giản.
- `instr_mem`: bộ nhớ lệnh riêng cho từng core.
- `data_mem`: bộ nhớ dữ liệu dùng chung 4 KB.
- `arbiter`: cấp quyền truy cập bus theo Round-Robin.
- `bus_ctrl`: định tuyến request từ core đến RAM và trả tín hiệu hoàn tất.

Có thể dẫn file chính:

- [top_8core.v](C:/Users/X1%20Yoga/hust/ktmt/risc_8core_project/rtl/top_8core.v)
- [risc_core.v](C:/Users/X1%20Yoga/hust/ktmt/risc_8core_project/rtl/core/risc_core.v)
- [bus_ctrl.v](C:/Users/X1%20Yoga/hust/ktmt/risc_8core_project/rtl/interconnect/bus_ctrl.v)

## 3. Kiến Trúc Một Lõi CPU

Mỗi core gồm các khối:

- `pc_logic`: quản lý Program Counter.
- `instr_mem`: đọc lệnh theo địa chỉ PC.
- `control_unit`: giải mã opcode, tạo tín hiệu điều khiển.
- `reg_file`: 32 thanh ghi 32-bit, `x0 = 0`.
- `alu`: thực hiện phép toán số học/logic.
- Memory interface: gửi `mem_req`, `mem_addr`, `mem_we`, `mem_re`, nhận `mem_rdata`, `mem_ready`.

Quy trình chạy của một lệnh:

```text
FETCH -> EXECUTE -> MEMORY nếu là load/store
FETCH <- EXECUTE nếu là ALU/branch/jump
```

Chi tiết:

- `FETCH`: đọc instruction từ instruction memory, lưu vào `instr_reg`.
- `EXECUTE`: giải mã lệnh, đọc thanh ghi, tạo immediate, ALU xử lý.
- Với lệnh ALU: ghi kết quả vào register file.
- Với `LW`: tính địa chỉ, gửi request đọc RAM, chờ `mem_ready`, ghi dữ liệu vào `rd`.
- Với `SW`: tính địa chỉ, gửi request ghi RAM, chờ hoàn tất.
- Với branch/jump: cập nhật PC theo điều kiện.

## 4. Tập Lệnh Và Chức Năng Hỗ Trợ

Nêu các nhóm lệnh đã hỗ trợ:

- R-type: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SLT`.
- I-type: `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLLI`, `SRLI`.
- Load/store: `LW`, `SW`.
- Branch: `BEQ`, `BNE`, `BLT`, `BGE`.
- Jump: `JAL`, `JALR`.
- U-type: `LUI`, `AUIPC`.
- Atomic: có thiết kế tín hiệu cho `LR`, `SC`, `AMO`.

Nên ghi chú:

- Đây là subset của RISC-V RV32I, chưa phải toàn bộ ISA.
- Atomic đã có logic trong bus controller nhưng báo cáo nên phân biệt giữa “đã thiết kế hỗ trợ” và “đã kiểm thử đầy đủ”.

## 5. Cơ Chế Đa Lõi Và Truy Cập Bộ Nhớ Chung

Trình bày vấn đề chính của hệ thống 8 core:

- 8 core chạy song song.
- Tất cả cùng muốn truy cập `data_mem`.
- RAM chỉ phục vụ một giao dịch tại một thời điểm.
- Vì vậy cần arbiter để tránh xung đột.

Quy trình truy cập RAM:

```text
Core phát mem_req
-> bus_ctrl gom request
-> arbiter chọn một core
-> bus_ctrl đưa addr/wdata/we/re vào data_mem
-> data_mem đọc/ghi
-> bus_ctrl trả core_ready cho đúng core
-> core tiếp tục chạy
```

Thuật toán arbiter:

- Dùng Round-Robin.
- Core được cấp quyền xong thì priority chuyển sang core tiếp theo.
- Giúp tránh tình trạng một core chiếm bus liên tục.

## 6. Chương Trình Test Và Kết Quả Mô Phỏng

Chương trình hệ thống nằm trong:

- [system_program.hex](C:/Users/X1%20Yoga/hust/ktmt/risc_8core_project/software/system_program.hex)

Logic chương trình:

```text
ADDI x1, x0, 42
SW   x1, 0(x0)
LW   x2, 0(x0)
ADDI x3, x0, 99
SW   x3, 4(x0)
JAL  x0, 0
```

Ý nghĩa:

- Mỗi core ghi `42` vào `mem[0]`.
- Mỗi core đọc lại dữ liệu từ `mem[0]`.
- Mỗi core ghi marker `99` vào `mem[1]`.
- Nếu sau mô phỏng `mem[0] = 42` và `mem[1] = 99`, hệ thống chạy đúng và không bị deadlock.

Kết quả mô phỏng thực tế:

```text
mem[0] = 42  -> PASS
mem[1] = 99  -> PASS
TONG KET: 2 PASSED, 0 FAILED
```

## 7. Cách Chạy Mô Phỏng

Môi trường:

- Icarus Verilog: `iverilog`
- Runtime mô phỏng: `vvp`
- Xem waveform: `gtkwave` nếu đã cài

Cách chạy trên Windows:

```powershell
.\scripts\compile.bat
```

Hoặc mô tả thủ công:

```powershell
iverilog -g2012 -o tb\system_test.vvp `
  -I rtl\core -I rtl\interconnect -I rtl\memory `
  rtl\core\alu.v `
  rtl\core\control_unit.v `
  rtl\core\pc_logic.v `
  rtl\core\reg_file.v `
  rtl\core\risc_core.v `
  rtl\memory\data_mem.v `
  rtl\memory\instr_mem.v `
  rtl\interconnect\arbiter.v `
  rtl\interconnect\bus_ctrl.v `
  rtl\top_8core.v `
  tb\system_tb.v

cd tb
vvp system_test.vvp
```

Nếu muốn xem dạng sóng:

```powershell
gtkwave system_tb.vcd
```

## 8. Đánh Giá Và Hạn Chế

Nên có một phần đánh giá trung thực:

Đã hoàn thành:

- Mô phỏng được 8 core hoạt động đồng thời.
- Có instruction memory riêng cho từng core.
- Có data memory dùng chung.
- Có bus controller và arbiter Round-Robin.
- Testbench full-system chạy pass.
- Có xuất file waveform `.vcd`.

Hạn chế:

- CPU chưa có pipeline.
- Chưa có cache hoặc cache coherence.
- Chưa có interrupt, exception, CSR.
- Chưa hỗ trợ toàn bộ RISC-V ISA.
- Chưa có assembler tự động từ `.asm` sang `.hex`.
- Chưa kiểm thử đầy đủ atomic, branch phức tạp, hazard, nhiều chương trình song song khác nhau.
- Các core hiện đang chạy cùng một chương trình test.

## 9. Kết Luận

Kết luận nên viết theo hướng:

- Đề tài đã xây dựng thành công mô hình mô phỏng CPU RISC-V 8 lõi ở mức RTL.
- Hệ thống thể hiện được các nguyên lý quan trọng của Kiến trúc máy tính: fetch-decode-execute, register file, ALU, memory hierarchy đơn giản, bus arbitration và shared memory trong hệ thống đa lõi.
- Kết quả mô phỏng chứng minh 8 core có thể cùng chạy và truy cập RAM dùng chung mà không deadlock.
- Hướng phát triển: pipeline, cache, kiểm thử ISA đầy đủ, hỗ trợ nhiều chương trình khác nhau cho từng core, thêm assembler và mở rộng tập lệnh.