/*
 * Assembly initialization routines for bootstrapping PIC firmware images.
 *
 * v. 1.1 / 2022-01-15 / Janne Paalijarvi, StackLake Ltd / http://stacklake.fi/index.en.html
 *
 * This file contains assembly initialization routines to bootstrap firmware
 * images compiled with position independent code (PIC) options. Bootstrapping
 * needs to be done here in assembly because the PIC options would mess up the
 * C compilation. It is basically a chicken and egg problem.
 *
 * I'm proud to say these routines are portable between differnet core types
 * and have been tested with Cortex-M0 and Cortex-M4 successfully.
 *
 * Two core concepts are needed to be handled very carefully here. They are
 * the interrupt service routine (ISR) vector table and the global offset table
 * (GOT). These tables need to be copied from flash to RAM for access. Now
 * comes the twist. The firmware itself is compiled so that it expects to be
 * running from first flash address, namely 0x8000000. Nothing special is done
 * about it anywhere else. BUT actually the firmware may be running from
 * somewhere else. For example from 0x8005200.
 *
 * Now, if we did not do some special bootstrapping here, the offsetted
 * firmware would try to still look up things from 0x8000000. How to prevent
 * this? We copy the ISR and GOT tables to RAM. Then if we see in those tables
 * addresses that are trying to access flash, we add the offset (0x5200).
 *
 * The routines first store register values of firmware position data. These
 * values are set up by bootloader. Values are verified with a checksum. If
 * the checksum matches, we can be quite sure that the we are booting with via
 * the bootloader.
 *
 * Then the routine copies the GOT to RAM and while copying it patches
 * relevant addresses with the offset value we calculated. Basically if it
 * sees addresses of the flash range (0x8000000 -> flash end boundary), it
 * adds the offset.
 *
 * Basically the same thing is performed next to ISR vector table; offset
 * patching.
 *
 * Next we run routines of copying other initialization data from flash to RAM,
 * but also using the offset. We also zero memory ranges which are expected to
 * be zero, BUT we take special care not to zero the global variable locations
 * we used in the very beginning to store the data we got via bootloader in
 * registers.
 *
 * Then we call the C initialization function SystemInit() which normally sets
 * up clocks and does some other necessary initializations. SystemInit() also,
 * on platforms having the vector table offset (VTOR) register, sets to VTOR
 * register to point it to right location. This happens at least on Cortex-M4.
 * On platforms not having VTOR (for example Cortex-M0) other means can be
 * used to emulate the functionality.
 *
 * Next there is the curious case of __libc_init_array . This is a C library
 * initialization assembly function. The original version would call functions
 * from an array in flash. However as the firmware image running now might be
 * relacated with an offset, we need to add an offset also.
 * NOTE: I have not extensively verified that this part would function in ALL
 * cases. It could be that the functions being called might have dependencies
 * to locations needing patching. So keep this in mind if you plan to use this
 * code.
 *
 * After __libc_init_array we are basically done with bootstrap and the
 * "calling" platform-specific startup file usually proceeds to call the actual
 * main() of the compiled binary.
 */


.syntax unified
.cpu cortex-m0plus
.fpu softvfp
.thumb

.global gu32FirmwareOffset
.global gu32FirmwareAbsPosition
.global gu32RamVectorTableBegin
.global Reset_Handler

.bss
.align  4
gu32FirmwareOffset:    .long 0
gu32FirmwareAbsPosition: .long 0
gu32RamVectorTableBegin: .long 0

  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
Reset_Handler:
	mov r2, pc
	ldr r7, =Reset_Handler
	subs r7, r2, r7 // subtract stored pc and reset_handler address
	subs r7, r7, 3 // adjust for instruction size

  ldr   r0, =__stack_end
  mov   sp, r0          /* set stack pointer */

  // store firmware offset 
  ldr r2, =gu32FirmwareOffset
  str r7, [r2]

  // calculate absolute position of firmware
  ldr r1, =__flash_begin;
	adds r1, r1, r7
  ldr r2, =gu32FirmwareAbsPosition
  str r1, [r2]

  // Store vector table RAM being address dynamically so systemconfig can map it
  ldr r7, =__ram_vector_table_begin
  ldr r2, =gu32RamVectorTableBegin
  str r7, [r2]



  // GOT needs to be in RAM in every case
