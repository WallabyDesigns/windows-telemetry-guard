//! Procedurally draws the app icon: a white eye with a red "blocked" slash
//! through it, on a dark teal circular badge. Generated at build time rather
//! than shipped as an asset, so there's nothing to keep in sync on disk.

const BG: [u8; 3] = [26, 42, 46];
const EYE: [u8; 3] = [235, 240, 238];
const PUPIL: [u8; 3] = [20, 30, 34];
const SLASH: [u8; 3] = [225, 70, 65];

pub fn build(size: usize) -> Vec<u8> {
    let mut buf = vec![0u8; size * size * 4];
    let cx = size as f32 / 2.0;
    let cy = cx;
    let r = size as f32 / 2.0 - 1.0;

    for y in 0..size {
        for x in 0..size {
            let px = x as f32 + 0.5;
            let py = y as f32 + 0.5;
            if dist(px, py, cx, cy) <= r {
                set(&mut buf, size, x, y, BG);
            }
        }
    }

    let eye_rx = size as f32 * 0.30;
    let eye_ry = size as f32 * 0.17;
    for y in 0..size {
        for x in 0..size {
            let dx = (x as f32 + 0.5 - cx) / eye_rx;
            let dy = (y as f32 + 0.5 - cy) / eye_ry;
            if dx * dx + dy * dy <= 1.0 {
                set(&mut buf, size, x, y, EYE);
            }
        }
    }

    let pupil_r = size as f32 * 0.09;
    for y in 0..size {
        for x in 0..size {
            let px = x as f32 + 0.5;
            let py = y as f32 + 0.5;
            if dist(px, py, cx, cy) <= pupil_r {
                set(&mut buf, size, x, y, PUPIL);
            }
        }
    }

    let thickness = size as f32 * 0.11;
    let reach = r * 0.78;
    let p0 = (cx - reach, cy + reach);
    let p1 = (cx + reach, cy - reach);
    for y in 0..size {
        for x in 0..size {
            let px = x as f32 + 0.5;
            let py = y as f32 + 0.5;
            if dist(px, py, cx, cy) <= r
                && point_segment_distance(px, py, p0, p1) <= thickness / 2.0
            {
                set(&mut buf, size, x, y, SLASH);
            }
        }
    }

    buf
}

fn set(buf: &mut [u8], size: usize, x: usize, y: usize, rgb: [u8; 3]) {
    let idx = (y * size + x) * 4;
    buf[idx] = rgb[0];
    buf[idx + 1] = rgb[1];
    buf[idx + 2] = rgb[2];
    buf[idx + 3] = 255;
}

fn dist(px: f32, py: f32, cx: f32, cy: f32) -> f32 {
    ((px - cx).powi(2) + (py - cy).powi(2)).sqrt()
}

fn point_segment_distance(px: f32, py: f32, a: (f32, f32), b: (f32, f32)) -> f32 {
    let (ax, ay) = a;
    let (bx, by) = b;
    let (abx, aby) = (bx - ax, by - ay);
    let len_sq = abx * abx + aby * aby;
    let t = if len_sq > 0.0 {
        (((px - ax) * abx + (py - ay) * aby) / len_sq).clamp(0.0, 1.0)
    } else {
        0.0
    };
    let (cx, cy) = (ax + t * abx, ay + t * aby);
    dist(px, py, cx, cy)
}
