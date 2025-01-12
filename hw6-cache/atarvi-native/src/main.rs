#![no_std]
#![no_main]

use core::panic::PanicInfo;
// use core::arch::asm;
use core::ptr::{read_volatile, write_volatile};
use core::hint;

use bitfield_struct::bitfield;

const MMAP_LEDS: *mut u8 = 0xFF002000 as *mut u8;

#[bitfield(u16, debug=false, defmt=false)]
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
    _unused: usize
}

#[bitfield(u8, debug=false, defmt=false)]
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
    _unused: bool
}

#[bitfield(u8, debug=false, defmt=false)]
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
    d7: bool
}

#[no_mangle]
pub fn _start() -> ! {
    // TODO: setup stack pointer sp
    main();
}

fn write_byte(value: u8, address: *mut u8) {
    unsafe { write_volatile(address, value); }
}

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

    fn update(&mut self, width: usize, height: usize) {
        // Update position
        self.x = (self.x as isize + self.dx) as usize;
        self.y = (self.y as isize + self.dy) as usize;

        // Check for collisions with the walls and reverse direction if needed
        if self.x == 0 || self.x + 2 >= width {
            self.dx = -self.dx;
        }
        if self.y == 0 || self.y + 2 >= height {
            self.dy = -self.dy;
        }
    }
}

#[no_mangle]
pub fn main() -> ! {
    let mmap_buttons = 0xFF001000 as *mut u8;
    let mmap_usb     = 0xFF004000 as *mut u16;
    let mmap_hdmi    = 0xFF100000 as *mut u8;
    const HDMI_COLS: usize = 40;
    const HDMI_ROWS: usize = 30;
    
    let screen: &mut [[u8; HDMI_COLS]; HDMI_ROWS] = unsafe { &mut *(mmap_hdmi as *mut [[u8; HDMI_COLS]; HDMI_ROWS]) };
    
    const WHITE: u8 = 0xFF;
    const BLACK: u8 = 0x00;
    const OTHER: u8 = 0x06;
    
    let mut ball = Ball::new(10, 10, 1, 1);
    let mut ball_color: u8 = BLACK;
    // set LEDs based on currently-pressed buttons
    // *leds = b_allbut0 | b_inv0;

    // clear screen
    for y in 0..HDMI_ROWS {
        for x in 0..HDMI_COLS {
            write_byte(WHITE, &mut screen[y as usize][x as usize]);
        }
    }

    loop {
        let buttons = BoardButtonInput::from(unsafe {read_volatile(mmap_buttons)});
        if buttons.b3() {
            ball_color += 1;
        } else if buttons.b4() {
            ball_color -= 1;
        }

        let gamepad = UsbGamepadInput::from(unsafe {read_volatile(mmap_usb)});
        if gamepad.up() {
            ball_color += 1;
        } else if gamepad.down() {
            ball_color -= 1;
        } else if gamepad.start() {
            ball_color = BLACK;
        }
        
        // erase ball
        if ball.dx != -1 || ball.dy != -1 {
            write_byte(WHITE, &mut screen[ball.y as usize][ball.x as usize]);
        }
        if ball.dx != 1 || ball.dy != -1 {
            write_byte(WHITE, &mut screen[ball.y as usize][ball.x+1 as usize]);
        }
        if ball.dx != -1 || ball.dy != 1 {
            write_byte(WHITE, &mut screen[ball.y+1 as usize][ball.x as usize]);
        }
        if ball.dx != 1 || ball.dy != 1 {
            write_byte(WHITE, &mut screen[ball.y+1 as usize][ball.x+1 as usize]);
        }

        // move ball
        ball.update(HDMI_COLS, HDMI_ROWS);

        // draw ball
        write_byte(ball_color, &mut screen[ball.y as usize][ball.x as usize]);
        write_byte(ball_color, &mut screen[ball.y as usize][ball.x+1 as usize]);
        write_byte(ball_color, &mut screen[ball.y+1 as usize][ball.x as usize]);
        write_byte(ball_color, &mut screen[ball.y+1 as usize][ball.x+1 as usize]);

        for _ in 0..200000 {
            hint::spin_loop();
        }
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {
        let all_on = LedOutput::new()
            .with_d0(true)
            .with_d1(true)
            .with_d2(true)
            .with_d3(true)
            .with_d4(true)
            .with_d5(true)
            .with_d6(true)
            .with_d7(true);
        unsafe { write_volatile(MMAP_LEDS, all_on.into()); }

        for _ in 0..1000000 {
            hint::spin_loop();
        }

        let all_off = LedOutput::new()
            .with_d0(false)
            .with_d1(false)
            .with_d2(false)
            .with_d3(false)
            .with_d4(false)
            .with_d5(false)
            .with_d6(false)
            .with_d7(false);
        unsafe { write_volatile(MMAP_LEDS, all_off.into()); }
    }
}