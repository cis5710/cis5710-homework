#![no_std]
#![no_main]

use core::arch::asm;
use core::cmp::{max, min};
use core::hint;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

use bitfield_struct::bitfield;

const MMAP_LEDS: *mut u8 = 0xFF002000 as *mut u8;
#[allow(dead_code)]
const MMAP_BUTTONS: *const u8 = 0xFF001000 as *const u8;
const MMAP_HDMI: *mut u8 = 0xFF100000 as *mut u8;

const FULL_SIZE: bool = true;

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

// TOOD: reset doesn't work if we use 0xFFFF_FFFC...
const STACK_START: u32 = 0xFFFF_1EFC;
// const STACK_START: u32 = 0xFFFF_FFFC;

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

#[inline(never)]
fn stack_check() {
    let sp: u32;
    unsafe {
        asm!(
        "mv {0}, sp",
        out(reg) sp
        );
    }
    // NB: This is where .rodata data ends in memory. Compute this from `readelf -e` output
    if sp <= (STACK_START - 0x500) {
        unsafe {
            write_volatile(MMAP_LEDS, 0xAA);
        }
        panic!();
    }
}

fn write_byte(value: u8, address: *mut u8) {
    unsafe {
        write_volatile(address, value);
    }
}

fn wait_for_millis(millis: usize) {
    for _ in 0..(millis * 6000) {
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
        wait_for_millis(100);
        unsafe {
            write_volatile(MMAP_LEDS, 0x00);
        }
        wait_for_millis(100);
    }
}

const SCREEN_WIDTH: usize = if FULL_SIZE { 400 } else { 40 };
const SCREEN_HEIGHT: usize = if FULL_SIZE { 300 } else { 30 };
const BLACK: u8 = 0x00;
const WHITE: u8 = 0xFF;
const RED: u8 = 0b110_000_00;
const GREEN: u8 = 0b000_110_00;
const BG_COLOR: u8 = 0b101_110_11; // light blue

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];

// #[no_mangle]
// #[inline(never)]
// pub fn main_orig() -> ! {
//     write_byte(0xAA, MMAP_LEDS);
//     // stack_check();
//     // frame buffer
//     let screen: &mut FrameBuffer = unsafe { &mut *(MMAP_HDMI as *mut FrameBuffer) };
//
//     loop {
//         // clear screen
//         for y in 0..SCREEN_HEIGHT {
//             for x in 0..SCREEN_WIDTH {
//                 write_byte(RED, &mut screen[y as usize][x as usize]);
//             }
//         }
//
//         // tie button inputs to LEDs
//         let button_now = BoardButtonInput::from(unsafe { read_volatile(MMAP_BUTTONS) });
//         let button_bits = button_now.into_bits();
//         write_byte(button_bits, MMAP_LEDS);
//         // wait_for_millis(30);
//     } // end main loop
// }

#[no_mangle]
#[inline(never)]
pub fn main() -> ! {
    // stack_check();
    // frame buffer
    let screen: &mut FrameBuffer = unsafe { &mut *(MMAP_HDMI as *mut FrameBuffer) };
    let mut my_byte: u8 = 0x00;
    hint::black_box(my_byte);

    let ptr: *mut u8 = &mut my_byte;
    unsafe { write_volatile(ptr, 0xAA); }
    let g: u8 = unsafe { read_volatile(ptr) };

    loop { wait_for_millis(1000); }

    // loop {
    //     // // clear screen
    //     // for y in 0..SCREEN_HEIGHT {
    //     //     for x in 0..SCREEN_WIDTH {
    //     //         write_byte(GREEN, &mut screen[y as usize][x as usize]);
    //     //     }
    //     // }
    //     // write_byte(0x01, MMAP_LEDS);
    //
    //     let button_now = BoardButtonInput::from(unsafe { read_volatile(MMAP_BUTTONS) });
    //     if button_now.b1() {
    //         write_byte(0xAA, ptr);
    //     } else if button_now.b4() {
    //         let g: u8;
    //         unsafe { g = read_volatile(ptr); }
    //         write_byte(g, MMAP_LEDS);
    //     }
    // } // end main loop
}
