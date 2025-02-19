#![no_std]
#![no_main]

use core::arch::asm;
use core::cmp::{max, min};
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};
use core::hint;

use bitfield_struct::bitfield;

const MMAP_LEDS: *mut u8      = 0xFF002000 as *mut u8;
#[allow(dead_code)]
const MMAP_BUTTONS: *const u8 = 0xFF001000 as *const u8;
const MMAP_USB: *const u16    = 0xFF004000 as *const u16;
const MMAP_RNG: *const u32    = 0xFF005000 as *const u32;
const MMAP_HDMI: *mut u8      = 0xFF100000 as *mut u8;

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

// TOOD: reset doesn't work if we use 0xFFFF_FFFC...
const STACK_START: u32 = 0xFFFF_FFFC;
// const STACK_START: u32 = 0xFFFF_FEFC;
// const STACK_START: u32 = 0x7EFC;

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
    if sp <= (STACK_START - 0x1800) { // 6KB stack
        unsafe {
            write_volatile(MMAP_LEDS, 0xAA);
        }
        panic!();
    }
}

fn write_byte(value: u8, address: *mut u8) {
    unsafe { write_volatile(address, value); }
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

#[derive(Clone, Copy, PartialEq)]
enum Tile {
    Red,
    Orange,
    Yellow,
    Green,
    Blue,
    Purple,
}

impl Tile {
    fn random(exclude: Option<Tile>, exclude2: Option<Tile>) -> Tile {
        let mut tile;
        loop {
            let random = unsafe { read_volatile(MMAP_RNG) };
            tile = match random % 6 {
                0 => Tile::Red,
                1 => Tile::Orange,
                2 => Tile::Yellow,
                3 => Tile::Green,
                4 => Tile::Blue,
                _ => Tile::Purple,
            };
            if (exclude.is_none() || exclude.unwrap() != tile) &&
                (exclude2.is_none() || exclude2.unwrap() != tile) {
                return tile
            }
        }
    }
}

const SCREEN_WIDTH: usize = 320;
const SCREEN_HEIGHT: usize = 240;
const TILE_SIZE: usize = 32; // Each tile is 32x32 pixels
const GRID_WIDTH: usize = 6;
const GRID_HEIGHT: usize = 7;
const X_MARGIN: usize = 0;
const Y_MARGIN: usize = (SCREEN_HEIGHT - (TILE_SIZE * GRID_HEIGHT)) / 2;
const BLACK: u8 = 0x00;
const WHITE: u8 = 0xFF;
const INIT_COLOR: u8 = 0b101_110_11; // light blue

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];
type TileGrid = [[Tile; GRID_WIDTH]; GRID_HEIGHT];
type MatchGrid = [[bool; GRID_WIDTH]; GRID_HEIGHT];

