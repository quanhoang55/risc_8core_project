# Huong Dan Trinh Bay He Thong Mo Phong CPU RISC-V 8 Core Pipeline 5 Tang

## 1. He Thong Da Hoan Thanh Chua?

Co. O muc do do an mon Kien truc may tinh, he thong nay da hoan thanh viec mo phong CPU RISC-V 8 core theo kien truc pipeline 5 tang.

Bang chung trong ma nguon hien tai:

- `rtl/core/risc_core.v` da duoc chuyen sang core pipeline 5 tang: `IF -> ID -> EX -> MEM -> WB`.
- `rtl/top_8core.v` khoi tao 8 core pipeline va noi chung vao `bus_ctrl`, `arbiter`, `data_mem`.
- `tb/system_tb.v` mo phong toan bo he thong 8 core, kiem tra ket qua RAM dung va in them bang chung pipeline/bus.
- `tb/core_tb.v` mo phong 1 core, kiem tra ALU, load/store, branch, stall va flush.
- `docs/pipeline_evidence.md` ghi lai bang chung va cac diem can dua vao slide.
- `software/program.asm` va `software/system_program.asm` la ma assembly nguon de giai thich chuong trinh test.

Ket qua mong doi khi chay mo phong:

```text
CORE TEST:
SUMMARY: 7 PASSED, 0 FAILED

SYSTEM TEST:
TONG KET: 10 PASSED, 0 FAILED
```

Nen trinh bay voi thay theo huong: "He thong da mo phong thanh cong CPU RISC-V 8 loi, moi loi la mot pipeline 5 tang don gian, cung truy cap RAM dung chung thong qua bus controller va arbiter Round-Robin. Ket qua mo phong cho thay 8 core cung thuc thi chuong trinh, tranh chap bus, ghi/doc RAM dung va khong bi deadlock."

Ghi chu trung thuc: day la mo hinh RTL phuc vu hoc tap, chua phai CPU cong nghiep. He thong chua co cache, interrupt/exception day du, CSR, operating system, hay cache coherence.

## 2. Muc Tieu Cua De Tai

Muc tieu chinh:

- Thiet ke mot he thong CPU RISC-V 8 core bang Verilog.
- Moi core co kha nang thuc thi mot chuong trinh RISC-V don gian.
- Chuyen core tu kien truc multi-cycle sang pipeline 5 tang.
- Ket noi 8 core vao mot bo nho du lieu dung chung.
- Xu ly tranh chap truy cap bo nho bang arbiter Round-Robin.
- Mo phong va kiem chung bang Icarus Verilog.
- Tao file waveform `.vcd` de xem bang GTKWave va dua vao slide.

Cac cau hoi can tra loi trong bao cao:

- CPU RISC-V la gi?
- Pipeline 5 tang hoat dong nhu the nao?
- Mot lenh di qua cac tang pipeline ra sao?
- Tai sao can forwarding, stall va flush?
- 8 core tranh chap RAM dung chung nhu the nao?
- Arbiter Round-Robin cap quyen bus nhu the nao?
- Ket qua mo phong chung minh dieu gi?

## 3. Tong Quan Kien Truc He Thong

So do muc cao:

```text
          +-------------+
Core 0 -> |             |
Core 1 -> |             |
Core 2 -> |             |
Core 3 -> |             |
Core 4 -> |  bus_ctrl   | -> data_mem
Core 5 -> |             |
Core 6 -> |             |
Core 7 -> |             |
          +-------------+
                 ^
                 |
            +---------+
            | arbiter |
            +---------+
```

Thanh phan chinh:

- `top_8core`: module top-level, ghep 8 core pipeline voi bus va RAM dung chung.
- `risc_core`: mot core RISC-V pipeline 5 tang.
- `instr_mem`: bo nho lenh rieng cho moi core.
- `data_mem`: bo nho du lieu dung chung 4 KB.
- `bus_ctrl`: dieu khien giao tiep giua 8 core va data memory.
- `arbiter`: chon core duoc truy cap RAM theo Round-Robin.
- `control_unit`: giai ma lenh RISC-V va tao tin hieu dieu khien.
- `alu`: thuc hien cac phep toan so hoc/logic.
- `reg_file`: 32 thanh ghi 32-bit cua RISC-V.

