#![no_std]
#![no_main]

use core::arch::asm;
use core::cmp::{max, min};
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};
use core::hint;
use ascii::AsciiStr;

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
const TITLE0_LOCATION: (usize,usize) = (210,Y_MARGIN + 32);
const TITLE1_LOCATION: (usize,usize) = (TITLE0_LOCATION.0,Y_MARGIN + 32 + 8);
const SCORE_LABEL_LOCATION: (usize,usize) = (TITLE0_LOCATION.0,TITLE1_LOCATION.1 + (3*8));
const SCORE_VALUE_LOCATION: (usize,usize) = (TITLE0_LOCATION.0,SCORE_LABEL_LOCATION.1 + 8);
const MOVE_SCORE0_LOCATION: (usize,usize) = (TITLE0_LOCATION.0,SCORE_VALUE_LOCATION.1 + 8);
const MOVE_SCORE1_LOCATION: (usize,usize) = (TITLE0_LOCATION.0 + 8,SCORE_VALUE_LOCATION.1 + 8);

const BLACK: u8 = 0x00;
const WHITE: u8 = 0xFF;
const BACKGROUND_COLOR: u8 = WHITE;
const CURSOR_COLOR: u8 = BLACK;

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];
type TileGrid = [[Tile; GRID_WIDTH]; GRID_HEIGHT];
type MatchGrid = [[bool; GRID_WIDTH]; GRID_HEIGHT];

#[no_mangle]
pub fn main() -> ! {
    stack_check();

    // frame buffer
    let mut screen: &mut FrameBuffer = unsafe { &mut *(MMAP_HDMI as *mut FrameBuffer) };

    // clear screen
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            write_byte(BACKGROUND_COLOR, &mut screen[y as usize][x as usize]);
        }
    }

    // render title
    render_text(" Welcome to", BLACK, &mut screen, TITLE0_LOCATION);
    render_text("Candy Crvsh!", BLACK, &mut screen, TITLE1_LOCATION);
    render_text("score:", BLACK, &mut screen, SCORE_LABEL_LOCATION);

    // game data structures
    let mut grid: TileGrid = [[Tile::Yellow; GRID_WIDTH]; GRID_HEIGHT];
    let mut matches: MatchGrid = [[false; GRID_WIDTH]; GRID_HEIGHT];
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

    let mut gamepad_prior = UsbGamepadInput::from(0);
    loop {
        let mut gamepad = UsbGamepadInput::from(0);

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
            let move_score = match num_tiles_matches {
                3 => 1,
                4 => 2,
                5 => 3,
                _ => 4,
            };
            score += move_score;

            // render grid with tiles swapped
            render_grid(&grid,
                        Some((selected_x,selected_y)),
                        (0,0),
                        (GRID_WIDTH,GRID_HEIGHT),
                        &mut screen,
                        (X_MARGIN, Y_MARGIN));

            // render move score
            let mut buffer = itoa::Buffer::new();
            let move_score_str = buffer.format(move_score);
            render_text("+", BLACK, &mut screen, MOVE_SCORE0_LOCATION);
            render_text(move_score_str, BLACK, &mut screen, MOVE_SCORE1_LOCATION);

            let y_shift = ((match_ymax - match_ymin) + 1) * TILE_SIZE;
            let fb_xmin = (match_xmin * TILE_SIZE) + X_MARGIN;

            if match_ymin == 0 {
                // match includes top row, show white pixels overwriting candies
                let fb_xmax = (match_xmax * TILE_SIZE) + X_MARGIN + TILE_SIZE;
                for ys in 0..=y_shift {
                    for x in fb_xmin..fb_xmax {
                        write_byte(WHITE, &mut screen[Y_MARGIN + ys][x]);
                    }
                    wait_for_millis(5);
                }

            } else {
                // match was not in the top row, animate a region of falling tiles
                for ys in 1..=y_shift {
                    render_grid(&grid,
                                None,
                                (match_xmin, 0),
                                (match_xmax+1, match_ymin),
                                &mut screen,
                                (fb_xmin, Y_MARGIN + ys));
                    wait_for_millis(5);
                }

            }
            wait_for_millis(250);
            erase_text(4, WHITE, &mut screen, MOVE_SCORE0_LOCATION);

            // update grid
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
        } // end check_match() loop

        // render the grid
        render_grid(&grid,
                    Some((selected_x,selected_y)),
                    (0,0),
                    (GRID_WIDTH,GRID_HEIGHT),
                    &mut screen,
                    (X_MARGIN, Y_MARGIN));

        // render the score
        erase_text(8, WHITE, &mut screen, SCORE_VALUE_LOCATION);
        let mut buffer = itoa::Buffer::new();
        let score_str = buffer.format(score);
        render_text(score_str, BLACK, &mut screen, SCORE_VALUE_LOCATION);

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
include!("../../images/font.rs");

