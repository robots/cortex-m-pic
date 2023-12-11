#include "platform.h"

#include <stdio.h>

#include "systime.h"
#include "led.h"

void test(void *arg)
{
	(void) arg;
//	while(1);
	return;
}

extern char __end_of_flash[];

int main(void)
{
	SystemInit();
	SystemCoreClockUpdate();

	RCC->IOPENR |= 0x2f;
	RCC->APBENR2 |= RCC_APBENR2_SYSCFGEN;

	systime_init();
	led_init();

	led_set(0, LED_3BLINK);	

	printf("ou yeah! %08x %08x\n", __end_of_flash, test);

	while (1) {
		systime_periodic();
		led_periodic();

	}
} 
