#![no_std]
#![no_main]

use core::arch::asm;
use core::hint;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

use bitfield_struct::bitfield;

const MMAP_LEDS: *mut u8 = 0xFF002000 as *mut u8;
const MMAP_BUTTONS: *const u8 = 0xFF001000 as *const u8;

#[bitfield(u8, debug = false, defmt = false)]
struct BoardButtonInput {
    /// The first field occupies the least-significant bit
    /// Booleans are 1 bit in size
    pwr: bool,
    b1: bool,
    b2: bool,
    b3: bool,
    b4: bool,
    b5: bool,
    b6: bool,
    _unused: bool,
}

#[bitfield(u8, debug = false, defmt = false)]
struct LedOutput {
    /// The first field occupies the least-significant bit
    /// Booleans are 1 bit in size
    d0: bool,
    d1: bool,
    d2: bool,
    d3: bool,
    d4: bool,
    d5: bool,
    d6: bool,
    d7: bool,
}

// const STACK_START: u32 = 0xFFFF_1EFC;
const STACK_START: u32 = 0xFFFF_FFFC;

#[link_section = ".start"]
#[no_mangle]
pub fn _start() -> ! {
    // setup stack pointer sp. NB: stack grows down (to smaller addresses)
    unsafe {
        asm!(
        "mv sp, {0}",
        in(reg) STACK_START
        );
    }

    main();
}

fn wait_for_millis(millis: usize) {
    let freq_mhz = 4_000_000; // NB: adjust for actual clock frequency
    let ns_per_sec = 1_000_000_000;
    let ns_per_clock = ns_per_sec / freq_mhz;
    // Note: there are 3 insns (~3 cycles) per loop iteration
    let ns_per_iteration = ns_per_clock * 3;
    let delay_ns = millis * 1_000_000;
    for _ in 0..(delay_ns / ns_per_iteration) {
        hint::spin_loop();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    // if code panics, flash all LEDs on and off
    loop {
        unsafe {
            write_volatile(MMAP_LEDS, 0xFF);
        }
        wait_for_millis(500);
        unsafe {
            write_volatile(MMAP_LEDS, 0x00);
        }
        wait_for_millis(500);
    }
}

#[no_mangle]
pub fn main() -> ! {
    let mut level = 1;
    let mut led_value: u8 = 1;
    let mut moving_left: bool = false;

    loop {
        let interval_millis = 300 - (level*35);
        unsafe { write_volatile( MMAP_LEDS, led_value); }
        let button_start = BoardButtonInput::from(unsafe { read_volatile(MMAP_BUTTONS) });
        wait_for_millis(interval_millis);

        let button_end = BoardButtonInput::from(unsafe { read_volatile(MMAP_BUTTONS) });
        if !button_start.b2() && button_end.b2() { // user pressed the button during the interval
            if led_value == 1 {
                // go to next level
                level += 1;
                unsafe { write_volatile( MMAP_LEDS, led_value | 0x80); }
                wait_for_millis(250);
                unsafe { write_volatile( MMAP_LEDS, led_value); }
            } else {
                // game over, flash all LEDs on and off
                loop {
                    unsafe {
                        write_volatile(MMAP_LEDS, 0xFF);
                    }
                    wait_for_millis(100);
                    unsafe {
                        write_volatile(MMAP_LEDS, 0x00);
                    }
                    wait_for_millis(100);
                }
            }
        }
        if led_value == 128 || led_value == 1 {
            moving_left = !moving_left;
        }
        if moving_left {
            led_value <<= 1;
        } else {
            led_value >>= 1;
        }
    } // end main loop
}
