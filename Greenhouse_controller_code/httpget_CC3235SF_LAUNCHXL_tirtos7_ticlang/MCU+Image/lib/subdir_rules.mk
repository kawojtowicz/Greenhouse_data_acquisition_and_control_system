################################################################################
# Automatically-generated file. Do not edit!
################################################################################

SHELL = cmd.exe

# Each subdirectory must supply rules for building sources it contributes
lib/%.o: ../lib/%.c $(GEN_OPTS) | $(GEN_FILES) $(GEN_MISC_FILES)
	@echo 'Building file: "$<"'
	@echo 'Invoking: Arm Compiler'
	"C:/ti/ccs1281/ccs/tools/compiler/ti-cgt-armllvm_3.2.2.LTS/bin/tiarmclang.exe" -c -mcpu=cortex-m4 -mfloat-abi=soft -mfpu=none -mlittle-endian -mthumb -Oz -I"C:/Users/kawoj/greenhouse/httpget_CC3235SF_LAUNCHXL_tirtos7_ticlang" -I"C:/Users/kawoj/greenhouse/httpget_CC3235SF_LAUNCHXL_tirtos7_ticlang/MCU+Image" -I"C:/ti/simplelink_cc32xx_sdk_7_10_00_13/source" -I"C:/ti/simplelink_cc32xx_sdk_7_10_00_13/kernel/tirtos7/packages" -I"C:/ti/simplelink_cc32xx_sdk_7_10_00_13/source/ti/posix/ticlang" -DDeviceFamily_CC3220 -gdwarf-3 -march=armv7e-m -MMD -MP -MF"lib/$(basename $(<F)).d_raw" -MT"$(@)" -I"C:/Users/kawoj/greenhouse/httpget_CC3235SF_LAUNCHXL_tirtos7_ticlang/MCU+Image/syscfg"  $(GEN_OPTS__FLAG) -o"$@" "$<"
	@echo 'Finished building: "$<"'
	@echo ' '


