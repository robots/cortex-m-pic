/**
 ******************************************************************************
 * @file      startup_stm32f10x_md.c
 * @author    MCD Application Team, modif. Martin Thomas
 * @version   V3.0.0-mthomas
 * @date      04/17/2009
 * @brief     STM32F10x Medium Density Devices vector table for GNU toolchain.
 *            This module performs:
 *                - Set the initial SP
 *                - Set the initial PC == Reset_Handler,
 *                - Set the vector table entries with the exceptions ISR address,
 *                - Branches to main in the C library (which eventually
 *                  calls main()).
 *            After Reset the Cortex-M3 processor is in Thread mode,
 *            priority is Privileged, and the Stack is set to Main.
 *******************************************************************************
 * @copy
 *
 * THE PRESENT FIRMWARE WHICH IS FOR GUIDANCE ONLY AIMS AT PROVIDING CUSTOMERS
 * WITH CODING INFORMATION REGARDING THEIR PRODUCTS IN ORDER FOR THEM TO SAVE
 * TIME. AS A RESULT, STMICROELECTRONICS SHALL NOT BE HELD LIABLE FOR ANY
 * DIRECT, INDIRECT OR CONSEQUENTIAL DAMAGES WITH RESPECT TO ANY CLAIMS ARISING
 * FROM THE CONTENT OF SUCH FIRMWARE AND/OR THE USE MADE BY CUSTOMERS OF THE
 * CODING INFORMATION CONTAINED HEREIN IN CONNECTION WITH THEIR PRODUCTS.
 *
 * <h2><center>&copy; COPYRIGHT 2009 STMicroelectronics</center></h2>
 */

/* Modified by Martin Thomas
   - to take VECT_TAB_RAM setting into account, also see the linker-script
   - to avoid warning "ISO C forbids initialization between function pointer and 'void *'".
   - added optional startup-delay to avoid unwanted operations while connecting with
     debugger/programmer
   - tested with the GNU arm-eabi toolchain as in CS G++ lite Q1/2009-161

	 Michal Demin:
	 - added FreeRTOS Hooks
	 - sbrk for newlib's allocator
*/

/* Includes ------------------------------------------------------------------*/
/* Private typedef -----------------------------------------------------------*/
/* Private typedef -----------------------------------------------------------*/
typedef void( *const intfunc )( void );

/* Private define ------------------------------------------------------------*/
#define WEAK __attribute__ ((weak))

extern char __stack_end[];

/* Private variables ---------------------------------------------------------*/

/* Private function prototypes -----------------------------------------------*/
extern void Reset_Handler(void);
extern int main(void);
void __Init_Data(void);
void Default_Handler(void);


/*******************************************************************************
*
*            Forward declaration of the default fault handlers.
*
*******************************************************************************/
//mthomas void WEAK Reset_Handler(void);
void WEAK NMI_Handler(void);
void WEAK HardFault_Handler(void);
void WEAK SVC_Handler(void);
void WEAK PendSV_Handler(void);
void WEAK SysTick_Handler(void);

void WEAK WWDG_IRQHandler(void);
void WEAK PVD_IRQHandler(void);
void WEAK RTC_TAMP_IRQHandler(void);
void WEAK FLASH_IRQHandler(void);
void WEAK RCC_IRQHandler(void);
void WEAK EXTI0_1_IRQHandler(void);
void WEAK EXTI2_3_IRQHandler(void);
void WEAK EXTI4_15_IRQHandler(void);
void WEAK DMA1_Channel1_IRQHandler(void);
void WEAK DMA1_Channel2_3_IRQHandler(void);
void WEAK DMA1_Ch4_5_DMAMUX1_OVR_IRQHandler(void);
void WEAK ADC1_IRQHandler(void);
void WEAK TIM1_BRK_UP_TRG_COM_IRQHandler(void);
void WEAK TIM1_CC_IRQHandler(void);
void WEAK TIM2_IRQHandler(void);
void WEAK TIM3_IRQHandler(void);
void WEAK LPTIM1_IRQHandler(void);
void WEAK LPTIM2_IRQHandler(void);
void WEAK TIM14_IRQHandler(void);
void WEAK TIM16_IRQHandler(void);
void WEAK TIM17_IRQHandler(void);
void WEAK I2C1_IRQHandler(void);
void WEAK I2C2_IRQHandler(void);
void WEAK SPI1_IRQHandler(void);
void WEAK SPI2_IRQHandler(void);
void WEAK USART1_IRQHandler(void);
void WEAK USART2_IRQHandler(void);
void WEAK LPUSART1_IRQHandler(void);


/* Private functions ---------------------------------------------------------*/
/******************************************************************************
*
* mthomas: If been built with VECT_TAB_RAM this creates two tables:
* (1) a minimal table (stack-pointer, reset-vector) used during startup
*     before relocation of the vector table using SCB_VTOR
* (2) a full table which is copied to RAM and used after vector relocation
*     (NVIC_SetVectorTable)
* If been built without VECT_TAB_RAM the following comment from STM is valid:
* The minimal vector table for a Cortex M3.  Note that the proper constructs
* must be placed on this to ensure that it ends up at physical address
* 0x0000.0000.
*
******************************************************************************/