GlobalOffsetTableCopyPatchInit:
  movs r0, #0 // Loop variable
  movs r1, #0 // Pointer (just introduction)

GlobalOffsetTableCopyPatchLoopCond:
  ldr r2, =__flash_global_offset_table_begin // Need global offset table table beginning for pointer
  ldr r3, =__flash_global_offset_table_end // And need end for checking loop
  ldr r4, =gu32FirmwareOffset // Need also data offset variable address
  ldr r4, [r4] // And the actual offset value
  adds r2, r2, r4 // Patching flash global offset table begin to honour offset
  adds r3, r3, r4 // Patching flash global offset table end to honour offset
  adds r1, r0, r2 // Pointer value is loop variable + offsetted flash global offset table begin
  cmp r1, r3 // Compare pointer against global offset table flash end
  bhs GlobalOffsetTableCopyPatchEnd // If getting past limits, go to end

GlobalOffsetTableCopyPatchLoopBody:
  ldr r2, [r1] // Load the actual data via pointer
  ldr r3, =__flash_begin // Need flash begin boundary for checking
  ldr r4, =__flash_end // Need also flash end boundary for checking
  cmp r2, r3 // Comparing loaded data to flash begin
  blo GlobalOffsetTableStoreData // If less than flash begin, jump to store
  cmp r2, r4 // Comparing loaded data to flash end
  bhs GlobalOffsetTableStoreData // If more than or equal to end, jump to store

GlobalOffsetTablePatchData:
  ldr r3, =gu32FirmwareOffset // Need data offset variable address
  ldr r3, [r3] // And then the actual data
  adds r2, r2, r3 // Patch the data

GlobalOffsetTableStoreData:
  ldr r3, =__ram_global_offset_table_begin // Get global offset table begin in ram for ram data pointer
  adds r3, r3, r0 // Add loop variable
  str r2, [r3] // Store the data

GlobalOffsetTableLoopIncrements:
  adds r0, r0, #4 // Increment loop
  b GlobalOffsetTableCopyPatchLoopCond // Jump to loop condition checking

GlobalOffsetTableCopyPatchEnd:
  ldr r0, =__ram_global_offset_table_begin
  mov r9, r0 // Stupid trick to put global offset table location to r9, for Cortex-M0


  // Need to copy and patch vector table in assembly so nobody comes to mess around
VectorTableCopyPatchInit:
  movs r0, #0 // Loop variable
  movs r1, #0 // Pointer (just introduction)

VectorTableCopyPatchLoopCond:
  ldr r2, =__flash_vector_table_begin // Need vector table beginning for pointer
  ldr r3, =__flash_vector_table_end // And need end for checking loop
  ldr r4, =gu32FirmwareOffset // Need also data offset variable address
  ldr r4, [r4] // And the actual offset value
  adds r2, r2, r4 // Patching flash vector table begin to honour offset
  adds r3, r3, r4 // Patching flash vector table end to honour offset
  adds r1, r0, r2 // Pointer value is loop variable + offsetted flash vector table begin
  cmp r1, r3 // Compare pointer against vector table flash end
  bhs VectorTableCopyPatchEnd // If getting past limits, go to end

VectorTableCopyPatchLoopBody:
  ldr r2, [r1] // Load the actual data via pointer
  ldr r3, =__flash_begin // Need flash begin boundary for checking
  ldr r4, =__flash_end // Need also flash end boundary for checking
  cmp r2, r3 // Comparing loaded data to flash begin
  blo VectorTableStoreData // If less than flash begin, jump to store
  cmp r2, r4 // Comparing loaded data to flash end
  bhs VectorTableStoreData // If more than or equal to end, jump to store

#VectorTablePatchData:
#  ldr r3, =gu32FirmwareOffset // Need data offset variable address
#  ldr r3, [r3] // And then the actual data
#  adds r2, r2, r3 // Patch the data

VectorTableStoreData:
  ldr r3, =__ram_vector_table_begin // Get vector table begin in ram for ram data pointer
  adds r3, r3, r0 // Add loop variable
  str r2, [r3] // Store the data

VectorTableLoopIncrements:
  adds r0, r0, #4 // Increment loop
  b VectorTableCopyPatchLoopCond // Jump to loop condition checking

