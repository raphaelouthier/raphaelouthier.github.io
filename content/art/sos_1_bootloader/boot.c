/*********
 * Types *
 *********/

#include <stdint.h>

typedef uint8_t u8;
typedef uint32_t u32;
typedef volatile u32 *v32p;

/*************
 * Accessors *
 *************/

/* Read or write a register. */
#define REGR(adr) (*(v32p) (adr))
#define REGW(adr, val) (*(v32p) (adr) = (val))

/******
 * HW *
 ******/

/* Copy / exec start. */
#define START_ADDRESS 0x20000000
#define EXEC_ADDRESS 0x20000001

/* Read all GPIOs. */
#define GPIO_READ() REGR(0xd0000004)

/* Configure LED. */
#define LED_INI() \
	REGW(0x400140cc, 5); \
	REGW(0xd0000024, (1 << 25)); \

/* Set led high. */
#define LED_ON REGW(0xd0000014, (1 << 25))

/* Set led low. */
#define LED_OFF REGW(0xd0000018, (1 << 25))

/**************
 * Entrypoint *
 **************/

/*
 * Bootloader uses two GPIOs for control and four GPIOs f 
 */
int __attribute__((naked, section(".stage2"))) main() {


	/* Cache addresses. */
	void (*entry)(void) = (void *) EXEC_ADDRESS;
	uint8_t *dst = (void *) START_ADDRESS;

	/* Disable IO_BANK0 reset, wait for reset done. */ 
	REGW(0x4000c000, 0); 
	while (!(REGR(0x4000c008) & 0x10)); 

	/* Initialize the LED. */
	LED_INI();

	/* Copy loop. */
	uint32_t val;
	uint8_t byt = 0;
	uint8_t cnt = 0;
	while (1) {

		/* Turn off the led. */
		LED_OFF;

		/* Wait for capture assertion. */
		wait_for_capture:
		for (uint32_t i = 0; i < 1000; i++) {
			val = GPIO_READ();
			if (!(val & 1)) goto wait_for_capture; 
		}

		/* Turn on the led. */
		LED_ON;
		
		/* Capture nibble,
		 * incorporate in byte,
		 * write if required. */
		uint32_t nib = (val >> 2) & 0xf;
		if (!cnt) {
			byt = nib;
		} else {
			byt |= nib << 4;
			*(dst++) = byt;
			byt = 0;
		}
		cnt = !cnt;

		/* Wait for capture deassertion. */
		wait_for_0:;
		for (uint32_t i = 0; i < 1000; i++) {
			val = GPIO_READ();
			if (val & 1) goto wait_for_0; 
		}

		/* If execution is asserted for
		 * that 1000 cycles, execute.
		 * Keep LED on. */
		if (val & 2) {
			for (uint32_t i = 0; i < 1000; i++) {
				val = GPIO_READ();
				if (!(val & 2)) goto exec_deasserted; 
			}
			goto exec;
		}
		exec_deasserted:;

	}

	exec:;
	(*(entry))();
	while(1);

}