Y tuong quan trong: moi core co instruction memory rieng, nhung tat ca core dung chung data memory. Vi vay khi nhieu core cung doc/ghi RAM, he thong phai co arbiter de tranh xung dot.

## 4. Co So Ly Thuyet Can Nam

### 4.1. RISC-V La Gi?

RISC-V la mot tap lenh mo theo kieu RISC. RISC co dac diem:

- Lenh co dang don gian.
- Do dai lenh co ban la 32 bit.
- Kien truc load/store: chi lenh load/store moi truy cap bo nho.
- Cac phep toan ALU chu yeu lam viec tren thanh ghi.
- Co 32 thanh ghi tong quat `x0` den `x31`.
- Thanh ghi `x0` luon bang 0.

Trong de tai nay, CPU ho tro mot tap con cua RV32I:

- R-type: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SLT`.
- I-type: `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLLI`, `SRLI`.
- Memory: `LW`, `SW`.
- Branch: `BEQ`, `BNE`, `BLT`, `BGE`.
- Jump: `JAL`, `JALR`.
- U-type: `LUI`, `AUIPC`.
- Atomic signals: `LR`, `SC`, `AMO` da co duong tin hieu va logic bus, nhung nen trinh bay la phan mo rong/kiem thu bo sung neu chua demo sau.

### 4.2. Kien Truc Pipeline 5 Tang

Pipeline chia qua trinh thuc thi lenh thanh nhieu tang. Thay vi cho mot lenh chay xong het moi bat dau lenh tiep theo, pipeline cho nhieu lenh cung ton tai trong CPU o cac tang khac nhau.

5 tang pipeline trong he thong:

```text
IF  -> ID  -> EX  -> MEM -> WB
```

Y nghia tung tang:

- `IF` - Instruction Fetch: lay lenh tu instruction memory theo dia chi PC.
- `ID` - Instruction Decode: giai ma lenh, doc thanh ghi, tao immediate va control signals.
- `EX` - Execute: ALU tinh toan, xac dinh branch/jump, tinh dia chi memory.
- `MEM` - Memory Access: doc/ghi data memory thong qua bus dung chung.
- `WB` - Write Back: ghi ket qua ve register file.

Vi du voi lenh:

```asm
addi x1, x0, 42
```

Luong chay:

```text
IF  : lay ma lenh addi
ID  : giai ma opcode, doc x0, tao immediate = 42
EX  : ALU tinh x0 + 42
MEM : khong truy cap RAM
WB  : ghi 42 vao x1
```

Vi du voi lenh:

```asm
sw x1, 0(x0)
```

Luong chay:

```text
IF  : lay ma lenh sw
ID  : doc x1 va x0, tao immediate = 0
EX  : tinh dia chi x0 + 0
MEM : gui request ghi RAM qua bus
WB  : khong ghi thanh ghi
```

## 5. Cac Hazard Trong Pipeline

Pipeline nhanh hon multi-cycle nhung sinh ra hazard. Bao cao nen co mot muc rieng ve hazard, vi day la diem the hien da that su phat trien kien truc pipeline.

### 5.1. Data Hazard

Data hazard xay ra khi mot lenh can dung ket qua cua lenh truoc do, nhung ket qua chua kip ghi ve register file.

Vi du:

```asm
addi x1, x0, 10
add  x3, x1, x2
```

Lenh `add` can gia tri moi cua `x1`, trong khi `addi` co the chua den tang `WB`.

Cach xu ly trong he thong:

- Forwarding tu `EX/MEM` ve `EX`.
- Forwarding tu `MEM/WB` ve `EX`.
- Writeback bypass trong `reg_file` de lenh dang decode doc duoc gia tri vua WB.

Tin hieu/counter lien quan:

- `retired_count`: so lenh da di qua pipeline.
- `load_use_stall_count`: so lan pipeline phai stall do load-use hazard.

### 5.2. Load-Use Hazard

Load-use hazard xay ra khi lenh ngay sau `lw` dung thanh ghi vua load.

Vi du trong `software/program.asm`:

```asm
lw   x4, 0(x0)
beq  x3, x4, pass
```

Lenh `beq` can `x4`, nhung `x4` chi co du lieu sau khi load xong tu memory. He thong phai chen stall de doi du lieu hop le.

Bang chung:

```text
load_use_stall=1
```

Dong nay duoc in trong `tb/core_tb.v`.

### 5.3. Control Hazard

Control hazard xay ra voi branch/jump, vi CPU co the da fetch lenh tiep theo truoc khi biet branch co nhay hay khong.

Vi du:

```asm
beq x3, x4, pass
jal x0, fail
```

Neu branch duoc lay, lenh `jal x0, fail` da fetch sai duong va phai bi xoa khoi pipeline.

Cach xu ly:

- Branch/jump duoc quyet dinh o tang `EX`.
- Neu branch/jump thay doi PC, pipeline flush cac lenh sai duong.

Tin hieu/counter lien quan:

- `flush_count`: so lan pipeline flush do branch/jump.

### 5.4. Structural Hazard

Structural hazard xay ra khi nhieu thanh phan can dung cung mot tai nguyen phan cung.

Trong he thong 8 core:

- Tat ca core dung chung `data_mem`.
- RAM chi phuc vu mot giao dich tai mot thoi diem.
- Nhieu core cung gui `mem_req` se gay tranh chap bus.

Cach xu ly:

- `arbiter` chon core duoc truy cap.
- `bus_ctrl` chi dua giao dich cua core duoc grant vao RAM.
- Core nao chua duoc phuc vu se stall o tang `MEM`.

Tin hieu/counter lien quan:

- `grant`: so lan moi core duoc cap bus.
- `mem_stall_count`: so cycle core phai doi bus/memory.

## 6. Luong Hoat Dong Tu A Den Z

### 6.1. Khi Reset

Khi `reset = 1`:

- PC cua moi core ve 0.
- Pipeline register bi clear.
- Register file ve 0.
- Data memory ve 0.
- Arbiter va bus controller ve trang thai ban dau.

Sau do `reset = 0`, cac core bat dau fetch lenh tu dia chi 0.

### 6.2. Mot Core Thuc Thi Lenh

Luong cua mot lenh trong mot core:

```text
PC -> instr_mem -> IF/ID -> control_unit + reg_file
   -> ID/EX -> ALU/branch logic
   -> EX/MEM -> bus/data memory neu can
   -> MEM/WB -> reg_file