#[no_mangle]
pub fn main() -> ! {
    stack_check();

    // frame buffer
    let mut screen: &mut FrameBuffer = unsafe { &mut *(MMAP_HDMI as *mut FrameBuffer) };

    unsafe { write_volatile(MMAP_LEDS, 1); }

    // clear screen
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            write_byte(INIT_COLOR, &mut screen[y as usize][x as usize]);
        }
    }

    unsafe { write_volatile(MMAP_LEDS, 2); }

    // game data structures
    let mut grid: TileGrid = [[Tile::Yellow; GRID_WIDTH]; GRID_HEIGHT];
    let mut matches: MatchGrid = [[false; GRID_WIDTH]; GRID_HEIGHT];
    let mut selected_x: usize = 3;
    let mut selected_y: usize = 3;
    let mut score: usize = 0;

    unsafe { write_volatile(MMAP_LEDS, 3); }

    // initialize grid
    for y in 0..GRID_HEIGHT {
        for x in 0..GRID_WIDTH {
            let mut above = None;
            let mut left = None;
            if y > 0 {
                above = Some(grid[y-1][x]);
            }
            if x > 0 {
                left = Some(grid[y][x-1]);
            }
            grid[y][x] = Tile::random(above, left);
        }
    }

    unsafe { write_volatile(MMAP_LEDS, 4); }

    let mut gamepad = UsbGamepadInput::from(0);
    let mut gamepad_prior = UsbGamepadInput::from(0);
    loop {
        // check for gamepad button presses
        let gamepad_now = UsbGamepadInput::from(unsafe {read_volatile(MMAP_USB)});
        if !gamepad_prior.up() && gamepad_now.up() {
            gamepad_prior.set_up(true);
        } else if gamepad_prior.up() && !gamepad_now.up() {
            gamepad_prior.set_up(false);
            gamepad.set_up(true); // record button press event
        }
        if !gamepad_prior.down() && gamepad_now.down() {
            gamepad_prior.set_down(true);
        } else if gamepad_prior.down() && !gamepad_now.down() {
            gamepad_prior.set_down(false);
            gamepad.set_down(true); // record button press event
        }
        if !gamepad_prior.left() && gamepad_now.left() {
            gamepad_prior.set_left(true);
        } else if gamepad_prior.left() && !gamepad_now.left() {
            gamepad_prior.set_left(false);
            gamepad.set_left(true); // record button press event
        }
        if !gamepad_prior.right() && gamepad_now.right() {
            gamepad_prior.set_right(true);
        } else if gamepad_prior.right() && !gamepad_now.right() {
            gamepad_prior.set_right(false);
            gamepad.set_right(true); // record button press event
        }
        if !gamepad_prior.x() && gamepad_now.x() {
            gamepad_prior.set_x(true);
        } else if gamepad_prior.x() && !gamepad_now.x() {
            gamepad_prior.set_x(false);
            gamepad.set_x(true); // record button press event
        }
        if !gamepad_prior.y() && gamepad_now.y() {
            gamepad_prior.set_y(true);
        } else if gamepad_prior.y() && !gamepad_now.y() {
            gamepad_prior.set_y(false);
            gamepad.set_y(true); // record button press event
        }
        if !gamepad_prior.a() && gamepad_now.a() {
            gamepad_prior.set_a(true);
        } else if gamepad_prior.a() && !gamepad_now.a() {
            gamepad_prior.set_a(false);
            gamepad.set_a(true); // record button press event
        }
        if !gamepad_prior.b() && gamepad_now.b() {
            gamepad_prior.set_b(true);
        } else if gamepad_prior.b() && !gamepad_now.b() {
            gamepad_prior.set_b(false);
            gamepad.set_b(true); // record button press event
        }

        unsafe { write_volatile(MMAP_LEDS, 5); }

        // move cursor
        if gamepad.left() && selected_x > 0 {
            gamepad.set_left(false); // clear button press event
            selected_x -= 1;
        }
        if gamepad.right() && selected_x < GRID_WIDTH-1 {
            gamepad.set_right(false); // clear button press event
            selected_x += 1;
        }
        if gamepad.up() && selected_y > 0 {
            gamepad.set_up(false); // clear button press event
            selected_y -= 1;
        }
        if gamepad.down() && selected_y < GRID_HEIGHT-1 {
            gamepad.set_down(false); // clear button press event
            selected_y += 1;
        }

        // swaps
        if gamepad.x() && selected_y > 0 {
            let orig_dst = grid[selected_y-1][selected_x];
            grid[selected_y-1][selected_x] = grid[selected_y][selected_x];
            grid[selected_y][selected_x] = orig_dst;
            if check_matches(&grid, None) {
                selected_y -= 1;
            } else {
                // undo move
                grid[selected_y][selected_x] = grid[selected_y-1][selected_x];
                grid[selected_y-1][selected_x] = orig_dst;
            }
        }
        if gamepad.y() && selected_x > 0 {
            let orig_dst = grid[selected_y][selected_x-1];
            grid[selected_y][selected_x-1] = grid[selected_y][selected_x];
            grid[selected_y][selected_x] = orig_dst;
            if check_matches(&grid, None) {
                selected_x -= 1;
            } else {
                // undo move
                grid[selected_y][selected_x] = grid[selected_y][selected_x-1];
                grid[selected_y][selected_x-1] = orig_dst;
            }
        }
        if gamepad.b() && selected_y < GRID_HEIGHT - 1 {
            let orig_dst = grid[selected_y+1][selected_x];
            grid[selected_y+1][selected_x] = grid[selected_y][selected_x];
            grid[selected_y][selected_x] = orig_dst;
            if check_matches(&grid, None) {
                selected_y += 1;
            } else {
                // undo move
                grid[selected_y][selected_x] = grid[selected_y+1][selected_x];
                grid[selected_y+1][selected_x] = orig_dst;
            }
        }
        if gamepad.a() && selected_x < GRID_WIDTH - 1 {
            let orig_dst = grid[selected_y][selected_x+1];
            grid[selected_y][selected_x+1] = grid[selected_y][selected_x];
            grid[selected_y][selected_x] = orig_dst;
            if check_matches(&grid, None) {
                selected_x += 1;
            } else {
                // undo move
                grid[selected_y][selected_x] = grid[selected_y][selected_x+1];
                grid[selected_y][selected_x+1] = orig_dst;
            }
        }

        unsafe { write_volatile(MMAP_LEDS, 6); }

        while check_matches(&grid, Some(&mut matches)) {
        // if check_matches(&grid, Some(&mut matches)) {
            let mut match_xmin: usize = GRID_WIDTH * 2;
            let mut match_xmax: usize = 0;
            let mut match_ymin: usize = GRID_HEIGHT * 2;
            let mut match_ymax: usize = 0;
            let mut num_tiles_matches: usize = 0;
            for y in 0..GRID_HEIGHT {
                for x in 0..GRID_WIDTH {
                    if matches[y][x] {
                        num_tiles_matches += 1;
                        match_xmin = min(match_xmin, x);
                        match_xmax = max(match_xmax, x);
                        match_ymin = min(match_ymin, y);
                        match_ymax = max(match_ymax, y);
                    }
                }
            }
            score += num_tiles_matches * num_tiles_matches * num_tiles_matches;
            // println!("score: {score} points");

            // TODO: animation is broken because we can't read from frame buffer...
            // if match_ymin > 0 {
            //     render_grid(&grid, &mut screen, selected_x, selected_y);
            //
            //     // match was not in the top row, animate a region of falling tiles
            //     let minx = (match_xmin * TILE_SIZE) + X_MARGIN;
            //     let maxx = (match_xmax * TILE_SIZE) + X_MARGIN + TILE_SIZE;
            //     let miny = 0;
            //     let maxy = match_ymin * TILE_SIZE;
            //     let shift = ((match_ymax - match_ymin) + 1) * TILE_SIZE;
            //     for y_shift in 1..=shift {
            //         for y in (miny..maxy).rev() {
            //             for x in minx..maxx {
            //                 screen[Y_MARGIN-1 + y + y_shift][x] = screen[Y_MARGIN-1 + y + y_shift - 1][x];
            //             }
            //         }
            //         wait_for_millis(10);
            //     }
            //     wait_for_millis(500);
            // }

            for y in 0..GRID_HEIGHT {
                for x in 0..GRID_WIDTH {
                    if matches[y][x] {
                        // slide this column down
                        for match_y in (1..=y).rev() {
                            grid[match_y][x] = grid[match_y - 1][x];
                        }
                        grid[0][x] = Tile::random(None, None);
                    }
                }
            }

            // clear matches
            for y in 0..GRID_HEIGHT {
                for x in 0..GRID_WIDTH {
                    matches[y][x] = false;
                }
            }
        }

        unsafe { write_volatile(MMAP_LEDS, 7); }

        // Render the grid
        render_grid(&grid, &mut screen, selected_x, selected_y);

        unsafe { write_volatile(MMAP_LEDS, 8); }

    } // end main loop
}