__attribute__ ((section(".isr_vectors")))
void (* const g_pfnVectors[])(void) =
{
    (intfunc)((unsigned long)&__stack_end), /* The stack pointer after relocation */
    Reset_Handler,              /* Reset Handler */
    NMI_Handler,                /* NMI Handler */
    HardFault_Handler,          /* Hard Fault Handler */
    0,
    0,
    0,
    0,                          /* Reserved */
    0,                          /* Reserved */
    0,                          /* Reserved */
    0,                          /* Reserved */
		SVC_Handler,                /* SVCall Handler - RTOS HOOK */
    0,
    0,                          /* Reserved */
    PendSV_Handler,             /* PendSV Handler - RTOS HOOK */
    SysTick_Handler,            /* SysTick Handler - RTOS HOOK */

    /* External Interrupts */
    WWDG_IRQHandler,            /* Window Watchdog */
    PVD_IRQHandler,             /* PVD through EXTI Line detect */
    RTC_TAMP_IRQHandler,          /* Tamper */
    FLASH_IRQHandler,           /* Flash */
    RCC_IRQHandler,             /* RCC */
    EXTI0_1_IRQHandler,           /* EXTI Line 0 */
    EXTI2_3_IRQHandler,           /* EXTI Line 2 */
    EXTI4_15_IRQHandler,           /* EXTI Line 4 */
		0,
    DMA1_Channel1_IRQHandler,   /* DMA1 Channel 1 */
    DMA1_Channel2_3_IRQHandler,   /* DMA1 Channel 2 */
    DMA1_Ch4_5_DMAMUX1_OVR_IRQHandler,   /* DMA1 Channel 4 */
    ADC1_IRQHandler,          /* ADC1 & ADC2 */
    TIM1_BRK_UP_TRG_COM_IRQHandler,        /* TIM1 Break */
    TIM1_CC_IRQHandler,         /* TIM1 Capture Compare */
    TIM2_IRQHandler,            /* TIM2 */
    TIM3_IRQHandler,            /* TIM3 */
    LPTIM1_IRQHandler,            /* TIM2 */
    LPTIM2_IRQHandler,            /* TIM3 */
    TIM14_IRQHandler,            /* TIM2 */
		0,
    TIM16_IRQHandler,            /* TIM3 */
    TIM17_IRQHandler,            /* TIM3 */
    I2C1_IRQHandler,         /* I2C1 Event */
    I2C2_IRQHandler,         /* I2C2 Event */
    SPI1_IRQHandler,            /* SPI1 */
    SPI2_IRQHandler,            /* SPI2 */
    USART1_IRQHandler,          /* USART1 */
    USART2_IRQHandler,          /* USART2 */
    LPUSART1_IRQHandler,          /* USART3 */
    0,
};



/*******************************************************************************
*
* Provide weak aliases for each Exception handler to the Default_Handler.
* As they are weak aliases, any function with the same name will override
* this definition.
*
*******************************************************************************/
#pragma weak NMI_Handler = Default_Handler
#pragma weak HardFault_Handler = Default_Handler
#pragma weak MemManage_Handler = Default_Handler
#pragma weak SVC_Handler = Default_Handler
#pragma weak PendSV_Handler = Default_Handler
#pragma weak SysTick_Handler = Default_Handler
#pragma weak WWDG_IRQHandler = Default_Handler
#pragma weak PVD_IRQHandler = Default_Handler
#pragma weak RTC_TAMP_IRQHandler = Default_Handler
#pragma weak FLASH_IRQHandler = Default_Handler
#pragma weak RCC_IRQHandler = Default_Handler
#pragma weak EXTI0_1_IRQHandler = Default_Handler
#pragma weak EXTI2_3_IRQHandler = Default_Handler
#pragma weak EXTI4_15_IRQHandler = Default_Handler
#pragma weak DMA1_Channel1_IRQHandler = Default_Handler
#pragma weak DMA1_Channel2_3_IRQHandler = Default_Handler
#pragma weak DMA1_Ch4_5_DMAMUX1_OVR_IRQHandler = Default_Handler
#pragma weak ADC1_IRQHandler = Default_Handler
#pragma weak TIM1_BRK_UP_TRG_COM_IRQHandler = Default_Handler
#pragma weak TIM1_CC_IRQHandler = Default_Handler
#pragma weak TIM2_IRQHandler = Default_Handler
#pragma weak TIM3_IRQHandler = Default_Handler
#pragma weak LPTIM1_IRQHandler = Default_Handler
#pragma weak LPTIM2_IRQHandler = Default_Handler
#pragma weak TIM14_IRQHandler = Default_Handler
#pragma weak TIM16_IRQHandler = Default_Handler
#pragma weak TIM17_IRQHandler = Default_Handler
#pragma weak I2C1_IRQHandler = Default_Handler
#pragma weak I2C2_IRQHandler = Default_Handler
#pragma weak SPI1_IRQHandler = Default_Handler
#pragma weak SPI2_IRQHandler = Default_Handler
#pragma weak USART1_IRQHandler = Default_Handler
#pragma weak USART2_IRQHandler = Default_Handler
#pragma weak LPUSART1_IRQHandler = Default_Handler

/**
 * @brief  This is the code that gets called when the processor receives an
 *         unexpected interrupt.  This simply enters an infinite loop, preserving
 *         the system state for examination by a debugger.
 *
 * @param  None
 * @retval : None
*/

void Default_Handler(void)
{
  /* Go into an infinite loop. */
  while (1)
  {
  }
}