VectorTableCopyPatchEnd:


  // Copy the data segment initializers from flash to SRAM.
  ldr r0, =__data_start
  ldr r1, =__data_end
  ldr r2, =__data_source
  ldr r7, =gu32FirmwareOffset // Load firmware offset variable address
  ldr r7, [r7] // Load the actual firmware offset variable data
  adds r2, r2, r7 // Patch the sidata location with offset
  movs r3, #0
  b LoopCopyDataInit

CopyDataInit:
  ldr r4, [r2, r3]
  str r4, [r0, r3]
  adds r3, r3, #4

LoopCopyDataInit:
  adds r4, r0, r3
  cmp r4, r1
  bcc CopyDataInit

  // Zero fill the bss segment.
  ldr r2, =__bss_start
  ldr r4, =__bss_end
  movs r3, #0
  b LoopFillZerobss

FillZerobss:
  // Here we need to check that we are not zeroing out addresses or needed symbols

  ldr r6, =gu32FirmwareAbsPosition // Load address of absolute firmware position variable
  cmp r2, r6 // Compare with what we are going to zero
  beq FillZerobssSkip // If we should skip zeroing, jump away

  ldr r6, =gu32FirmwareOffset // Load address of firmware offset variable
  cmp r2, r6 // Compare with what we are going to zero
  beq FillZerobssSkip // If we should skip zeroing, jump away

  ldr r6, =gu32RamVectorTableBegin // Vector table location in RAM
  cmp r2, r6 // Compare with what we are going to zero
  beq FillZerobssSkip // If we should skip zeroing, jump away

  str  r3, [r2] // If not escaped yet, make the store

FillZerobssSkip:
  adds r2, r2, #4

LoopFillZerobss:
  cmp r2, r4
  bcc FillZerobss


// patch relocations
  ldr r5, =gu32FirmwareOffset // Load address of firmware offset variable
	ldr r5, [r5] // load offset

	// the "best" way would be to get __end_of_flash from GOT
  ldr r2, =__end_of_flash // Load address of absolute firmware position variable
	adds r2, r2, r5 // add offset to __end_of_flash,
  ldr r6, [r2] // load relocation count

LoopRelocations:

	cmp r6, 0
	beq LoopRelocationsEnd

	adds r2, r2, 4 // next member of table

	ldr r3, [r2] // load address from table

	ldr r4, [r3]    // load value from ram 
	// TODO: check sanity of address: only addresses pointing to FLASH are to be relocated
	adds r4, r4, r5 // patch ram value
	str r4, [r3]    // put value back

	subs r6, r6, 1 // decrement
	b LoopRelocations

LoopRelocationsEnd:


  // Make our own __libc_init_array
CallPreinitsInit:
  ldr r7, =gu32FirmwareOffset
  ldr r7, [r7]
  ldr r0, =__preinit_array_start
  adds r0, r7
  ldr r1, =__preinit_array_end
  adds r1, r7

CallPreinitsLoopCond:
  cmp r0, r1
  beq CallPreinitsEnd// If same, it is at end, go away

CallPreinitsLoop:
  ldr r5, =__init_array_start
  ldr r4, =__init_array_end // Yes, order is funny to say the least
  ldr r3, [r0]
  push {r0, r1, r2, r3, r4, r5, r6, r7} // Save context because calling externals
  blx r3
  pop {r0, r1, r2, r3, r4, r5, r6, r7} // Retrieve context
  adds r0, r0, #4
  b CallPreinitsLoopCond

CallPreinitsEnd:

#  ldr r3, =_init
#  adds r3, r7
#  push {r0, r1, r2, r3, r4, r5, r6, r7} // Save context because calling externals
#  blx r3
#  pop {r0, r1, r2, r3, r4, r5, r6, r7} // Retrieve context

CallInitsInit:
  ldr r5, =__init_array_start
  adds r5, r7
  ldr r4, =__init_array_end
  adds r4, r7
  ldr r7, =gu32FirmwareOffset
  ldr r7, [r7]

CallInitsLoopCond:
  cmp r5, r4
  beq CallInitsEnd

CallInitsLoop:
  ldr r3, [r5]
  add r3, r3, r7
  push {r0, r1, r2, r3, r4, r5, r6, r7} // Save context because calling externals
  blx r3
  pop {r0, r1, r2, r3, r4, r5, r6, r7} // Retrieve context
  adds r5, r5, #4
  b CallInitsLoopCond

CallInitsEnd:

/* Call the application s entry point.*/
  bl main

LoopForever:
  b LoopForever

.size Reset_Handler, .-Reset_Handler
