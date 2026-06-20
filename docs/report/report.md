# BÁO CÁO CUỐI KỲ DỰ ÁN KIẾN TRÚC MÁY TÍNH
## ĐỀ TÀI: MÔ PHỎNG CPU 8-CORE VỚI KIẾN TRÚC TẬP LỆNH RISC-V (PIPELINE 5 TẦNG)

**Nhóm thực hiện:**
1. **Hoàng Anh Quân** - MSSV: 202418969
2. **Trương Tùng Dương** - MSSV: 202418885
3. **Nguyễn Minh Hoàng** - MSSV: 202418904
4. **Bùi Thị Mai Linh** - MSSV: 20227240

---

## TÓM TẮT ĐÓNG GÓP CỦA CÁC THÀNH VIÊN
*(Sắp xếp theo thứ tự mức độ đóng góp từ cao xuống thấp)*

| STT | Thành viên | Vai trò trong nhóm | Nội dung công việc thực hiện | Mức độ đóng góp |
| :--- | :--- | :--- | :--- | :---: |
| 1 | **Nguyễn Minh Hoàng** | Thành viên | - Thiết kế bộ điều khiển Bus ([bus_ctrl.v](file:///d:/computer_architecture/risc_8core_project/rtl/interconnect/bus_ctrl.v)) và Bộ phân xử Arbiter ([arbiter.v](file:///d:/computer_architecture/risc_8core_project/rtl/interconnect/arbiter.v)).<br>- Tích hợp toàn hệ thống 8 lõi ([top_8core.v](file:///d:/computer_architecture/risc_8core_project/rtl/top_8core.v)). | **25%** |
| 2 | **Bùi Thị Mai Linh** | Thành viên | - Xây dựng kịch bản kiểm thử tích hợp hệ thống ([system_tb.v](file:///d:/computer_architecture/risc_8core_project/tb/system_tb.v)) và đơn nhân ([core_tb.v](file:///d:/computer_architecture/risc_8core_project/tb/core_tb.v)).<br>- Cấu hình môi trường biên dịch tự động, chạy mô phỏng và phân tích dạng sóng GTKWave. | **25%** |
| 3 | **Trương Tùng Dương** | Thành viên | - Thiết kế các khối chức năng cơ bản của datapath: ALU số học/logic ([alu.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/alu.v)).<br>- Thiết kế khối Tập thanh ghi ([reg_file.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/reg_file.v)) có cơ chế writeback bypass.<br>- Xây dựng bộ nhớ dữ liệu shared RAM ([data_mem.v](file:///d:/computer_architecture/risc_8core_project/rtl/memory/data_mem.v)) và các ROM chứa lệnh ([instr_mem.v](file:///d:/computer_architecture/risc_8core_project/rtl/memory/instr_mem.v)). | **25%** |
| 4 | **Hoàng Anh Quân** | Trưởng nhóm / Kiến trúc sư | - Thiết kế và kiểm thử bộ giải mã chỉ thị ([control_unit.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/control_unit.v)).<br>- Thiết kế và kiểm thử kiến trúc lõi đơn ([risc_core.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/risc_core.v)) cùng 4 thanh ghi pipeline ([pipeline_register.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/pipeline_register/hazard_controller.v)): IF/ID, ID/EX, EX/MEM, MEM/WB. | **25%** |

---

## CHƯƠNG 1: GIỚI THIỆU ĐỀ TÀI

### 1.1 Bối cảnh đề tài
Trong kiến trúc máy tính hiện đại, các giới hạn vật lý về mặt tiêu thụ năng lượng và mật độ tỏa nhiệt (Power Wall, Thermal Wall) đã ngăn cản việc tăng tần số xung nhịp của các bộ vi xử lý đơn nhân. Để tiếp tục nâng cao hiệu năng tính toán, ngành công nghiệp bán dẫn đã chuyển dịch mạnh mẽ sang xu hướng thiết kế hệ thống đa nhân hoạt động song song (Multi-core / Multiprocessor Systems). Việc thiết kế và tối ưu hóa giao tiếp, chia sẻ tài nguyên bộ nhớ giữa các nhân này là bài toán trung tâm của kiến trúc máy tính hiện đại.

### 1.2 Chủ đề của dự án
Dự án này tập trung vào việc **Thiết kế và mô phỏng ở mức RTL bộ xử lý 8 nhân (8-Core System)** sử dụng tập lệnh mã nguồn mở **RISC-V (RV32I subset)**. Mỗi lõi CPU được xây dựng theo kiến trúc **Pipeline 5 tầng** nhằm tối ưu hóa thông lượng chỉ thị. Hệ thống sử dụng một mô hình bộ nhớ dữ liệu dùng chung (Shared SRAM 4KB) thông qua trục Bus trung tâm được điều phối bởi Bộ phân xử (Arbiter) xoay vòng Round-Robin và Bộ điều khiển Bus (Bus Controller) có hỗ trợ giao dịch nguyên tử (Atomic).

### 1.3 Mục tiêu và các yêu cầu thiết kế
*   **Thiết kế lõi xử lý (Core Design):** Xây dựng lõi vi xử lý RISC-V 32-bit pipeline 5 tầng hoàn chỉnh, hỗ trợ tối thiểu 40 lệnh số nguyên cơ bản (RV32I) cùng các lệnh hỗ trợ đồng bộ đa nhân (A-Extension).
*   **Cơ chế xử lý Hazard:** Giải quyết triệt để các xung đột dữ liệu (Data Hazard), xung đột điều khiển (Control Hazard) và xung đột tài nguyên (Structural Hazard) bằng các phương pháp: Forwarding (Bơm tắt), Stall (Tạm hoãn) và Flush (Xóa lệnh).
*   **Liên kết đa nhân (Interconnect):** Thiết kế bộ Arbiter phân cấp truy cập công bằng, tránh tình trạng đói tài nguyên (starvation) và tránh deadlock khi 8 lõi CPU đồng thời gửi yêu cầu ghi/đọc bộ nhớ dùng chung.
*   **Mô phỏng và Kiểm chứng:** Đảm bảo hệ thống biên dịch không lỗi và mô phỏng thành công trên phần mềm Icarus Verilog, xuất định dạng sóng trực quan `.vcd` để kiểm chứng bằng GTKWave.

---

## CHƯƠNG 2: PHƯƠNG PHÁP LUẬN & THIẾT KẾ HỆ THỐNG

### 2.1 Phương pháp luận thiết kế hệ thống
Để xây dựng thành công hệ thống vi xử lý đa lõi 8-Core RISC-V hoạt động ổn định và tối ưu, dự án áp dụng phương pháp luận thiết kế phần cứng hệ thống theo các nguyên tắc cốt lõi sau:

#### 2.1.1 Quy trình thiết kế Top-Down kết hợp Bottom-Up
Quy trình xây dựng hệ thống kết hợp hài hòa hai cách tiếp cận:
*   **Thiết kế từ trên xuống (Top-Down Design):** Xuất phát từ yêu cầu hệ thống đa nhân chia sẻ bộ nhớ và sử dụng tập lệnh RISC-V. Hệ thống được phân rã thành các khối chức năng độc lập bao gồm: Lõi đơn nhân (Core), Bộ phân xử (Arbiter), Bộ điều khiển Bus (Bus Controller) và Bộ nhớ dữ liệu dùng chung (Shared RAM). Việc xác định rõ giao tiếp (Interface) giữa các khối này là bước tiên quyết trước khi viết mã RTL.
*   **Tích hợp từ dưới lên (Bottom-Up Integration):** Hiện thực hóa và kiểm thử kỹ lưỡng từ mức linh kiện cơ bản: Đơn vị số học logic (ALU), Tập thanh ghi (Register File), Bộ điều khiển (Control Unit), Logic cập nhật PC. Sau đó tích hợp thành Lõi xử lý đơn (Core) và trục liên kết đa nhân (Interconnect). Cuối cùng là tích hợp toàn hệ thống 8-Core và kiểm chứng bằng testbench hệ thống phức tạp.

#### 2.1.2 Mô hình hóa phần cứng ở mức RTL (RTL Modeling)
Toàn bộ hệ thống được mô tả bằng ngôn ngữ mô tả phần cứng **Verilog HDL** (chuẩn IEEE 1364-2001). Phương pháp thiết kế RTL tập trung vào:
*   **Tách biệt mạch tuần tự và mạch tổ hợp:** Sử dụng sườn lên xung nhịp (`posedge clk`) để chốt dữ liệu vào các thanh ghi pipeline và bộ đếm chương trình PC. Sử dụng khối `always @(*)` và `assign` cho các mạch tổ hợp giải mã lệnh và tính toán ALU.
*   **Thiết kế modular hóa:** Mỗi khối chức năng được đóng gói trong một file riêng biệt, giao tiếp qua các cổng dữ liệu (ports) rõ ràng, giúp dễ dàng bảo trì và kiểm thử độc lập.

#### 2.1.3 Quy trình mô phỏng và kiểm chứng dựa trên công cụ mã nguồn mở
Kiểm chứng chức năng (Functional Verification) đóng vai trò sống còn. Phương pháp luận kiểm chứng của dự án dựa trên:
*   **Mô phỏng mức RTL (RTL Simulation):** Sử dụng công cụ mã nguồn mở **Icarus Verilog** để biên dịch mã nguồn và chạy các testbench. Các kịch bản kiểm thử được thiết kế để bao phủ các tình huống xung đột dữ liệu (data hazard), xung đột điều khiển (control hazard) và tranh chấp bus bộ nhớ.
*   **Phân tích giản đồ dạng sóng (Waveform Analysis):** Xuất tệp dạng sóng định dạng VCD (Value Change Dump) và sử dụng phần mềm trực quan **GTKWave** để gỡ lỗi (debug) các hành vi phần cứng theo từng chu kỳ xung nhịp.

#### 2.1.4 Mô hình hóa chia sẻ tài nguyên và cơ chế đồng bộ
Đối với hệ thống 8 lõi dùng chung bộ nhớ:
*   **Tránh deadlock và starvation:** Áp dụng thuật toán phân xử Round-Robin cho bộ Arbiter nhằm cấp quyền truy cập bus tuần hoàn, công bằng giữa các nhân.
*   **Đồng bộ hóa phần cứng:** Hỗ trợ các chỉ thị lệnh nguyên tử (Atomic) từ nhóm mở rộng A-Extension nhằm giải quyết xung đột ghi/đọc đồng thời từ phần mềm đa nhân.

### 2.2 Kiến trúc tập lệnh RISC-V (ISA) áp dụng trong dự án
Trước khi đi vào thiết kế phần cứng ở mức RTL, việc hiểu rõ kiến trúc tập lệnh (Instruction Set Architecture - ISA) là bắt buộc. ISA đóng vai trò là đặc tả giao tiếp giữa phần mềm và phần cứng. Trong dự án này, hệ thống vi xử lý được xây dựng dựa trên tập chỉ thị **RV32I** kết hợp với một số chỉ thị thuộc nhóm mở rộng nguyên tử **A-Extension** (RV32IA subset).

#### 2.2.1 Tổng quan về tập chỉ thị RV32I
RV32I là tập chỉ thị số nguyên cơ bản dạng 32-bit của RISC-V. Đây là tập chỉ thị bắt buộc và là nền tảng cho mọi bộ xử lý RISC-V. Các đặc trưng kỹ thuật chính bao gồm:
*   **�#### 2.2.4 Đặc tả định dạng mã hóa và trường bit của các lệnh thực hiện
Bộ xử lý trong dự án này hiện thực một tập con của kiến trúc tập lệnh RV32I cùng nhóm mở rộng nguyên tử A-Extension để điều khiển và đồng bộ tính toán đa lõi. Dưới đây là mô tả chi tiết mã hóa nhị phân 32-bit cho từng chỉ thị lệnh được triển khai thực tế trong mã nguồn RTL:

##### 1. Nhóm lệnh định dạng R (R-type)
Các lệnh tính toán số học và logic thực thi trực tiếp giữa các thanh ghi nguồn (`rs1`, `rs2`) và lưu kết quả vào thanh ghi đích (`rd`). Chúng sử dụng chung mã opcode là `0110011` (7'h33). Chi tiết mã hóa các trường bit được trình bày trong Bảng 2.2.

##### 2. Nhóm lệnh định dạng I (I-type)
Các lệnh tính toán với hằng số nạp trực tiếp (`imm`), lệnh nạp dữ liệu từ bộ nhớ (`LW`), hoặc lệnh nhảy gián tiếp (`JALR`) có độ dài hằng số là 12-bit.
*   Lệnh tính toán ALU sử dụng opcode `0010011` (7'h13).
*   Lệnh đọc bộ nhớ `LW` sử dụng opcode `0000011` (7'h03).
*   Lệnh nhảy gián tiếp `JALR` sử dụng opcode `1100111` (7'h67).

Chi tiết mã hóa được trình bày trong Bảng 2.3. Đối với hai chỉ thị dịch bit `SLLI` và `SRLI`, hằng số dịch (`shamt`) chỉ có độ rộng 5-bit (để dịch tối đa 31 bit), do đó trường `imm[11:5]` được nối cứng bằng `0000000`.

##### 3. Nhóm lệnh định dạng S (S-type)
Định dạng dùng cho lệnh ghi dữ liệu vào bộ nhớ RAM dùng chung. Mã opcode duy nhất của nhóm là `0100011` (7'h23). Trường hằng số dịch chuyển địa chỉ (`imm`) được phân tách thành hai phần đặt ở hai vị trí khác nhau để tối ưu hóa đường dây giải mã trong CPU. Chi tiết mã hóa lệnh `SW` được mô tả trong Bảng 2.4.

##### 4. Nhóm lệnh định dạng B (Branch - B-type)
Các lệnh rẽ nhánh có điều kiện so sánh giá trị giữa `rs1` và `rs2` để quyết định việc thay đổi địa chỉ PC. Chúng sử dụng chung mã opcode `1100011` (7'h63). Các bit của hằng số nhảy lệch được phân rã phức tạp nhằm đồng nhất với cấu trúc mạch giải mã của định dạng S. Chi tiết cấu trúc được thể hiện qua Bảng 2.5.

##### 5. Nhóm lệnh định dạng U (U-type) và J (J-type)
Các chỉ thị làm việc với hằng số lớn nạp trực tiếp 20-bit vào nửa cao của thanh ghi (`LUI`, `AUIPC`) hoặc thực hiện lệnh nhảy không điều kiện tầm xa (`JAL`). Chi tiết cấu trúc mã hóa được thể hiện qua Bảng 2.6.

##### 6. Nhóm lệnh nguyên tử đồng bộ (A-Extension)
Đặc trưng thiết yếu của hệ thống 8 lõi xử lý chia sẻ RAM dữ liệu là việc đồng bộ hóa đa luồng thông qua các chỉ thị nguyên tử (Atomic). Các chỉ thị này sử dụng chung mã opcode `0101111` (7'h2F) và trường `funct3` mặc định là `010` (độ rộng dữ liệu word 32-bit). Lệnh được phân biệt bởi mã trường 5 bit `funct5 = instruction[31:27]`. Để đơn giản hóa mạch phần cứng, hai bit điều khiển tính nhất quán bộ nhớ là `aq` (bit 26) và `rl` (bit 25) được nối cứng về 0. Chi tiết mã hóa của các lệnh nguyên tử được thể hiện qua Bảng 2.7.

#### 2.2.5 Các bảng tổng hợp đặc tả mã hóa chỉ thị lệnh
Dưới đây là toàn bộ các bảng đặc tả mã hóa nhị phân chi tiết cho từng nhóm chỉ thị lệnh được hiện thực hóa trong dự án:

##### Bảng 2.2: Mã hóa chi tiết các lệnh định dạng R-type
| Lệnh | funct7 [31:25] | rs2 [24:20] | rs1 [19:15] | funct3 [14:12] | rd [11:7] | opcode [6:0] | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **ADD** | `0000000` | `rs2` | `rs1` | `000` | `rd` | `0110011` | `R[rd] = R[rs1] + R[rs2]` |
| **SUB** | `0100000` | `rs2` | `rs1` | `000` | `rd` | `0110011` | `R[rd] = R[rs1] - R[rs2]` |
| **SLL** | `0000000` | `rs2` | `rs1` | `001` | `rd` | `0110011` | `R[rd] = R[rs1] << R[rs2][4:0]` |
| **SLT** | `0000000` | `rs2` | `rs1` | `010` | `rd` | `0110011` | `R[rd] = (R[rs1] < R[rs2]) ? 1 : 0` |
| **XOR** | `0000000` | `rs2` | `rs1` | `100` | `rd` | `0110011` | `R[rd] = R[rs1] ^ R[rs2]` |
| **SRL** | `0000000` | `rs2` | `rs1` | `101` | `rd` | `0110011` | `R[rd] = R[rs1] >> R[rs2][4:0]` |
| **OR** | `0000000` | `rs2` | `rs1` | `110` | `rd` | `0110011` | `R[rd] = R[rs1] | R[rs2]` |
| **AND** | `0000000` | `rs2` | `rs1` | `111` | `rd` | `0110011` | `R[rd] = R[rs1] & R[rs2]` |

##### Bảng 2.3: Mã hóa chi tiết các lệnh định dạng I-type
| Lệnh | imm[11:0] [31:20] | rs1 [19:15] | funct3 [14:12] | rd [11:7] | opcode [6:0] | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **ADDI** | `imm[11:0]` | `rs1` | `000` | `rd` | `0010011` | `R[rd] = R[rs1] + imm` |
| **SLTI** | `imm[11:0]` | `rs1` | `010` | `rd` | `0010011` | `R[rd] = (R[rs1] < imm) ? 1 : 0` |
| **XORI** | `imm[11:0]` | `rs1` | `100` | `rd` | `0010011` | `R[rd] = R[rs1] ^ imm` |
| **ORI** | `imm[11:0]` | `rs1` | `110` | `rd` | `0010011` | `R[rd] = R[rs1] | imm` |
| **ANDI** | `imm[11:0]` | `rs1` | `111` | `rd` | `0010011` | `R[rd] = R[rs1] & imm` |
| **SLLI** | `0000000` \| `shamt[4:0]` | `rs1` | `001` | `rd` | `0010011` | `R[rd] = R[rs1] << shamt` |
| **SRLI** | `0000000` \| `shamt[4:0]` | `rs1` | `101` | `rd` | `0010011` | `R[rd] = R[rs1] >> shamt` |
| **LW** | `imm[11:0]` | `rs1` | `010` | `rd` | `0000011` | `R[rd] = M[R[rs1] + imm]` |
| **JALR** | `imm[11:0]` | `rs1` | `000` | `rd` | `1100111` | `R[rd] = PC + 4; PC = (R[rs1] + imm) & ~1` |

##### Bảng 2.4: Mã hóa chi tiết lệnh định dạng S-type
| Lệnh | imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **SW** | `imm[11:5]` | `rs2` | `rs1` | `010` | `imm[4:0]` | `0100011` | `M[R[rs1] + imm] = R[rs2]` |

##### Bảng 2.5: Mã hóa chi tiết các lệnh định dạng B-type
| Lệnh | imm[12\|10:5] | rs2 | rs1 | funct3 | imm[4:1\|11] | opcode | Điều kiện rẽ nhánh |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **BEQ** | `imm[12\|10:5]` | `rs2` | `rs1` | `000` | `imm[4:1\|11]` | `1100011` | `if (R[rs1] == R[rs2]) PC = PC + imm` |
| **BNE** | `imm[12\|10:5]` | `rs2` | `rs1` | `001` | `imm[4:1\|11]` | `1100011` | `if (R[rs1] != R[rs2]) PC = PC + imm` |
| **BLT** | `imm[12\|10:5]` | `rs2` | `rs1` | `100` | `imm[4:1\|11]` | `1100011` | `if (R[rs1] < R[rs2]) PC = PC + imm` |
| **BGE** | `imm[12\|10:5]` | `rs2` | `rs1` | `101` | `imm[4:1\|11]` | `1100011` | `if (R[rs1] >= R[rs2]) PC = PC + imm` |

##### Bảng 2.6: Mã hóa chi tiết các lệnh định dạng U-type và J-type
| Lệnh | imm [31:12] | rd [11:7] | opcode [6:0] | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :--- |
| **LUI** | `imm[31:12]` | `rd` | `0110111` | `R[rd] = imm << 12` |
| **AUIPC** | `imm[31:12]` | `rd` | `0010111` | `R[rd] = PC + (imm << 12)` |
| **JAL** | `imm[20\|10:1\|11\|19:12]` | `rd` | `1101111` | `R[rd] = PC + 4; PC = PC + imm` |

##### Bảng 2.7: Mã hóa chi tiết các lệnh nguyên tử thuộc nhóm A-Extension
| Lệnh | funct5 | aq | rl | rs2 | rs1 | funct3 | rd | opcode | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **LR.W** | `00010` | `0` | `0` | `00000` | `rs1` | `010` | `rd` | `0101111` | `R[rd] = M[R[rs1]] (đặt khóa)` |
| **SC.W** | `00011` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `R[rd] = SC(M[R[rs1]] = R[rs2])` |
| **AMOSWAP.W**| `00001` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = R[rs2]; R[rd] = temp` |
| **AMOADD.W** | `00000` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp + R[rs2]; R[rd] = temp` |
| **AMOAND.W** | `01100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp & R[rs2]; R[rd] = temp` |
| **AMOOR.W** | `01010` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp \| R[rs2]; R[rd] = temp` |
| **AMOXOR.W** | `00100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp ^ R[rs2]; R[rd] = temp` |
| **AMOMIN.W** | `10000` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = min(temp, R[rs2]); R[rd] = temp` |
| **AMOMAX.W** | `10100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = max(temp, R[rs2]); R[rd] = temp` |
| **AMOMINU.W**| `11000` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = min_u(temp, R[rs2]); R[rd] = temp` |
| **AMOMAXU.W**| `11100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = max_u(temp, R[rs2]); R[rd] = temp` |1\|11]` | `1100011` | `if (R[rs1] < R[rs2]) PC = PC + imm` |
| **BGE** | `imm[12\|10:5]` | `rs2` | `rs1` | `101` | `imm[4:1\|11]` | `1100011` | `if (R[rs1] >= R[rs2]) PC = PC + imm` |

##### 5. Nhóm lệnh định dạng U (U-type) và J (J-type)

| Lệnh | imm [31:12] | rd [11:7] | opcode [6:0] | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :--- |
| **LUI** | `imm[31:12]` | `rd` | `0110111` | `R[rd] = imm << 12` |
| **AUIPC** | `imm[31:12]` | `rd` | `0010111` | `R[rd] = PC + (imm << 12)` |
| **JAL** | `imm[20\|10:1\|11\|19:12]` | `rd` | `1101111` | `R[rd] = PC + 4; PC = PC + imm` |

##### 6. Nhóm lệnh nguyên tử đồng bộ (A-Extension)
Các chỉ thị này sử dụng chung mã opcode `0101111` (7'h2F) và trường `funct3` mặc định là `010`. Hai bit `aq` (bit 26) và `rl` (bit 25) được nối cứng về 0.

| Lệnh | funct5 | aq | rl | rs2 | rs1 | funct3 | rd | opcode | Mô tả hoạt động |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **LR.W** | `00010` | `0` | `0` | `00000` | `rs1` | `010` | `rd` | `0101111` | `R[rd] = M[R[rs1]] (đặt khóa)` |
| **SC.W** | `00011` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `R[rd] = SC(M[R[rs1]] = R[rs2])` |
| **AMOSWAP.W**| `00001` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = R[rs2]; R[rd] = temp` |
| **AMOADD.W** | `00000` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp + R[rs2]; R[rd] = temp` |
| **AMOAND.W** | `01100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp & R[rs2]; R[rd] = temp` |
| **AMOOR.W** | `01010` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp \| R[rs2]; R[rd] = temp` |
| **AMOXOR.W** | `00100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = temp ^ R[rs2]; R[rd] = temp` |
| **AMOMIN.W** | `10000` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = min(temp, R[rs2]); R[rd] = temp` |
| **AMOMAX.W** | `10100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = max(temp, R[rs2]); R[rd] = temp` |
| **AMOMINU.W**| `11000` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = min_u(temp, R[rs2]); R[rd] = temp` |
| **AMOMAXU.W**| `11100` | `0` | `0` | `rs2` | `rs1` | `010` | `rd` | `0101111` | `temp = M[R[rs1]]; M[R[rs1]] = max_u(temp, R[rs2]); R[rd] = temp` |

### 2.3 Cấu trúc tổng thể hệ thống 8-Core
Hệ thống bao gồm 8 lõi CPU độc lập kết nối với nhau qua bộ liên kết trung tâm Interconnect để truy cập vào vùng RAM dùng chung. Cấu trúc tổng thể như sau:

```text
                     +---------------------------------------+
                     |         Bộ nhớ chung (Shared RAM)      |
                     +---------------------------------------+
                                         ^
                                         | Shared Bus
                     +---------------------------------------+
                     |          Bộ Điều Khiển Bus            | <---+
                     |           (bus_ctrl.v)                |     |
                     +---------------------------------------+     |
                       ^           ^                   ^           | req / grant
                       |           |                   |           v
                 +-----+     +-----+             +-----+     +-----------+
                 |           |                   |           |  Arbiter  |
                 v           v                   v           | (arbiter) |
             +-------+   +-------+           +-------+       +-----------+
             | Core 0|   | Core 1|   ...     | Core 7|
             +-------+   +-------+           +-------+
```

*   **Lõi CPU (`risc_core.v`):** Thực thi tập lệnh độc lập, có bộ nhớ chương trình (Instruction ROM) độc lập để tránh xung đột nạp lệnh.
*   **Bộ phân xử (`arbiter.v`):** Định đoạt nhân nào được quyền sử dụng Bus dựa trên thuật toán Round-Robin.
*   **Bộ điều khiển Bus (`bus_ctrl.v`):** Thực hiện định tuyến dữ liệu, địa chỉ và phản hồi tín hiệu `ready` cho nhân được cấp quyền.

### 2.4 Kiến trúc đường truyền dữ liệu (Datapath) đơn lõi
Đường truyền dữ liệu (Datapath) của lõi vi xử lý đơn nhân ([risc\_core.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/risc_core.v)) được tổ chức thành 5 giai đoạn (stages) xử lý gối đầu nhau, liên kết bởi các thanh ghi đệm:

#### 1. Tầng Nạp chỉ thị (Instruction Fetch - IF)
*   **Chức năng:** Lấy mã chỉ thị 32-bit từ bộ nhớ chương trình riêng ([instr\_mem.v](file:///d:/computer_architecture/risc_8core_project/rtl/memory/instr_mem.v)) dựa trên bộ đếm chương trình PC.
*   **Cập nhật PC:** Được điều khiển bởi khối logic PC ([pc\_logic.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/pc_logic.v)). Địa chỉ PC sẽ tăng tiến thêm 4 byte (`PC + 4`) trong mỗi chu kỳ. Tuy nhiên:
    *   Nếu gặp **Stall** do xung đột dữ liệu hoặc phải chờ cấp quyền Bus (`mem_wait`), PC sẽ giữ nguyên giá trị để đóng băng luồng lệnh.
    *   Nếu xảy ra rẽ nhánh hoặc nhảy (`redirect_taken` từ tầng EX), địa chỉ PC lập tức nạp địa chỉ đích mới (`redirect_target`).
*   **Thanh ghi đệm IF/ID:** Lưu lại giá trị PC và lệnh lấy được vào `if_id_pc` và `if_id_instr`.

#### 2. Tầng Giải mã chỉ thị (Instruction Decode - ID)
*   **Giải mã điều khiển:** Khối [control\_unit.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/control_unit.v) giải mã op-code, funct3, funct7 của chỉ thị nằm trong `if_id_instr` để tạo ra toàn bộ các tín hiệu điều khiển của lõi (ví dụ: `reg_write`, `alu_src`, `alu_control`, `mem_read`, `mem_write`, v.v.).
*   **Tập thanh ghi:** Khối [reg\_file.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/reg_file.v) đọc bất đồng bộ toán hạng từ thanh ghi nguồn `rs1` và `rs2`.
*   **Bộ sinh hằng số:** Trích xuất và căn lề dấu (sign-extend) hằng số nạp trực tiếp `imm` tương ứng kiểu lệnh.
*   **Thanh ghi đệm ID/EX:** Đẩy toàn bộ dữ liệu toán hạng và cờ điều khiển vào các thanh ghi đệm `id_ex_*`.

#### 3. Tầng Thực thi (Execute - EX)
*   **Mạch Bơm tắt dữ liệu (Forwarding MUX):** So sánh địa chỉ thanh ghi đích đang xử lý ở tầng `EX/MEM` và `MEM/WB` với địa chỉ nguồn `rs1`/`rs2` của tầng hiện tại. Nếu có phụ thuộc dữ liệu, kết quả `ex_mem_result` hoặc `mem_wb_write_data` được bơm tắt ngược về làm đầu vào ALU mà không cần đợi Writeback.
*   **Bộ chọn nguồn ALU (ALU Source MUX):** Lựa chọn toán hạng đầu vào ALU:
    *   Đầu vào A: Luôn là dữ liệu thanh ghi 1 sau forwarding (`fwd_rs1_data`).
    *   Đầu vào B: Chọn qua MUX 2-sang-1 giữa hằng số immediate (`id_ex_imm`) nếu `alu_src = 1`, hoặc dữ liệu nguồn 2 sau forwarding (`fwd_rs2_data`) nếu `alu_src = 0`.
*   **Tính toán số học (ALU):** Khối [alu.v](file:///d:/computer_architecture/risc_8core_project/rtl/core/alu.v) tính toán đưa ra kết quả `alu_result` và cờ báo không `zero`.
*   **Xử lý Rẽ nhánh & Nhảy:** Tầng EX đánh giá điều kiện rẽ nhánh (BEQ, BNE, BLT, BGE) và địa chỉ nhảy (`redirect_target`). Nếu rẽ nhánh được thực hiện hoặc là lệnh nhảy, tín hiệu `redirect_taken` được kích hoạt đưa về tầng IF để cập nhật PC và phát lệnh xóa (**Flush**) làm trống các tầng đệm pipeline đi sai hướng.

#### 4. Tầng Truy cập bộ nhớ (Memory Access - MEM)
*   **Giao dịch Bộ nhớ:** Nếu lệnh là `LW`, `SW`, hoặc các lệnh nguyên tử (`LR`, `SC`, `AMO`), tầng MEM phát đi yêu cầu `mem_req` ra trục bus trung tâm cùng địa chỉ bộ nhớ và dữ liệu ghi.
*   **Memory Stall:** Core phải giữ nguyên trạng thái ở tầng MEM và stall toàn bộ các tầng trước cho tới khi Bus Controller phản hồi tín hiệu sẵn sàng `mem_ready = 1`.
*   **Ghi nhận dữ liệu:** Dữ liệu đọc được (`mem_rdata`) hoặc kết quả ghi điều kiện (`mem_sc_result` cho lệnh `SC.W`) được chốt vào thanh ghi đệm `mem_wb_*`.

#### 5. Tầng Ghi ngược (Writeback - WB)
*   **Bộ chọn dữ liệu ghi ngược (Writeback MUX):** Chọn lựa dữ liệu `mem_wb_write_data` để ghi lại vào register file: chọn `mem_rdata` (nếu đọc bộ nhớ), `mem_sc_result` (nếu ghi điều kiện), hoặc chọn kết quả ALU/PC (đối với các lệnh tính toán và nhảy).
*   **Cập nhật Register File:** Khẳng định tín hiệu ghi `rf_write_en` để thực hiện ghi đồng bộ dữ liệu vào thanh ghi đích `rd` ở sườn lên clock tiếp theo.

### 2.5 Cơ chế xử lý xung đột trong Pipeline (Hazard Handling)
*   **Xung đột dữ liệu (Data Hazard):** Được xử lý bằng đường truyền tắt (**Forwarding Paths**) từ tầng `EX/MEM` và `MEM/WB` quay ngược lại đầu vào của ALU. Với xung đột kiểu **Load-use hazard** (lệnh ngay sau `LW` cần sử dụng dữ liệu vừa load), bộ xử lý chèn thêm 1 chu kỳ hoãn (**Stall**) bằng cách giữ nguyên PC và làm trống tầng `ID/EX`.
*   **Xung đột điều khiển (Control Hazard):** Xảy ra khi lệnh rẽ nhánh (`Branch`) hoặc nhảy (`Jump`) được xác định kết quả tại tầng `EX`. Hệ thống sẽ kích hoạt tín hiệu xóa (**Flush**) để đưa các thanh ghi đệm pipeline `IF/ID` và `ID/EX` về trạng thái không hợp lệ (`valid = 0`), biến các lệnh nạp sai hướng thành lệnh rỗng `NOP` (`32'h0000_0013`).

### 2.6 Trục liên kết Interconnect và Phân xử Arbiter
*   **Thuật toán Round-Robin:** Để đảm bảo tính công bằng và loại bỏ starvation, bộ phân xử sử dụng con trỏ ưu tiên (`priority_ptr`). Khi một nhân gửi yêu cầu và được cấp bus (`grant`), con trỏ ưu tiên sẽ dịch chuyển sang nhân kế tiếp (`priority_ptr <= winner + 1`).
*   **Hỗ trợ Giao dịch nguyên tử (Atomic):** Trục bus hỗ trợ lưu vết địa chỉ khóa cho cặp lệnh `LR.W` (Load-Reserved) và `SC.W` (Store-Conditional), giúp hệ thống 8 lõi có thể xây dựng các biến đồng bộ đồng thời (Mutex/Semaphore) mức phần mềm mà không lo ngại xung đột tài nguyên.

---

## CHƯƠNG 3: KẾT QUẢ VÀ BÀN LUẬN

### 3.1 Môi trường mô phỏng và kiểm thử
Dự án sử dụng ngôn ngữ mô tả phần cứng **Verilog HDL (chuẩn IEEE 1364-2001 / SystemVerilog 2012)**. Các công cụ triển khai bao gồm:
*   **Icarus Verilog:** Trình biên dịch mã nguồn và sinh tệp thực thi mô phỏng.
*   **VVP (Verilog Simulator Engine):** Trực tiếp chạy tệp mô phỏng và xuất dữ liệu ghi dạng sóng.
*   **GTKWave:** Công cụ hiển thị dạng sóng `.vcd` trực quan.

### 3.2 Kết quả kiểm thử lõi đơn (Single Core Test)
Chạy kịch bản kiểm thử trên file testbench lõi đơn [core_tb.v](file:///d:/computer_architecture/risc_8core_project/tb/core_tb.v):
*   **Kết quả:** `SUMMARY: 7 PASSED, 0 FAILED`.
*   **Phân tích thông số Pipeline:**
    *   `retired = 67`: Tổng số lệnh thực thi và ghi nhận thành công.
    *   `load_use_stall = 1`: Mạch kiểm soát hazard chèn đúng 1 chu kỳ stall khi gặp phụ thuộc dữ liệu sau lệnh đọc bộ nhớ.
    *   `flush = 62`: Xóa thành công các lệnh bị nạp sai hướng rẽ nhánh khi chuyển PC đột ngột.

### 3.3 Kết quả kiểm thử toàn hệ thống 8-Core (Multi-Core Integration Test)
Chạy chương trình tính toán song song song trên bộ nhớ dùng chung với kịch bản được định nghĩa tại [system_tb.v](file:///d:/computer_architecture/risc_8core_project/tb/system_tb.v). Chương trình Assembly nạp cho mỗi core thực hiện:
1.  Ghi giá trị `42` vào địa chỉ `mem[0]`.
2.  Đọc lại giá trị từ `mem[0]` kiểm tra.
3.  Ghi dấu mốc hoàn thành `99` vào địa chỉ `mem[1]`.

**Kết quả từ Console Output:**
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

**Bàn luận kết quả mô phỏng:**
1.  **Tính đúng đắn dữ liệu:** Giá trị bộ nhớ cuối cùng đạt `mem[0] = 42` và `mem[1] = 99`, cho thấy quá trình đọc ghi thông qua Bus diễn ra trơn tru.
2.  **Khả năng phân xử của Bus:** Mọi lõi (Core 0 đến Core 7) đều nhận được quyền ghi Bus (`grant` đạt từ 3 đến 4 lần). Tín hiệu `mem_stall` tăng dần từ Core 0 đến Core 7 cho thấy rõ sự tranh chấp đường truyền bus trên thực tế (khi Core trước đang sử dụng bus, Core sau phải stall giữ nguyên trạng thái chờ).
3.  **Hoàn thành không Deadlock:** Cả 8 core đều chạy đến chỉ thị kết thúc và không phát sinh trạng thái treo (deadlock), khẳng định thuật toán phân xử Round-Robin hoạt động hoàn hảo.

---

## CHƯƠNG 4: HẠN CHẾ VÀ HƯỚNG PHÁT TRIỂN

### 4.1 Lý do triển khai một phần và hạn chế hiện tại
Để kiểm soát độ phức tạp của dự án trong khuôn khổ đồ án môn học, nhóm nghiên cứu đã lựa chọn thực hiện một mô hình giản lược có các hạn chế sau:
*   **Chưa tích hợp bộ nhớ đệm (Cache):** Việc 8 nhân truy cập trực tiếp vào RAM dùng chung gây nghẽn băng thông bus nghiêm trọng (thể hiện qua chỉ số `mem_stall_count` khá cao).
*   **Chưa có cơ chế Cache Coherence:** Do chưa có L1/L2 Cache riêng nên nhóm chưa phát triển các giao thức đồng bộ trạng thái cache như MESI.
*   **Giới hạn tập lệnh:** Chỉ hỗ trợ tập con lệnh cơ bản nhất của RV32I và thiếu các thanh ghi điều khiển hệ thống (CSR), ngắt (Interrupt) và ngoại lệ (Exception).

### 4.2 Hướng phát triển tiếp theo
*   Thiết kế bổ sung bộ nhớ đệm dữ liệu (L1 Data Cache) riêng cho mỗi core.
*   Ứng dụng giao thức MESI hoặc Snooping Bus để quản lý tính nhất quán dữ liệu bộ nhớ đệm (Cache Coherence).
*   Mở rộng đầy đủ tập lệnh RV32IM để tăng tốc các phép toán nhân/chia phần cứng.

---

## CHƯƠNG 5: TÀI LIỆU THAM KHẢO

1.  David A. Patterson và John L. Hennessy, *Computer Organization and Design RISC-V Edition: The Hardware Software Interface*, Morgan Kaufmann, 2017.
2.  RISC-V International, *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA, Version 20191213*.
3.  Steve Harris và Sarah Harris, *Digital Design and Computer Architecture: ARM Edition*, Morgan Kaufmann, 2015.

---

## PHỤ LỤC: KẾ HOẠCH LÀM VIỆC CỦA NHÓM

| Tuần thực hiện | Nội dung công việc | Nhân sự phụ trách | Trạng thái |
| :--- | :--- | :--- | :---: |
| **Tuần 1 - 2** | Nghiên cứu kiến trúc RISC-V RV32I, định dạng lệnh và thiết kế Datapath đơn nhân. | Cả nhóm | Hoàn thành |
| **Tuần 3 - 4** | Hiện thực hóa mã nguồn Verilog đơn nhân đơn chu kỳ. | Minh Hoàng, Mai Linh | Hoàn thành |
| **Tuần 5 - 6** | Chuyển đổi lõi đơn sang kiến trúc Pipeline 5 tầng, hiện thực hóa Hazard Unit. | Anh Quân, Minh Hoàng | Hoàn thành |
| **Tuần 7** | Thiết kế bộ phân xử Arbiter và Bus Controller cho trục kết nối đa nhân. | Anh Quân | Hoàn thành |
| **Tuần 8** | Tích hợp hệ thống 8-Core hoàn chỉnh, viết testbench lõi đơn và hệ thống. | Anh Quân, Tùng Dương | Hoàn thành |
| **Tuần 9** | Chạy mô phỏng, phân tích lỗi, sửa lỗi hazard và hoàn thiện dạng sóng mô phỏng. | Tùng Dương, Mai Linh | Hoàn thành |
| **Tuần 10** | Viết báo cáo cuối kỳ và thiết kế Slide thuyết trình. | Cả nhóm | Hoàn thành |
