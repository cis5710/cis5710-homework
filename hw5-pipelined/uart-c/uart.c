#define MAX_LEN 128

//#include <string.h>
//define struct for input & output memory region
//typedef struct {
//    volatile int len;
//    volatile char string[MAX_LEN];
//} region_t;

// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
//volatile region_t* const INPUT  = (volatile region_t* const) 0xFF002000;
//volatile region_t* const OUTPUT = (volatile region_t* const) 0xFF001000;

// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
volatile char* const OUTPUT = (volatile char* const) 0xFF001000;
volatile char* const INPUT  = (volatile char* const) 0xFF002000;

/** Wait for approximately the desired numberof milliseconds, then return. */
void wait_for_millis(unsigned long millis) {
    const unsigned long freq_mhz = 20000000; // Adjust for actual clock frequency
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

    //char input_done = 'n';
    char new_char = 0;
    char old_char = 0;
    //int input_len = 0;
    //int output_len = 0;
    //char input[MAX_LEN]; //input string
    //for(int i = 0; i < MAX_LEN; i++) {
    //    input[i] = 0;
    //}

    while (1) {
        old_char = new_char;
        new_char = *INPUT;
        if(old_char != new_char) { //New character posedge
            *OUTPUT = new_char + 1;
            for (unsigned long i = 0; i < 1000000; i++) {
                __asm__ volatile ("nop");
            }
        }
        else {
            *OUTPUT = 0;
        }

        //if(new_char != 0 && new_char != '\n' && input_len < MAX_LEN) { //Input is not done
        //    wait_for_millis(100);
        //    *INPUT = 0;
        //    input[input_len] = new_char;
        //    input_len++;
        //    continue;
        //}
        //if(new_char == '\n' && output_len < input_len) { //Input is done
        //    *OUTPUT = input[output_len];
        //    output_len++;
        //    continue;
        //}   
        //if(new_char == '\n' && output_len == input_len) { //Output is done
        //    *OUTPUT = '\n';
        //    *INPUT = 0;
        //    input_len = 0;
        //    output_len = 0;
        //    continue;
        //}
    } 
}
