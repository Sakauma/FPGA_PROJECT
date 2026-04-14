#设置器件型号 xc7z035ffg676-2 xc7z045ffg900-2  xc7k325tffg900-2 xc7k410tffg900-2
set device_model xc7k325tffg900-2
#设置工程创建位置
set dev_dir [pwd]
#确保切换到了工程位置
cd $dev_dir
puts "The home_dir is $dev_dir now!"
#创建工程
create_project 00_PRJ $dev_dir -part $device_model
#set_property board_part milianke:dev_zynq:part0:1.2 [current_project] 米联客搞得不知道干啥
set_property simulator_language Verilog [current_project]

#设置当前仿真工具为modelsim
set obj [current_project]
set_property -name "compxlib.modelsim_compiled_library_dir" -value "C:/modelsim_vivado2020_2_lib" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "target_simulator" -value "ModelSim" -objects $obj

#导入文件
#add_files -norecurse define_sel.vh
#source vivado_add_file_relative.tcl
#source vivado_bd_file_relative.tcl

#设置工程属性，以及导入xdc文件，xdc文件属性，仿真文件属性
#source vivado_prj_status.tcl
