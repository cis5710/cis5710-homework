// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
volatile char* const GPIO    = (volatile char* const) 0xFF001000;
volatile char* const LEDS    = (volatile char* const) 0xFF002000;
volatile char* const BUTTONS = (volatile char* const) 0xFF003000;

void wait(const int amount) {
    // at 20 MHz, each iteration takes about 150ns
    for(int j = 0; j < amount; j++) { 
        __asm__ volatile ("nop");
    }
}

// ensure _start() is at address 0x0, the datapath's starting PC
void _start() __attribute__((section(".start"))) __attribute__((naked));
void _start() {
    // setup stack pointer sp. NB: stack grows down (to smaller addresses)
    asm volatile ("li sp, 0xFFFFFFFC");

    int led = -1;
    const int message = 53366;
    const int extra   = 4724;

    while (1) {
        *LEDS = led;
        led = ~led;

        int m = message;
        int e = extra;
        for (int i = 0; i < 17; i++) {
            wait(10000);
            *GPIO = 1;
            if (m & 0x01) {
                wait(30000);
            } else {
                wait(10000);
            }
            *GPIO = 0;
            if (e & 0x01) {
              wait(30000);
            }
            m >>= 1;
            e >>= 1;
        }
        wait(200000);
    }
}
