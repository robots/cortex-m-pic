#include "platform.h"

#include <stdio.h>

#define FLASH_ORIGIN ((uint32_t)0x08000000)
#define APP_OFFSET  ((uint32_t)0x00002000)

typedef  void (*pFunction)(void);

int main(void)
{
	SystemInit();
	SystemCoreClockUpdate();

//	initialise_monitor_handles();

	RCC->IOPENR |= 0x2f;
	RCC->APBENR2 |= RCC_APBENR2_SYSCFGEN;

//	printf("Ahoj\n");

	uint32_t stak;

	/* Check if valid stack address (RAM address) then jump to user application */
	stak = *(volatile uint32_t*)(FLASH_ORIGIN+APP_OFFSET);

	printf("Stack: %08lx\n", stak);

	if ((stak & 0x2FFE0000 ) == 0x20000000) {
		uint32_t JumpAddress = *(volatile uint32_t*) (FLASH_ORIGIN+APP_OFFSET + 4);

	//	printf("Stack is valid\n");
	//	printf("Entry point is: %08lx\n", JumpAddress);
	//	printf("Offset is %08lx\n", APP_OFFSET);

		JumpAddress += APP_OFFSET;

		printf("New entry point: %08lx\n", JumpAddress);

		/* Jump to user application */
		pFunction Jump_To_Application = (pFunction) JumpAddress;

		/* Initialize user application's Stack Pointer */
		__set_MSP(stak);

		Jump_To_Application();
	}

	printf("Stack is not valid\n");

	while (1) {
	}
} 
