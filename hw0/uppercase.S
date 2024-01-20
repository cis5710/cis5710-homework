        .section .data
input_string:   .asciz "Hello world!"


        
        .section .text
        .globl _start
_start:
        # Load the address of the input string into a0
        la a0, input_string

        # Your code here!
        
end_program:
        # jump here when you're done
        j end_program

