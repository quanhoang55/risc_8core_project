@echo off
echo === Bien dich RISC-V 8-Core System ===

:: Chuyển về thư mục root của project
cd /d "%~dp0\.."

:: Xóa các file cũ nếu có
if exist tb\system_test.vvp del /f /q tb\system_test.vvp
if exist tb\system_tb.vcd del /f /q tb\system_tb.vcd

:: Chạy iverilog để biên dịch tất cả mã nguồn RTL và Testbench (Liệt kê rõ từng file để tránh lỗi wildcard trên Windows CMD)
iverilog -g2012 -o tb\system_test.vvp -I rtl\core -I rtl\interconnect -I rtl\memory rtl\core\alu.v rtl\core\control_unit.v rtl\core\pc_logic.v rtl\core\reg_file.v rtl\core\risc_core.v rtl\core\hazard_controller.v rtl\core\pipeline_register\if_id.v rtl\core\pipeline_register\id_ex.v rtl\core\pipeline_register\ex_mem.v rtl\core\pipeline_register\mem_wb.v rtl\memory\data_mem.v rtl\memory\instr_mem.v rtl\interconnect\arbiter.v rtl\interconnect\bus_ctrl.v rtl\top_8core.v tb\system_tb.v

if %ERRORLEVEL% EQU 0 (
    echo Bien dich thanh cong! Dang chay mo phong...
    echo ==================================================
    cd tb
    vvp system_test.vvp
    echo ==================================================
    echo Hoan tat! Ban co the xem file song bang lenh: gtkwave system_tb.vcd
) else (
    echo Bien dich that bai! Hay kiem tra lai ma nguon.
)
pause
