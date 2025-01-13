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

#[link_section = ".start"]
#[no_mangle]
pub fn _start() -> ! {
    // setup stack pointer sp
    unsafe {
        asm!(
        "li sp, 0x6000", // Load immediate value 0x6000 into sp
        options(nostack) // Indicate that this assembly does not use the stack
        );
    }
    main();
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

        wait_for_millis(500);

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
        let all_tiles = [Tile::Red, Tile::Orange, Tile::Yellow, Tile::Green, Tile::Blue, Tile::Purple];
        for tile in all_tiles {
            if (exclude.is_none() || exclude.unwrap() != tile) &&
                (exclude2.is_none() || exclude2.unwrap() != tile) {
                return tile
            }
        }
        Tile::Blue
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

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];
type TileGrid = [[Tile; GRID_WIDTH]; GRID_HEIGHT];
type MatchGrid = [[bool; GRID_WIDTH]; GRID_HEIGHT];

#[no_mangle]
pub fn main() -> ! {
    // frame buffer
    let mut screen: &mut FrameBuffer = unsafe { &mut *(MMAP_HDMI as *mut FrameBuffer) };

    // clear screen to white
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            write_byte(WHITE, &mut screen[y as usize][x as usize]);
        }
    }

    // game data structures
    let mut grid: TileGrid = [[Tile::Blue; GRID_WIDTH]; GRID_HEIGHT];
    let mut matches: [[bool; GRID_WIDTH]; GRID_HEIGHT] = [[false; GRID_WIDTH]; GRID_HEIGHT];
    let mut selected_x: usize = 3;
    let mut selected_y: usize = 3;
    let mut score: usize = 0;

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

    loop {
        let gamepad = UsbGamepadInput::from(unsafe {read_volatile(MMAP_USB)});

        // move cursor
        if gamepad.left() && selected_x > 0 {
            selected_x -= 1;
        }
        if gamepad.right() && selected_x < GRID_WIDTH-1 {
            selected_x += 1;
        }
        if gamepad.up() && selected_y > 0 {
            selected_y -= 1;
        }
        if gamepad.down() && selected_y < GRID_HEIGHT-1 {
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
        if gamepad.b() && selected_y < GRID_HEIGHT-1 {
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

        while check_matches(&grid, Some(&mut matches)) {
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
            if match_ymin > 0 {
                render_grid(&grid, &mut screen, selected_x, selected_y);

                // match was not in the top row, animate a region of falling tiles
                let minx = (match_xmin * TILE_SIZE) + X_MARGIN;
                let maxx = (match_xmax * TILE_SIZE) + X_MARGIN + TILE_SIZE;
                let miny = 0;
                let maxy = match_ymin * TILE_SIZE;
                let shift = ((match_ymax - match_ymin) + 1) * TILE_SIZE;
                for y_shift in 1..=shift {
                    for y in (miny..maxy).rev() {
                        for x in minx..maxx {
                            // TODO: animation is broken because we can't read from frame buffer...
                            screen[Y_MARGIN-1 + y + y_shift][x] = screen[Y_MARGIN-1 + y + y_shift - 1][x];
                        }
                    }
                    wait_for_millis(10);
                }
                wait_for_millis(500);
            }
            for y in 0..GRID_HEIGHT { // start at the bottom
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

        // Render the grid
        render_grid(&grid, &mut screen, selected_x, selected_y);
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

include!("../images/candies-8b.rs");

fn render_grid(grid: &TileGrid,
               screen: &mut FrameBuffer,
               selected_x: usize,
               selected_y: usize) {

    for y in 0..GRID_HEIGHT {
        for x in 0..GRID_WIDTH {
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
                        // screen[Y_MARGIN + py][X_MARGIN + px] = tile_pixels[ty][tx];
                        write_byte(tile_pixels[ty][tx], &mut screen[Y_MARGIN + py as usize][X_MARGIN + px as usize]);
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
                            if px < SCREEN_WIDTH && py < SCREEN_HEIGHT {
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