```

Trong code:

- `if_id_*`: thanh ghi pipeline giua IF va ID.
- `id_ex_*`: thanh ghi pipeline giua ID va EX.
- `ex_mem_*`: thanh ghi pipeline giua EX va MEM.
- `mem_wb_*`: thanh ghi pipeline giua MEM va WB.

Day la bang chung ro nhat cho thay core khong con la multi-cycle FSM nua, ma da co pipeline register that.

### 6.3. 8 Core Cung Chay

Trong `top_8core.v`, he thong tao 8 instance:

```text
gen_core[0].u_core
gen_core[1].u_core
...
gen_core[7].u_core
```

Tat ca core chay cung chuong trinh:

```text
software/system_program.hex
```

Assembly tuong ung:

```asm
addi x1, x0, 42
sw   x1, 0(x0)
lw   x2, 0(x0)
addi x3, x0, 99
sw   x3, 4(x0)
jal  x0, halt
```

Y nghia:

- Moi core tao gia tri 42.
- Moi core ghi 42 vao `mem[0]`.
- Moi core doc lai `mem[0]`.
- Moi core tao marker 99.
- Moi core ghi 99 vao `mem[1]`.
- Cuoi cung moi core vao vong lap halt.

### 6.4. Khi Core Truy Cap RAM

Neu mot core gap lenh `LW`, `SW`, `LR`, `SC`, hoac `AMO`, no phat tin hieu:

```text
mem_req
mem_addr
mem_wdata
mem_we
mem_re
```

Sau do:

```text
Core -> bus_ctrl -> arbiter -> data_mem -> bus_ctrl -> Core
```

Chi tiet:

1. Core bat `mem_req = 1`.
2. `bus_ctrl` gom request cua 8 core thanh `bus_request`.
3. `arbiter` chon mot core theo Round-Robin.
4. `bus_ctrl` dua dia chi/du lieu cua core duoc chon vao `data_mem`.
5. `data_mem` doc hoac ghi.
6. `bus_ctrl` tra `core_ready[core_id] = 1`.
7. Core tiep tuc pipeline.

## 7. Arbiter Round-Robin

Vi tat ca core dung chung RAM, can co co che chon core nao duoc truy cap truoc.

Round-Robin hoat dong nhu sau:

- Neu nhieu core cung request, arbiter chon core theo thu tu xoay vong.
- Sau khi cap grant cho core `i`, lan tiep theo uu tien bat dau tu core `i + 1`.
- Cach nay giup tranh viec mot core chiem bus lien tuc.

Trong output `system_tb`, cot `grant` cho biet moi core duoc cap bus bao nhieu lan.

Vi du:

```text
Core 0: grant=3 retired=163 mem_stall=13 load_use_stall=0 flush=159
Core 1: grant=3 retired=163 mem_stall=14 load_use_stall=0 flush=159
...
Core 7: grant=4 retired=161 mem_stall=20 load_use_stall=0 flush=157
```

Khi trinh bay, co the noi:

"Moi core deu co grant lon hon 0, nghia la tat ca core deu tung truy cap shared memory. He thong khong bi starvation va khong bi deadlock trong mo phong."

## 8. Cac File Quan Trong

| File | Vai tro |
|---|---|
| `rtl/core/risc_core.v` | Core RISC-V pipeline 5 tang |
| `rtl/core/control_unit.v` | Giai ma lenh, tao tin hieu dieu khien |
| `rtl/core/alu.v` | Khoi tinh toan so hoc/logic |
| `rtl/core/reg_file.v` | 32 thanh ghi RISC-V |
| `rtl/memory/instr_mem.v` | ROM lenh rieng cua moi core |
| `rtl/memory/data_mem.v` | RAM du lieu dung chung |
| `rtl/interconnect/arbiter.v` | Cap bus theo Round-Robin |
| `rtl/interconnect/bus_ctrl.v` | Dieu khien doc/ghi RAM cho 8 core |
| `rtl/top_8core.v` | Noi 8 core voi bus va RAM |
| `tb/core_tb.v` | Test 1 core pipeline |
| `tb/system_tb.v` | Test full 8 core pipeline |
| `software/program.asm` | Assembly cho test 1 core |
| `software/system_program.asm` | Assembly cho test 8 core |
| `docs/pipeline_evidence.md` | Bang chung pipeline cho slide |

## 9. Quy Trinh Chay Mo Phong

### 9.1. Cong Cu Can Co

Can cai:

- Icarus Verilog: `iverilog`
- Runtime cua Icarus: `vvp`
- GTKWave neu muon xem waveform: `gtkwave`

Kiem tra:

```powershell
iverilog -V
vvp -V
```

Neu co GTKWave:

```powershell
gtkwave --version
```

### 9.2. Chay Mo Phong 8 Core

Tu thu muc root cua project:

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

Ket qua can thay:

```text
BAT DAU MO PHONG HE THONG 8 LOI PIPELINE

