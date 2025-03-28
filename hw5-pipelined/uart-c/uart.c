#define MAX_LEN 8
#define INTERVAL_BETWEEN_WRITE 333 //Hand-tune result, 333 is the magic number

// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
volatile char* const OUTPUT = (volatile char* const) 0xFF001000;
volatile char* const INPUT  = (volatile char* const) 0xFF002000;

// ensure _start() is at address 0x0, the datapath's starting PC
void _start() __attribute__((section(".start"))) __attribute__((naked));
void _start() {
    // setup stack pointer sp. NB: stack grows down (to smaller addresses)
    asm volatile ("li sp, 0xFFFFFFFC");

    //char input_done = 'n';
    char new_char = 0;
    //char old_char = 0;
    int input_len = 0;
    char buffer[MAX_LEN];
    for(int i = 0; i < MAX_LEN; i++) {
        buffer[i] = 0;
    }

    while (1) {
        if(input_len == MAX_LEN) {
            for(int i = MAX_LEN - 1; i >= 0; i--) {
                *OUTPUT = buffer[i];
                for(int j = 0; j < INTERVAL_BETWEEN_WRITE; j++) { 
                    __asm__ volatile ("nop");
                }
            }
            *OUTPUT = '\n';
            for(int j = 0; j < INTERVAL_BETWEEN_WRITE; j++) {
                    __asm__ volatile ("nop");
            }
            *OUTPUT = '\r';
            for(int j = 0; j < INTERVAL_BETWEEN_WRITE; j++) {
                    __asm__ volatile ("nop");
            }
            *OUTPUT = 0;
            input_len = 0;
            continue;
        }
        //old_char = new_char;
        new_char = *INPUT;
        if(new_char != 0) { //New character posedge
            for(int j = 0; j < INTERVAL_BETWEEN_WRITE; j++) {
                    __asm__ volatile ("nop");
            }
            *INPUT = 0;
            buffer[input_len] = new_char;
            input_len++;
        }
    } 
}