/// # Arguments
/// * `grid_selected` x,y grid coordinates of the selected candy
/// * `grid_tl` x,y grid coordinates of the top left region of the grid to render
/// * `grid_br` x,y grid coordinates of the bottom right region of the grid to render
/// * `render_start` the x,y screen coordinates where we should start drawing
#[inline(never)]
fn render_grid(grid: &TileGrid,
               grid_selected: Option<(usize,usize)>,
               grid_tl: (usize,usize),
               grid_br: (usize,usize),
               screen: &mut FrameBuffer,
               render_start: (usize,usize),
) {
    for y in grid_tl.1..grid_br.1 {
        for x in grid_tl.0..grid_br.0 {
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
                    let px = ((x - grid_tl.0) * TILE_SIZE) + tx;
                    let py = ((y - grid_tl.1) * TILE_SIZE) + ty;
                    assert!(px < SCREEN_WIDTH && py < SCREEN_HEIGHT);
                    write_byte(tile_pixels[ty][tx], &mut screen[render_start.1 + py][render_start.0 + px]);
                }
            }
            if grid_selected.is_some() && (x,y) == grid_selected.unwrap() {
                // draw cursor border
                for ty in 0..TILE_SIZE {
                    for tx in 0..TILE_SIZE {
                        if ty <= 2 || ty >= TILE_SIZE - 3 || tx <= 2 || tx >= TILE_SIZE - 3 {
                            let px = ((x - grid_tl.0) * TILE_SIZE) + tx;
                            let py = ((y - grid_tl.1) * TILE_SIZE) + ty;
                            assert!(render_start.0 + px < SCREEN_WIDTH && render_start.1 + py < SCREEN_HEIGHT);
                            // screen[render_start.1 + py][render_start.0 + px] = CURSOR_COLOR;
                            write_byte(CURSOR_COLOR, &mut screen[render_start.1 + py][render_start.0 + px])
                        }
                    }
                }
            }
        }
    }
}

/// Render the given string in a single horizontal line.
/// # Arguments
/// * `s` must contain only ASCII characters
/// * `color` color to use for text pixels
/// * `screen` frame buffer to write to
/// * `render_start` (x,y) coordinates of the top-left corner at which to start rendering.
fn render_text(s: &str, color: u8, screen: &mut FrameBuffer, render_start: (usize,usize)) {
    let astr = AsciiStr::from_ascii(s).unwrap();
    for ci in 0..astr.len() {
        let achar = astr.as_bytes()[ci];
        let bitmap = FONT8X8[achar as usize];
        for by in 0..8 {
            let bitmap_row = bitmap[by];
            for bx in (0..8).rev() {
                let bit = (bitmap_row >> bx) & 1;
                if 1 == bit {
                    write_byte(color, &mut screen[render_start.1 + by][render_start.0 + (ci * 8) + bx]);
                }
            }
        }
    }
}

/// Erase one line of text by writing `num_chars` 8x8 blocks of `color` pixels, starting at `render_start`
fn erase_text(num_chars: usize, color: u8, screen: &mut FrameBuffer, render_start: (usize,usize)) {
    for y in render_start.1..(render_start.1+8) {
        for x in render_start.0..(num_chars*8) {
            write_byte(color, &mut screen[y][x]);
        }
    }
}