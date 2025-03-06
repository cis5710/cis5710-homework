// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
volatile char * const LEDS = (volatile char * const) 0xFF002000;
volatile char* const BUTTONS = (volatile char * const) 0xFF001000;

/** Wait for approximately the desired numberof milliseconds, then return. */
void wait_for_millis(unsigned long millis) {
    const unsigned long freq_mhz = 4000000; // Adjust for actual clock frequency
    const unsigned long ns_per_sec = 1000000000;
    const unsigned long ns_per_clock = ns_per_sec / freq_mhz;
    // Note: there are 3 instructions (~3 cycles) per loop iteration
    const unsigned long ns_per_iteration = ns_per_clock * 3;
    const unsigned long delay_ns = millis * 1000000;
    for (unsigned long i = 0; i < (delay_ns / ns_per_iteration); i++) {
        __asm__ volatile ("nop");
    }
}

// ensure _start() is at address 0x0, the datapath's starting PC
void _start() __attribute__((section(".start"))) __attribute__((naked));
void _start() {
    // setup stack pointer sp. NB: stack grows down (to smaller addresses)
    asm volatile ("li sp, 0xFFFFFFFC");

    // game logic starts here
    int level = 1;
    char led_value = 1;
    char moving_left = 0;
    
    while (1) {
        int interval_millis = 300 - (level * 35);
        *LEDS = led_value;
        char button_start = *BUTTONS;
        wait_for_millis(interval_millis);

        char button_end = *BUTTONS;
        if (!(button_start & 0x04) && (button_end & 0x04)) {
            if (led_value == 1) {
                // go to next level
                level++;
                *LEDS = led_value | 0x80;
                wait_for_millis(250);
                *LEDS = led_value;
            } else {
                // game over, flash all LEDS
                while (1) {
                    *LEDS = 0xFF;
                    wait_for_millis(100);
                    *LEDS = 0;
                    wait_for_millis(100);
                }
            }
        }
        if (led_value == 128 || led_value == 1) {
            moving_left = !moving_left;
        }
        if (moving_left) {
            led_value <<= 1;
        } else {
            led_value >>= 1;
        }
    } // end game loop
}
