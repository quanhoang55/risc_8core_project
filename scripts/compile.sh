#!/bin/bash
# Script biên dịch và chạy mô phỏng Icarus Verilog

echo "=== Biên dịch RISC-V 8-Core System ==="

# Chuyển về thư mục root của project
cd "$(dirname "$0")/.."

# Xóa các file cũ nếu có
rm -f tb/system_test.vvp
rm -f tb/system_tb.vcd

# Chạy iverilog để biên dịch tất cả mã nguồn RTL và Testbench
iverilog -g2012 -o tb/system_test.vvp \
  -I rtl/core -I rtl/interconnect -I rtl/memory \
  rtl/core/alu.v \
  rtl/core/control_unit.v \
  rtl/core/pc_logic.v \
  rtl/core/reg_file.v \
  rtl/core/risc_core.v \
  rtl/core/hazard_controller.v \
  rtl/core/pipeline_register/if_id.v \
  rtl/core/pipeline_register/id_ex.v \
  rtl/core/pipeline_register/ex_mem.v \
  rtl/core/pipeline_register/mem_wb.v \
  rtl/memory/data_mem.v \
  rtl/memory/instr_mem.v \
  rtl/interconnect/arbiter.v \
  rtl/interconnect/bus_ctrl.v \
  rtl/top_8core.v \
  tb/system_tb.v

if [ $? -eq 0 ]; then
    echo "Biên dịch thành công! Đang chạy mô phỏng..."
    echo "=================================================="
    # Chạy mô phỏng bằng vvp
    cd tb
    vvp system_test.vvp
    echo "=================================================="
    echo "Hoàn tất! Bạn có thể xem file sóng bằng lệnh: gtkwave system_tb.vcd"
else
    echo "Biên dịch thất bại! Hãy kiểm tra lại mã nguồn."
fi
