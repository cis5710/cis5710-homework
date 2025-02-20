use std::cmp::{max, min};
use std::thread;
use std::time::Duration;
use ascii::AsciiStr;
use minifb::{Key, KeyRepeat, Window, WindowOptions};
use rand::Rng;

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
    fn random2(exclude: Option<Tile>, exclude2: Option<Tile>) -> Tile {
        let all_tiles = [Tile::Red, Tile::Orange, Tile::Yellow, Tile::Green, Tile::Blue, Tile::Purple];
        for tile in all_tiles {
            if (exclude.is_none() || exclude.unwrap() != tile) &&
                (exclude2.is_none() || exclude2.unwrap() != tile) {
                return tile
            }
        }
        Tile::Blue
    }
    fn random(exclude: Option<Tile>, exclude2: Option<Tile>) -> Tile {
        let mut tile;
        loop {
            tile = match rand::thread_rng().gen_range(0..6) {
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

const BLACK: u8 = 0x00;
const WHITE: u8 = 0xFF;
const CURSOR_COLOR: u8 = BLACK;

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];
type WindowBuffer = [[u32; SCREEN_WIDTH]; SCREEN_HEIGHT];
type TileGrid = [[Tile; GRID_WIDTH]; GRID_HEIGHT];

fn main() {
    let mut window = Window::new(
        "Candy Crvsh",
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        WindowOptions::default(),
    )
        .unwrap_or_else(|e| {
            panic!("{}", e);
        });

    // frame buffer
    let mut frame_buffer: FrameBuffer = [[BLACK; SCREEN_WIDTH]; SCREEN_HEIGHT];
    let mut window_buffer: WindowBuffer = [[0; SCREEN_WIDTH]; SCREEN_HEIGHT];

    // game data structures
    let mut grid: TileGrid = [[Tile::Blue; GRID_WIDTH]; GRID_HEIGHT];
    let mut matches: [[bool; GRID_WIDTH]; GRID_HEIGHT] = [[false; GRID_WIDTH]; GRID_HEIGHT];
    let mut selected_x: usize = 3;
    let mut selected_y: usize = 3;
    let mut score: usize = 0;

    // clear screen to white
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            frame_buffer[y][x] = WHITE;
        }
    }

    // render title
    render_text(" Welcome to", BLACK, &mut frame_buffer, TITLE0_LOCATION);
    render_text("Candy Crvsh!", BLACK, &mut frame_buffer, TITLE1_LOCATION);
    render_text("score:", BLACK, &mut frame_buffer, SCORE_LABEL_LOCATION);

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

    while window.is_open() && !window.is_key_down(Key::Escape) {

        // move cursor
        if window.is_key_pressed(Key::Left, KeyRepeat::Yes) && selected_x > 0 {
            selected_x -= 1;
        }
        if window.is_key_pressed(Key::Right, KeyRepeat::Yes) && selected_x < GRID_WIDTH-1 {
            selected_x += 1;
        }
        if window.is_key_pressed(Key::Up, KeyRepeat::Yes) && selected_y > 0 {
            selected_y -= 1;
        }
        if window.is_key_pressed(Key::Down, KeyRepeat::Yes) && selected_y < GRID_HEIGHT-1 {
            selected_y += 1;
        }

        // swaps
        if window.is_key_pressed(Key::W, KeyRepeat::No) && selected_y > 0 {
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
        if window.is_key_pressed(Key::A, KeyRepeat::No) && selected_x > 0 {
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
        if window.is_key_pressed(Key::S, KeyRepeat::No) && selected_y < GRID_HEIGHT-1 {
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
        if window.is_key_pressed(Key::D, KeyRepeat::No) && selected_x < GRID_WIDTH - 1 {
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
            let move_score = match num_tiles_matches {
                3 => 1,
                4 => 2,
                5 => 3,
                _ => 4,
            };
            score += move_score;
            println!("score: {score} points");

            // render grid with tiles swapped
            render_grid(&grid,
                        Some((selected_x,selected_y)),
                        (0,0),
                        (GRID_WIDTH,GRID_HEIGHT),
                        &mut frame_buffer,
                        (X_MARGIN, Y_MARGIN));
            fb_to_wb(&frame_buffer, &mut window_buffer);
            window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();

            let mut buffer = itoa::Buffer::new();
            let move_score_str = buffer.format(move_score);
            render_text("+", BLACK, &mut frame_buffer, MOVE_SCORE0_LOCATION);
            render_text(move_score_str, BLACK, &mut frame_buffer, MOVE_SCORE1_LOCATION);

            let shift = ((match_ymax - match_ymin) + 1) * TILE_SIZE;
            let fb_xmin = (match_xmin * TILE_SIZE) + X_MARGIN;
            if match_ymin == 0 {
                // match includes top row, show white pixels overwriting candies
                let fb_xmax = (match_xmax * TILE_SIZE) + X_MARGIN + TILE_SIZE;
                for y_shift in 0..=shift {
                    for x in fb_xmin..fb_xmax {
                        frame_buffer[Y_MARGIN + y_shift][x] = WHITE;
                    }
                    fb_to_wb(&frame_buffer, &mut window_buffer);
                    window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();
                    thread::sleep(Duration::from_millis(10));
                }

            } else {
                // match was not in the top row, animate a region of falling tiles
                let miny = 0;
                let maxy = match_ymin * TILE_SIZE;
                //println!("animated drop of {shift} pixels, from {match_xmin},{match_ymin} to {match_xmax},{match_ymax}");

                for y_shift in 1..=shift {
                    render_grid(&grid,
                                None,
                                (match_xmin, 0),
                                (match_xmax + 1, match_ymin),
                                &mut frame_buffer,
                                (fb_xmin, Y_MARGIN + y_shift));
                    fb_to_wb(&frame_buffer, &mut window_buffer);
                    window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();
                    thread::sleep(Duration::from_millis(10));
                }
            }


            // for y_shift in 1..=shift {
            //     for y in (miny..maxy).rev() {
            //         for x in minx..maxx {
            //             buffer[Y_MARGIN-1 + y + y_shift][x] = buffer[Y_MARGIN-1 + y + y_shift - 1][x];
            //         }
            //     }
            //     fb_to_wb(&buffer, &mut window_buffer);
            //     window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();
            //     thread::sleep(Duration::from_millis(10));
            // }
            thread::sleep(Duration::from_millis(500));

            let erase_move_score: &[u8] = &[0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01];
            render_text(unsafe { core::str::from_utf8_unchecked(erase_move_score) }, WHITE, &mut frame_buffer, MOVE_SCORE0_LOCATION);

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
        // render_grid(&grid, &mut buffer, selected_x, selected_y);
        render_grid(&grid,
                    Some((selected_x,selected_y)),
                    (0,0),
                    (GRID_WIDTH,GRID_HEIGHT),
                    &mut frame_buffer,
                    (X_MARGIN, Y_MARGIN));
        fb_to_wb(&frame_buffer, &mut window_buffer);
        window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();

        // render the score
        let erase_score: &[u8] = &[0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01];
        render_text(unsafe { core::str::from_utf8_unchecked(erase_score) }, WHITE, &mut frame_buffer, SCORE_VALUE_LOCATION);
        let mut buffer = itoa::Buffer::new();
        let score_str = buffer.format(score);
        render_text(score_str, BLACK, &mut frame_buffer, SCORE_VALUE_LOCATION);
    }
}

fn check_matches(grid: &[[Tile; GRID_WIDTH]; GRID_HEIGHT],
                 mut matches: Option<&mut [[bool; GRID_WIDTH]; GRID_HEIGHT]>) -> bool {
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

//include!("../images/candies-24b.rs");
include!("../images/candies-8b.rs");
include!("../images/font.rs");

fn pixel8_to_pixel32(pixel: u8) -> u32 {
    // wire [ 7:0] red24 = {{3{red8[2]}}, {3{red8[1]}}, {2{red8[0]}}};
    // wire [ 7:0] green24 = {{3{green8[2]}}, {3{green8[1]}}, {2{green8[0]}}};
    // wire [ 7:0] blue24 = {{4{blue8[1]}}, {4{blue8[0]}}};
    // Extract the red, green, and blue components
    let red = (pixel >> 5) & 0b0000_0111;
    let green = (pixel >> 2) & 0b0000_0111;
    let blue = pixel & 0b0000_0011;

    // Convert to 8-bit values
    let red = (red << 5) | (red << 2) | (red >> 1);
    let green = (green << 5) | (green << 2) | (green >> 1);
    let blue = (blue << 6) | (blue << 4) | (blue << 2) | blue;

    // Combine into a single u32 value
    (red as u32) << 16 | (green as u32) << 8 | blue as u32
}

fn fb_to_wb(fbuf: &FrameBuffer, winbuf: &mut WindowBuffer) {
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            winbuf[y][x] = pixel8_to_pixel32(fbuf[y][x]);
        }
    }
}

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
                    // write_byte(tile_pixels[ty][tx], &mut screen[render_start.1 + py as usize][render_start.0 + px as usize]);
                    screen[render_start.1 + py][render_start.0 + px] = tile_pixels[ty][tx];
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
                            screen[render_start.1 + py][render_start.0 + px] = CURSOR_COLOR;
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
                    screen[render_start.1 + by][render_start.0 + (ci * 8) + bx] = color;
                }
            }
        }
    }
}

fn render_grid_old(grid: &TileGrid,
                   buffer: &mut FrameBuffer,
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
                        buffer[Y_MARGIN + py][X_MARGIN + px] = tile_pixels[ty][tx];
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
                                buffer[Y_MARGIN + py][X_MARGIN + px] = 0;
                            }
                        }
                    }
                }
            }
        }
    }
}