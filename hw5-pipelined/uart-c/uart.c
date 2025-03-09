#define MAX_LEN 128

//define struct for input & output memory region
//typedef struct {
//    volatile int len;
//    volatile char string[MAX_LEN];
//} region_t;

// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
//volatile region_t* const INPUT  = (volatile region_t* const) 0xFF002000;
//volatile region_t* const OUTPUT = (volatile region_t* const) 0xFF001000;

// memory-mapped device addresses are volatile so the compiler doesn't register-allocate them
volatile char* const OUTPUT = (volatile char* const) 0xFF002000;
volatile char* const INPUT  = (volatile char* const) 0xFF001000;

/** Wait for approximately the desired numberof milliseconds, then return. */
//void wait_for_millis(unsigned long millis) {
//    const unsigned long freq_mhz = 4000000; // Adjust for actual clock frequency
//    const unsigned long ns_per_sec = 1000000000;
//    const unsigned long ns_per_clock = ns_per_sec / freq_mhz;
//    // Note: there are 3 instructions (~3 cycles) per loop iteration
//    const unsigned long ns_per_iteration = ns_per_clock * 3;
//    const unsigned long delay_ns = millis * 1000000;
//    for (unsigned long i = 0; i < (delay_ns / ns_per_iteration); i++) {
//        __asm__ volatile ("nop");
//    }
//}

// ensure _start() is at address 0x0, the datapath's starting PC
void _start() __attribute__((section(".start"))) __attribute__((naked));
void _start() {
    // setup stack pointer sp. NB: stack grows down (to smaller addresses)
    asm volatile ("li sp, 0xFFFFFFFC");

    char input_done = 'n';
    char first_char = '\0';
    int input_len = 0;
    char input[128]; //input string

    int output_len = 0;
    char output[128]; //output string

    //

    while (1) {
        //Input is not done
        if(input_done == 'n') {
            first_char = *INPUT;
            //You should modify the logic of uart_rx_data a little bit
            //We need to set it back to '\0' after setting it to input
            //Input is not done yet
            if(first_char != '\0') {
                input[input_len] = first_char;
                if(first_char == '\n') {
                    input_done = 'y'; //When "enter" key is detected, input is done
                }
                else {
                    if(input_len < MAX_LEN - 1)
                        input_len++;
                    else if(input_len == MAX_LEN - 1) {
                        input_done = 'y'; //If the input hit the threshold, just end the input
                    }
                }
            }
            else {
                continue; //go back to the top of the loop and read again
            }
        }
        //Input is done
        else if(input_done == 'y') {
            //--------MODIFICATION OF THE INPUT DATA--------//
            output_len = input_len;
            for(int i = 0; i < output_len; i++) {
                output[i] = input[output_len - 1 - i]; //Reverse the input string
            }

            //Just to be safe, erase the value in the input array & input_len
            for(int i = 0; i < input_len; i++) {
                input[i] = '\0';
            }
            input_len = 0;

            //--------SEND THE MODIFIED DATA TO OUTPUT--------//
            int index = 0;
            while(1) {
                //Hardware needs to set "\0"
                if(*OUTPUT == '\0' && index < output_len) {
                    *OUTPUT = output[index];
                    index++;
                }
                else if(index == output_len) {
                    output_len = 0;
                    input_done = 'n';
                    for(int i = 0; i < output_len; i++) {
                        output[i] = '\0';
                    }
                    break;
                }
            }
        }
    } 
}