Kiem tra mem[0] (Ky vong: 42) = 42
[PASS] Shared memory data dung.

Kiem tra mem[1] addr 4 (Ky vong: 99) = 99
[PASS] 8 core hoan thanh chuong trinh khong deadlock.

PIPELINE / BUS EVIDENCE
Core 0: grant=... retired=... mem_stall=... load_use_stall=... flush=...
...
Core 7: grant=... retired=... mem_stall=... load_use_stall=... flush=...

TONG KET: 10 PASSED, 0 FAILED
```

### 9.3. Chay Mo Phong 1 Core

Tu thu muc root:

```powershell
iverilog -g2012 -o tb\core_test.vvp `
  -I rtl\core -I rtl\memory `
  rtl\core\alu.v `
  rtl\core\control_unit.v `
  rtl\core\reg_file.v `
  rtl\core\risc_core.v `
  rtl\memory\data_mem.v `
  rtl\memory\instr_mem.v `
  tb\core_tb.v

cd tb
vvp core_test.vvp
```

Ket qua can thay:

```text
CORE TEST RESULTS
x1 = 10  [PASS]
x2 = 20  [PASS]
x3 = 30  [PASS]
x4 = 30  [PASS]
x5 = 1   [PASS]
mem[0] = 30 [PASS]

PIPELINE EVIDENCE
retired=67 mem_stall=4 load_use_stall=1 flush=62
[PASS] Pipeline counters show retire/stall/flush activity.

