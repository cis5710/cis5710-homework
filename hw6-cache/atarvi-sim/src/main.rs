use std::cmp::{max, min};
use std::thread;
use std::time::Duration;
use minifb::{Key, KeyRepeat, Window, WindowOptions};
use rand::Rng;

const SCREEN_WIDTH: usize = 320;
const SCREEN_HEIGHT: usize = 240;
const TILE_SIZE: usize = 32; // Each tile is 32x32 pixels
const GRID_WIDTH: usize = 6;
const GRID_HEIGHT: usize = 7;
const X_MARGIN: usize = 0;
const Y_MARGIN: usize = (SCREEN_HEIGHT - (TILE_SIZE * GRID_HEIGHT)) / 2;

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

type FrameBuffer = [[u8; SCREEN_WIDTH]; SCREEN_HEIGHT];
type WindowBuffer = [[u32; SCREEN_WIDTH]; SCREEN_HEIGHT];
type Grid = [[Tile; GRID_WIDTH]; GRID_HEIGHT];

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
    let mut buffer: FrameBuffer = [[BLACK; SCREEN_WIDTH]; SCREEN_HEIGHT];
    let mut window_buffer: WindowBuffer = [[0; SCREEN_WIDTH]; SCREEN_HEIGHT];

    // game data structures
    let mut grid: Grid = [[Tile::Blue; GRID_WIDTH]; GRID_HEIGHT];
    let mut matches: [[bool; GRID_WIDTH]; GRID_HEIGHT] = [[false; GRID_WIDTH]; GRID_HEIGHT];
    let mut selected_x: usize = 3;
    let mut selected_y: usize = 3;
    let mut score: usize = 0;

    // clear screen to white
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            buffer[y][x] = WHITE;
        }
    }

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
            score += num_tiles_matches * num_tiles_matches * num_tiles_matches;
            println!("score: {score} points");
            if match_ymin > 0 {
                render_grid(&grid, &mut buffer, selected_x, selected_y);
                fb_to_wb(&buffer, &mut window_buffer);
                window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();

                // match was not in the top row, animate a region of falling tiles
                let minx = (match_xmin * TILE_SIZE) + X_MARGIN;
                let maxx = (match_xmax * TILE_SIZE) + X_MARGIN + TILE_SIZE;
                let miny = 0;
                let maxy = match_ymin * TILE_SIZE;
                let shift = ((match_ymax - match_ymin) + 1) * TILE_SIZE;
                // println!("animated drop of {shift} pixels, from {match_xmin},{match_ymin} to {match_xmax},{match_ymax}");
                for y_shift in 1..=shift {
                    for y in (miny..maxy).rev() {
                        for x in minx..maxx {
                            buffer[Y_MARGIN-1 + y + y_shift][x] = buffer[Y_MARGIN-1 + y + y_shift - 1][x];
                        }
                    }
                    fb_to_wb(&buffer, &mut window_buffer);
                    window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();
                    thread::sleep(Duration::from_millis(10));
                }
                thread::sleep(Duration::from_millis(500));
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
        render_grid(&grid, &mut buffer, selected_x, selected_y);
        fb_to_wb(&buffer, &mut window_buffer);
        window.update_with_buffer(window_buffer.as_flattened(), SCREEN_WIDTH, SCREEN_HEIGHT).unwrap();
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

fn render_grid(grid: &Grid,
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