fn check_matches(grid: &TileGrid,
                 mut matches: Option<&mut MatchGrid>) -> bool {
    let mut found_match: bool = false;
    // Check horizontal matches
    for y in 0..GRID_HEIGHT {
        for x in 0..GRID_WIDTH - 2 {
            if grid[y][x] == grid[y][x + 1] && grid[y][x] == grid[y][x + 2] {
                found_match = true;
                if matches.is_some() {
                    matches.as_mut().unwrap()[y][x] = true;
                    matches.as_mut().unwrap()[y][x+1] = true;
                    matches.as_mut().unwrap()[y][x+2] = true;
                }
            }
        }
    }

    // Check vertical matches
    for x in 0..GRID_WIDTH {
        for y in 0..GRID_HEIGHT - 2 {
            if grid[y][x] == grid[y + 1][x] && grid[y][x] == grid[y + 2][x] {
                found_match = true;
                if matches.is_some() {
                    matches.as_mut().unwrap()[y][x] = true;
                    matches.as_mut().unwrap()[y+1][x] = true;
                    matches.as_mut().unwrap()[y+2][x] = true;
                }
            }
        }
    }

    found_match
}

include!("../../images/candies-8b.rs");

fn render_grid(grid: &TileGrid,
               screen: &mut FrameBuffer,
               selected_x: usize,
               selected_y: usize) {
    let draw_candies = true;

    for y in 0..GRID_HEIGHT {
        for x in 0..GRID_WIDTH {
            if draw_candies {
                let tile_pixels = match grid[y][x] {
                    Tile::Red => RED,
                    Tile::Orange => ORANGE,
                    Tile::Yellow => YELLOW,
                    Tile::Green => GREEN,
                    Tile::Blue => BLUE,
                    Tile::Purple => PURPLE,
                };
                for ty in 0..TILE_SIZE {
                    for tx in 0..TILE_SIZE {
                        let px = x * TILE_SIZE + tx;
                        let py = y * TILE_SIZE + ty;
                        if px < SCREEN_WIDTH && py < SCREEN_HEIGHT {
                            write_byte(tile_pixels[ty][tx], &mut screen[Y_MARGIN + py as usize][X_MARGIN + px as usize]);
                        }
                    }
                }
            } else {
                let color = match grid[y][x] {
                    Tile::Red => 0b111_000_00,
                    Tile::Orange => 0b111_101_00,
                    Tile::Yellow => 0b111_111_00,
                    Tile::Green => 0b000_111_00,
                    Tile::Blue => 0b000_000_11,
                    Tile::Purple => 0b100_000_10,
                    _ => BLACK,
                };
                for ty in 0..TILE_SIZE {
                    for tx in 0..TILE_SIZE {
                        let px = x * TILE_SIZE + tx;
                        let py = y * TILE_SIZE + ty;
                        if X_MARGIN + px < SCREEN_WIDTH && Y_MARGIN + py < SCREEN_HEIGHT {
                            write_byte(color, &mut screen[Y_MARGIN + py as usize][X_MARGIN + px as usize]);
                        }
                    }
                }
            }
            if y == selected_y && x == selected_x {
                // draw selection border
                for ty in 0..TILE_SIZE {
                    for tx in 0..TILE_SIZE {
                        if ty <= 2 || ty >= TILE_SIZE - 3 || tx <= 2 || tx >= TILE_SIZE - 3 {
                            let px = x * TILE_SIZE + tx;
                            let py = y * TILE_SIZE + ty;
                            if X_MARGIN + px < SCREEN_WIDTH && Y_MARGIN + py < SCREEN_HEIGHT {
                                // screen[Y_MARGIN + py][X_MARGIN + px] = BLACK;
                                write_byte(BLACK, &mut screen[Y_MARGIN + py as usize][X_MARGIN + px as usize]);
                            }
                        }
                    }
                }
            }
        }
    }
}