SUMMARY: 7 PASSED, 0 FAILED
```

### 9.4. Chay Bang Script

Neu dung Windows:

```powershell
.\scripts\compile.bat
```

Script nay bien dich full system va chay `system_tb`.

Neu dung Linux/MSYS/Git Bash:

```bash
./scripts/compile.sh
```

### 9.5. Xem Waveform

Sau khi mo phong, testbench tao file:

```text
tb/system_tb.vcd
tb/core_tb.vcd
```

Mo waveform:

```powershell
gtkwave tb\system_tb.vcd
```

Nen chup cac tin hieu sau de dua vao slide:

- `clk`, `reset`
- `dut.gen_core[0].u_core.pc`
- `if_id_valid`, `id_ex_valid`, `ex_mem_valid`, `mem_wb_valid`
- `mem_req`, `mem_ready`, `mem_addr`, `mem_we`, `mem_re`
- `dut.u_arbiter.request`
- `dut.u_arbiter.grant`
- `dut.u_arbiter.grant_id`
- `dut.u_data_mem.mem[0]`
- `dut.u_data_mem.mem[1]`
- `retired_count`
- `mem_stall_count`
- `load_use_stall_count`
- `flush_count`

## 10. Cach Giai Thich Truoc Thay

Co the trinh bay theo thu tu nay:

### Buoc 1: Gioi thieu bai toan

"Em xay dung mot he thong CPU RISC-V 8 loi bang Verilog. Ban dau core co the la multi-cycle, sau do em phat trien thanh pipeline 5 tang. Muc tieu la mo phong qua trinh nhieu core cung thuc thi lenh va tranh chap RAM dung chung."

### Buoc 2: Noi ve RISC-V

"RISC-V la kien truc load/store, cac phep toan ALU lam viec tren register, con truy cap bo nho chi qua `LW` va `SW`. Trong project, em ho tro mot tap con RV32I gom ALU, load/store, branch, jump va U-type."

### Buoc 3: Noi ve pipeline

"Moi core duoc chia thanh 5 tang: IF, ID, EX, MEM, WB. Nhieu lenh co the cung nam trong pipeline o cac tang khac nhau, nen thong luong tot hon multi-cycle."

### Buoc 4: Noi ve hazard

"Pipeline sinh ra hazard. Em xu ly data hazard bang forwarding va writeback bypass, load-use hazard bang stall, control hazard bang flush, va structural hazard cua RAM dung chung bang bus controller voi arbiter."

### Buoc 5: Noi ve 8 core

"Top-level khoi tao 8 instance cua `risc_core`. Moi core co instruction memory rieng nhung dung chung data memory. Khi core can doc/ghi RAM, no gui request ra bus. Arbiter Round-Robin cap quyen cho tung core, bus controller dua giao dich vao RAM va tra `mem_ready`."

### Buoc 6: Noi ve chuong trinh test

"Chuong trinh 8 core rat ngan: moi core ghi 42 vao `mem[0]`, doc lai, roi ghi marker 99 vao `mem[1]`. Neu sau mo phong `mem[0] = 42` va `mem[1] = 99`, chung to 8 core da chay, bus/RAM hoat dong, va he thong khong deadlock."

### Buoc 7: Dua bang chung

"Testbench in ra `TONG KET: 10 PASSED, 0 FAILED`. Ngoai ra moi core deu co `grant` va `retired`, chung to moi core deu duoc cap bus va co lenh duoc commit. Cac counter `mem_stall`, `load_use_stall`, `flush` la bang chung pipeline that su co co che stall/flush."

## 11. De Xuat Cau Truc Bao Cao

### Chuong 1: Gioi Thieu

Noi dung:

- Ly do chon de tai.
- Muc tieu thiet ke CPU RISC-V 8 core.
- Pham vi de tai: mo phong RTL, pipeline 5 tang, shared memory, arbiter.

### Chuong 2: Co So Ly Thuyet

Noi dung:

- Tong quan RISC-V.
- Tap lenh RV32I subset.
- Kien truc datapath CPU.
- Pipeline 5 tang.
- Hazard: data, control, structural.
- He thong da loi va shared memory.
- Arbiter Round-Robin.

### Chuong 3: Thiet Ke He Thong

Noi dung:

- So do tong the 8 core.
- Giai thich `top_8core`.
- Giai thich mot core pipeline.
- Giai thich register file, ALU, control unit.
- Giai thich instruction memory va data memory.
- Giai thich bus controller va arbiter.

### Chuong 4: Thiet Ke Pipeline Core

Noi dung:

- Cac pipeline register: `if_id`, `id_ex`, `ex_mem`, `mem_wb`.
- Luong di chuyen cua lenh qua 5 tang.
- Forwarding.
- Load-use stall.
- Branch/jump flush.
- Memory stall khi doi bus.

### Chuong 5: Mo Phong Va Kiem Thu

Noi dung:

- Cong cu: Icarus Verilog, VVP, GTKWave.
- Test 1 core: muc tieu, chuong trinh, ket qua.
- Test 8 core: muc tieu, chuong trinh, ket qua.
- Bang ket qua pass/fail.
- Waveform minh hoa.

Bang ket qua goi y:

| Test | Muc tieu | Ket qua ky vong | Ket qua |
|---|---|---|---|
| `core_tb` | Kiem tra 1 core pipeline | Register/RAM dung, co stall/flush | PASS |
| `system_tb` | Kiem tra 8 core | `mem[0]=42`, `mem[1]=99`, khong deadlock | PASS |
| Pipeline counters | Chung minh pipeline hoat dong | Co retired/stall/flush | PASS |
| Bus grants | Chung minh 8 core truy cap RAM | Moi core grant > 0 | PASS |

### Chuong 6: Danh Gia Va Han Che

Da lam duoc:

- Mo phong CPU RISC-V 8 core.
- Chuyen core sang pipeline 5 tang.
- Co xu ly forwarding, stall, flush.
- Co shared memory va bus arbitration.
- Co testbench va waveform.
- Co bang chung terminal va VCD cho slide.

Han che:

- Chua co cache.
- Chua co cache coherence.
- Chua co interrupt/exception/CSR day du.
- Chua ho tro toan bo RISC-V ISA.
- Chua co assembler rieng, `.hex` van duoc viet san.
- Atomic LR/SC/AMO nen trinh bay la huong mo rong neu khong demo rieng.

### Chuong 7: Ket Luan

Ket luan goi y:

"De tai da xay dung va mo phong thanh cong he thong CPU RISC-V 8 loi theo kien truc pipeline 5 tang. Ket qua mo phong cho thay cac core co the cung thuc thi chuong trinh, truy cap RAM dung chung thong qua bus controller va arbiter, dong thoi pipeline co co che xu ly hazard nhu forwarding, stall va flush. He thong dat muc tieu minh hoa cac nguyen ly quan trong cua mon Kien truc may tinh: datapath, control, pipeline, bo nho dung chung va dieu phoi tai nguyen trong he thong da loi."

## 12. Goi Y Slide Trinh Bay

Slide 1: Ten de tai

- Mo phong CPU RISC-V 8 core pipeline 5 tang.
- Ten thanh vien/mon hoc.

Slide 2: Muc tieu

- Thiet ke CPU RISC-V.
- Chuyen sang pipeline.
- Mo phong 8 core dung chung RAM.
- Kiem chung bang Verilog testbench.

Slide 3: Tong quan RISC-V

- RV32I subset.
- Register file 32 thanh ghi.
- Load/store architecture.

Slide 4: Kien truc pipeline 5 tang

```text
IF -> ID -> EX -> MEM -> WB
```

Slide 5: Datapath mot core

- PC.
- Instruction memory.
- Control unit.
- Register file.
- ALU.
- Pipeline registers.

Slide 6: Hazard handling

- Forwarding.
- Load-use stall.
- Branch flush.
- Memory stall.

Slide 7: Kien truc 8 core

```text
8 pipeline cores -> bus_ctrl -> data_mem
                 -> arbiter
