#![no_std]
#![no_main]

use core::arch::asm;
use core::cmp::{max, min};
use core::hint;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

use bitfield_struct::bitfield;

const MMAP_LEDS: *mut u8      = 0xFF00_2000 as *mut u8;
#[allow(dead_code)]
const MMAP_BUTTONS: *const u8 = 0xFF00_1000 as *const u8;
const MMAP_USB: *const u16    = 0xFF00_4000 as *const u16;
const MMAP_RNG: *const u32    = 0xFF00_5000 as *const u32;
const MMAP_HDMI: *mut u8      = 0xFF10_0000 as *mut u8;

const FULL_SIZE: bool = true;

#[bitfield(u16, debug = false, defmt = false)]
struct UsbGamepadInput {
    /// The first field occupies the least-significant bit
    /// Booleans are 1 bit in size
    start: bool,
    select: bool,
    y: bool,
    x: bool,
    b: bool,
    a: bool,
    down: bool,
    up: bool,
    right: bool,
    left: bool,
    #[bits(6)]
    _unused: usize,
}

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
const BG_COLOR: u8 = 0b101_110_11; // light blue

const PADDLE_ROW: usize = SCREEN_HEIGHT - 10;
const BALL_DIAMETER: usize = 8;
const PADDLE_WIDTH: usize = 32;
const PADDLE_MOVEMENT: usize = 3;

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];

struct Ball {
    x: usize,
    y: usize,
    dx: isize,
    dy: isize,
}
impl Ball {
    fn new(x: usize, y: usize, dx: isize, dy: isize) -> Self {
        Ball { x, y, dx, dy }
    }
}

#[no_mangle]
pub fn main() -> ! {
    // stack_check();
    // frame buffer
    let screen: &mut FrameBuffer = unsafe { &mut *(MMAP_HDMI as *mut FrameBuffer) };

    // clear screen
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            write_byte(BG_COLOR, &mut screen[y as usize][x as usize]);
        }
    }

    // game data structures
    let mut paddle_start_x = 2;
    let mut new_paddle_start_x = paddle_start_x;

    let mut ball = Ball::new(10, 10, 2, -2);
    let mut ball_color: u8 = BLACK;

    for i in paddle_start_x..paddle_start_x + PADDLE_WIDTH {
        write_byte(BLACK, &mut screen[PADDLE_ROW][i]);
    }

    loop {
        // move paddle
        let gamepad_now = UsbGamepadInput::from(unsafe { read_volatile(MMAP_USB) });
        if gamepad_now.left() && paddle_start_x > PADDLE_MOVEMENT {
            new_paddle_start_x -= PADDLE_MOVEMENT;
        }
        if gamepad_now.right() && paddle_start_x + PADDLE_MOVEMENT + PADDLE_WIDTH < SCREEN_WIDTH {
            new_paddle_start_x += PADDLE_MOVEMENT;
        }

        // draw the paddle
        if new_paddle_start_x < paddle_start_x {
            // moved left
            for i in 0..PADDLE_MOVEMENT {
                write_byte(BLACK, &mut screen[PADDLE_ROW][new_paddle_start_x + i]);
                write_byte(
                    BG_COLOR,
                    &mut screen[PADDLE_ROW][paddle_start_x + PADDLE_WIDTH - 1 + i],
                );
            }
        } else if new_paddle_start_x > paddle_start_x {
            // moved right
            for i in 0..PADDLE_MOVEMENT {
                write_byte(
                    BLACK,
                    &mut screen[PADDLE_ROW][new_paddle_start_x + PADDLE_WIDTH - 1 + i],
                );
                write_byte(BG_COLOR, &mut screen[PADDLE_ROW][paddle_start_x + i]);
            }
        }
        paddle_start_x = new_paddle_start_x;

        // erase ball
        draw_ball(BG_COLOR, &ball, screen);

        // move ball
        ball.x = (ball.x as isize + ball.dx) as usize;
        ball.y = (ball.y as isize + ball.dy) as usize;

        // Check for collisions with the walls and reverse direction if needed
        if ball.x == 0 || ball.x + BALL_DIAMETER >= SCREEN_WIDTH {
            ball.dx = -ball.dx;
            ball_color = unsafe { read_volatile(MMAP_RNG) } as u8;
        }
        let hit_paddle = ball.x + 1 >= paddle_start_x
            && ball.x <= paddle_start_x + PADDLE_WIDTH
            && ball.y + BALL_DIAMETER == PADDLE_ROW;
        if ball.y == 0 || hit_paddle {
            ball.dy = -ball.dy;
            ball_color = unsafe { read_volatile(MMAP_RNG) } as u8;
        }

        // draw new ball position
        draw_ball(ball_color, &ball, screen);

        if ball.y + BALL_DIAMETER >= SCREEN_HEIGHT {
            // ball hit the ground, we lost
            draw_ball(RED, &ball, screen);
            panic!();
        }

        wait_for_millis(30);
    } // end main loop
}

fn draw_ball(color: u8, ball: &Ball, screen: &mut FrameBuffer) {
    stack_check();

    for i in 0..BALL_DIAMETER {
        for j in 0..BALL_DIAMETER {
            let x = ball.x + i;
            let y = ball.y + j;
            if x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT {
                write_byte(color, &mut screen[y as usize][x as usize]);
            }
        }
    }
}