```

Slide 8: Arbiter va shared memory

- Round-Robin.
- `mem_req`.
- `grant`.
- `mem_ready`.

Slide 9: Chuong trinh test

```asm
addi x1, x0, 42
sw   x1, 0(x0)
lw   x2, 0(x0)
addi x3, x0, 99
sw   x3, 4(x0)
jal  x0, halt
```

Slide 10: Ket qua mo phong

- `mem[0] = 42`.
- `mem[1] = 99`.
- `TONG KET: 10 PASSED, 0 FAILED`.

Slide 11: Pipeline/bus evidence

- Bang `grant`, `retired`, `mem_stall`, `load_use_stall`, `flush`.
- Anh chup waveform.

Slide 12: Danh gia va huong phat trien

- Da hoan thanh pipeline 8 core.
- Han che: cache, coherence, interrupt, full ISA.
- Huong phat trien: cache, assembler, atomic tests, pipeline toi uu hon.

## 13. Cau Tra Loi Ngan Khi Thay Hoi

Hoi: "He thong cua em la multi-cycle hay pipeline?"

Tra loi: "Phien ban hien tai la pipeline 5 tang. Trong `risc_core.v`, em co cac pipeline register `if_id`, `id_ex`, `ex_mem`, `mem_wb`, khong con dung FSM 3 state fetch-execute-memory nhu multi-cycle."

Hoi: "Bang chung pipeline hoat dong la gi?"

Tra loi: "Testbench in counter `retired`, `mem_stall`, `load_use_stall`, `flush`. Ngoai ra waveform co the hien cac pipeline register valid qua tung cycle."

Hoi: "8 core co that su chay khong?"

Tra loi: "Co. `top_8core.v` generate 8 instance `risc_core`. Trong `system_tb`, moi core deu co `grant > 0` va `retired > 0`, chung to moi core co thuc thi lenh va tung truy cap shared memory."

Hoi: "Neu 8 core cung truy cap RAM thi co xung dot khong?"

Tra loi: "Co kha nang xung dot, nen he thong dung `arbiter` Round-Robin va `bus_ctrl`. Moi thoi diem chi mot core duoc grant vao RAM, cac core con lai doi va stall o MEM stage."

Hoi: "Tai sao `mem[0] = 42`, `mem[1] = 99` lai chung minh chay dung?"

Tra loi: "Vi chuong trinh test cua moi core bat buoc phai ghi 42, doc lai, roi ghi marker 99. Neu RAM cuoi mo phong co hai gia tri nay va testbench khong timeout, nghia la cac core da chay qua duong lenh memory va he thong khong deadlock."

Hoi: "Han che cua project la gi?"

Tra loi: "Day la mo hinh RTL phuc vu hoc tap. Em chua trien khai cache, cache coherence, interrupt/exception day du, CSR va full ISA. Cac phan do co the dua vao huong phat trien."

## 14. Checklist Truoc Khi Bao Cao

Truoc khi nop/trinh bay, nen lam:

- Chay `core_tb` va chup ket qua `SUMMARY: 7 PASSED, 0 FAILED`.
- Chay `system_tb` va chup ket qua `TONG KET: 10 PASSED, 0 FAILED`.
- Mo `system_tb.vcd` bang GTKWave.
- Chup waveform co `clk`, `pc`, pipeline valid, `mem_req`, `grant`, `mem_ready`.
- Chup man hinh bang `PIPELINE / BUS EVIDENCE`.
- Dua so do 8 core vao slide.
- Dua so do `IF -> ID -> EX -> MEM -> WB` vao slide.
- Ghi ro han che va huong phat trien de bao cao trong sang, khong bi hoi kho.

