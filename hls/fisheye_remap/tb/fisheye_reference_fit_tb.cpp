// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 从真实 raw16 帧拟合鱼眼圆心/半径，并生成去畸变软件参考图。
// 数据流位置    : HLS C 仿真侧校准工具，用于判断畸变表方向和 200 行缓存限制影响。
// 维护边界      : 不进入综合核心；确认参数后再单独修改 HLS 算法源码和导出 RTL。
// ============================================================================
#include "fisheye_remap_reader_hls.h"
#include "distortion_lut.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <vector>

#ifdef _WIN32
#include <direct.h>
#else
#include <sys/stat.h>
#endif

static const int kRawFramePixels = kFisheyeImageWidth * kFisheyeImageHeight;
static const int kRawFrameBytes = kRawFramePixels * 2;
static const int kFitAngleCount = 720;
static const int kFitRadiusMin = 700;
static const int kFitRadiusMax = 1250;
static const int kPreviewTileSize = 512;

struct point_t {
    double x;
    double y;
};

struct fit_result_t {
    double cx;
    double cy;
    double radius;
    double rms_error;
    int initial_points;
    int kept_points;
};

struct image_stats_t {
    uint16_t min_v;
    uint16_t max_v;
    uint64_t sum;
    uint64_t saturated;
};

struct variant_report_t {
    std::string name;
    bool constrained;
    double max_dx;
    double max_dy;
    double mean_abs_diff;
    double clamp_ratio;
    uint64_t diff_pixels;
    image_stats_t stats;
};

struct curve_fit_t {
    double cx;
    double cy;
    double radius;
    double target_y;
    double max_delta;
    int initial_points;
    int kept_points;
};

struct curve_flatten_report_t {
    std::string name;
    bool constrained;
    double inner_radius;
    double target_y;
    double max_dy;
    double mean_abs_diff;
    double clamp_ratio;
    uint64_t diff_pixels;
    image_stats_t stats;
};

static void make_dir(const std::string& path) {
#ifdef _WIN32
    _mkdir(path.c_str());
#else
    mkdir(path.c_str(), 0755);
#endif
}

static std::string env_or_default(const char* name, const std::string& fallback) {
    const char* value = std::getenv(name);
    return (value && value[0]) ? std::string(value) : fallback;
}

static bool env_is_big_endian() {
    return env_or_default("FISHEYE_RAW_ENDIAN", "little") == "big";
}

static std::string basename_of(const std::string& path) {
    const size_t slash = path.find_last_of("/\\");
    return (slash == std::string::npos) ? path : path.substr(slash + 1);
}

static std::vector<uint16_t> read_raw16(const std::string& path, bool big_endian) {
    std::ifstream in(path.c_str(), std::ios::binary);
    if (!in) {
        std::cerr << "ERROR: cannot open raw file: " << path << std::endl;
        std::exit(2);
    }
    in.seekg(0, std::ios::end);
    const std::streamoff size = in.tellg();
    in.seekg(0, std::ios::beg);
    if (size != kRawFrameBytes) {
        std::cerr << "ERROR: raw file size mismatch: " << path
                  << " size=" << size
                  << " expected=" << kRawFrameBytes << std::endl;
        std::exit(3);
    }

    std::vector<unsigned char> bytes(kRawFrameBytes);
    in.read(reinterpret_cast<char*>(&bytes[0]), bytes.size());
    std::vector<uint16_t> pixels(kRawFramePixels);
    for (int i = 0; i < kRawFramePixels; ++i) {
        const unsigned char b0 = bytes[i * 2 + 0];
        const unsigned char b1 = bytes[i * 2 + 1];
        pixels[i] = big_endian
                        ? static_cast<uint16_t>((b0 << 8) | b1)
                        : static_cast<uint16_t>(b0 | (b1 << 8));
    }
    return pixels;
}

static void write_pgm16(const std::string& path, const std::vector<uint16_t>& pixels) {
    std::ofstream out(path.c_str(), std::ios::binary);
    out << "P5\n" << kFisheyeImageWidth << " " << kFisheyeImageHeight << "\n65535\n";
    for (size_t i = 0; i < pixels.size(); ++i) {
        const unsigned char hi = static_cast<unsigned char>((pixels[i] >> 8) & 0xff);
        const unsigned char lo = static_cast<unsigned char>(pixels[i] & 0xff);
        out.put(static_cast<char>(hi));
        out.put(static_cast<char>(lo));
    }
}

static void write_raw16_le(const std::string& path, const std::vector<uint16_t>& pixels) {
    std::ofstream out(path.c_str(), std::ios::binary);
    for (size_t i = 0; i < pixels.size(); ++i) {
        const unsigned char lo = static_cast<unsigned char>(pixels[i] & 0xff);
        const unsigned char hi = static_cast<unsigned char>((pixels[i] >> 8) & 0xff);
        out.put(static_cast<char>(lo));
        out.put(static_cast<char>(hi));
    }
}

static uint16_t sample_nearest(const std::vector<uint16_t>& image, double x, double y) {
    const int xi = static_cast<int>(std::floor(x + 0.5));
    const int yi = static_cast<int>(std::floor(y + 0.5));
    if (xi < 0 || xi >= kFisheyeImageWidth || yi < 0 || yi >= kFisheyeImageHeight) {
        return 0;
    }
    return image[yi * kFisheyeImageWidth + xi];
}

static uint16_t sample_bilinear(const std::vector<uint16_t>& image, double x, double y) {
    if (x < 0.0 || y < 0.0 ||
        x >= static_cast<double>(kFisheyeImageWidth - 1) ||
        y >= static_cast<double>(kFisheyeImageHeight - 1)) {
        return 0;
    }
    const int x0 = static_cast<int>(std::floor(x));
    const int y0 = static_cast<int>(std::floor(y));
    const double fx = x - x0;
    const double fy = y - y0;
    const uint16_t p00 = image[y0 * kFisheyeImageWidth + x0];
    const uint16_t p10 = image[y0 * kFisheyeImageWidth + x0 + 1];
    const uint16_t p01 = image[(y0 + 1) * kFisheyeImageWidth + x0];
    const uint16_t p11 = image[(y0 + 1) * kFisheyeImageWidth + x0 + 1];
    const double top = p00 * (1.0 - fx) + p10 * fx;
    const double bot = p01 * (1.0 - fx) + p11 * fx;
    const double value = top * (1.0 - fy) + bot * fy;
    return static_cast<uint16_t>(std::max(0.0, std::min(65535.0, value + 0.5)));
}

static image_stats_t calc_stats(const std::vector<uint16_t>& image) {
    image_stats_t stats;
    stats.min_v = std::numeric_limits<uint16_t>::max();
    stats.max_v = 0;
    stats.sum = 0;
    stats.saturated = 0;
    for (size_t i = 0; i < image.size(); ++i) {
        stats.min_v = std::min(stats.min_v, image[i]);
        stats.max_v = std::max(stats.max_v, image[i]);
        stats.sum += image[i];
        stats.saturated += (image[i] == 65535) ? 1 : 0;
    }
    return stats;
}

static bool solve_3x3(double m[3][4], double out[3]) {
    for (int col = 0; col < 3; ++col) {
        int pivot = col;
        for (int row = col + 1; row < 3; ++row) {
            if (std::fabs(m[row][col]) > std::fabs(m[pivot][col])) {
                pivot = row;
            }
        }
        if (std::fabs(m[pivot][col]) < 1.0e-9) {
            return false;
        }
        if (pivot != col) {
            for (int k = col; k < 4; ++k) {
                std::swap(m[pivot][k], m[col][k]);
            }
        }
        const double div = m[col][col];
        for (int k = col; k < 4; ++k) {
            m[col][k] /= div;
        }
        for (int row = 0; row < 3; ++row) {
            if (row == col) {
                continue;
            }
            const double factor = m[row][col];
            for (int k = col; k < 4; ++k) {
                m[row][k] -= factor * m[col][k];
            }
        }
    }
    out[0] = m[0][3];
    out[1] = m[1][3];
    out[2] = m[2][3];
    return true;
}

static fit_result_t fit_circle(const std::vector<point_t>& points) {
    double sx = 0.0;
    double sy = 0.0;
    double s1 = static_cast<double>(points.size());
    double sxx = 0.0;
    double syy = 0.0;
    double sxy = 0.0;
    double sxz = 0.0;
    double syz = 0.0;
    double sz = 0.0;
    for (size_t i = 0; i < points.size(); ++i) {
        const double x = points[i].x;
        const double y = points[i].y;
        const double z = x * x + y * y;
        sx += x;
        sy += y;
        sxx += x * x;
        syy += y * y;
        sxy += x * y;
        sxz += x * z;
        syz += y * z;
        sz += z;
    }

    double mat[3][4] = {
        {sxx, sxy, sx, -sxz},
        {sxy, syy, sy, -syz},
        {sx,  sy,  s1, -sz}
    };
    double abc[3] = {0.0, 0.0, 0.0};
    fit_result_t fit;
    fit.cx = kFisheyeCenterX;
    fit.cy = kFisheyeCenterY;
    fit.radius = kFisheyeMaxRadius;
    fit.rms_error = 0.0;
    fit.initial_points = static_cast<int>(points.size());
    fit.kept_points = static_cast<int>(points.size());
    if (!solve_3x3(mat, abc)) {
        return fit;
    }

    fit.cx = -abc[0] * 0.5;
    fit.cy = -abc[1] * 0.5;
    fit.radius = std::sqrt(std::max(0.0, fit.cx * fit.cx + fit.cy * fit.cy - abc[2]));
    double err = 0.0;
    for (size_t i = 0; i < points.size(); ++i) {
        const double d = std::hypot(points[i].x - fit.cx, points[i].y - fit.cy) - fit.radius;
        err += d * d;
    }
    fit.rms_error = std::sqrt(err / std::max(1.0, s1));
    return fit;
}

static std::vector<point_t> find_edge_points(const std::vector<uint16_t>& image,
                                             double cx,
                                             double cy) {
    std::vector<point_t> points;
    const double pi = std::acos(-1.0);
    for (int a = 0; a < kFitAngleCount; ++a) {
        const double theta = (2.0 * pi * a) / kFitAngleCount;
        const double ux = std::cos(theta);
        const double uy = std::sin(theta);
        int best_r = -1;
        double best_score = 0.0;
        for (int r = kFitRadiusMin; r <= kFitRadiusMax; ++r) {
            const double xm = cx + ux * r;
            const double ym = cy + uy * r;
            const double x0 = cx + ux * (r - 5);
            const double y0 = cy + uy * (r - 5);
            const double x1 = cx + ux * (r + 5);
            const double y1 = cy + uy * (r + 5);
            if (x1 < 1.0 || x1 >= (kFisheyeImageWidth - 1) ||
                y1 < 1.0 || y1 >= (kFisheyeImageHeight - 1) ||
                x0 < 1.0 || x0 >= (kFisheyeImageWidth - 1) ||
                y0 < 1.0 || y0 >= (kFisheyeImageHeight - 1)) {
                continue;
            }
            const double inner = sample_nearest(image, x0, y0);
            const double outer = sample_nearest(image, x1, y1);
            const double mid = sample_nearest(image, xm, ym);
            const double score = std::fabs(inner - outer) + 0.25 * std::fabs(mid - outer);
            if (score > best_score) {
                best_score = score;
                best_r = r;
            }
        }
        if (best_r >= 0 && best_score > 512.0) {
            point_t p;
            p.x = cx + ux * best_r;
            p.y = cy + uy * best_r;
            points.push_back(p);
        }
    }
    return points;
}

static fit_result_t robust_fit_circle(const std::vector<uint16_t>& image) {
    std::vector<point_t> points = find_edge_points(image, kFisheyeCenterX, kFisheyeCenterY);
    fit_result_t fit = fit_circle(points);
    fit.initial_points = static_cast<int>(points.size());

    for (int iter = 0; iter < 3; ++iter) {
        std::vector<double> residuals;
        residuals.reserve(points.size());
        for (size_t i = 0; i < points.size(); ++i) {
            residuals.push_back(std::fabs(std::hypot(points[i].x - fit.cx, points[i].y - fit.cy) - fit.radius));
        }
        std::vector<double> sorted = residuals;
        std::sort(sorted.begin(), sorted.end());
        const double median = sorted.empty() ? 0.0 : sorted[sorted.size() / 2];
        const double limit = std::max(24.0, median * 3.0);
        std::vector<point_t> kept;
        kept.reserve(points.size());
        for (size_t i = 0; i < points.size(); ++i) {
            if (residuals[i] <= limit) {
                kept.push_back(points[i]);
            }
        }
        if (kept.size() < 32 || kept.size() == points.size()) {
            points = kept.empty() ? points : kept;
            break;
        }
        points.swap(kept);
        fit = fit_circle(points);
    }
    fit.kept_points = static_cast<int>(points.size());
    return fit;
}

static double lut_scale_at_radius(const ap_uint<18>* lut, double radius, double fit_radius) {
    double idx_f = (radius / std::max(1.0, fit_radius)) * 100.0;
    if (idx_f < 0.0) {
        idx_f = 0.0;
    }
    if (idx_f > 100.0) {
        idx_f = 100.0;
    }
    const int idx0 = static_cast<int>(std::floor(idx_f));
    const int idx1 = std::min(100, idx0 + 1);
    const double t = idx_f - idx0;
    const double s0 = static_cast<double>(lut[idx0].to_uint()) / 65536.0;
    const double s1 = static_cast<double>(lut[idx1].to_uint()) / 65536.0;
    return s0 * (1.0 - t) + s1 * t;
}

static std::vector<uint16_t> remap_reference(const std::vector<uint16_t>& input,
                                             const fit_result_t& fit,
                                             const ap_uint<18>* lut,
                                             bool inverse,
                                             bool constrained,
                                             variant_report_t& report) {
    std::vector<uint16_t> output(kRawFramePixels, 0);
    uint64_t diff_pixels = 0;
    uint64_t clamp_pixels = 0;
    double sad = 0.0;
    double max_dx = 0.0;
    double max_dy = 0.0;

    for (int y = 0; y < kFisheyeImageHeight; ++y) {
        for (int x = 0; x < kFisheyeImageWidth; ++x) {
            const double dx = x - fit.cx;
            const double dy = y - fit.cy;
            const double radius = std::hypot(dx, dy);
            double scale = lut_scale_at_radius(lut, radius, fit.radius);
            if (inverse) {
                scale = (scale == 0.0) ? 1.0 : (1.0 / scale);
            }
            double sx = fit.cx + dx * scale;
            double sy = fit.cy + dy * scale;
            const double raw_vshift = sy - y;
            if (constrained && std::fabs(raw_vshift) > kFisheyeMaxVerticalShift) {
                sy = y + ((raw_vshift > 0.0) ? kFisheyeMaxVerticalShift : -kFisheyeMaxVerticalShift);
                clamp_pixels++;
            }
            max_dx = std::max(max_dx, std::fabs(sx - x));
            max_dy = std::max(max_dy, std::fabs(sy - y));
            const uint16_t pixel = sample_bilinear(input, sx, sy);
            output[y * kFisheyeImageWidth + x] = pixel;
            if (pixel != input[y * kFisheyeImageWidth + x]) {
                diff_pixels++;
            }
            sad += std::fabs(static_cast<double>(pixel) - input[y * kFisheyeImageWidth + x]);
        }
    }

    report.max_dx = max_dx;
    report.max_dy = max_dy;
    report.mean_abs_diff = sad / kRawFramePixels;
    report.clamp_ratio = static_cast<double>(clamp_pixels) / kRawFramePixels;
    report.diff_pixels = diff_pixels;
    report.stats = calc_stats(output);
    return output;
}

static double median_of(std::vector<double> values, double fallback) {
    if (values.empty()) {
        return fallback;
    }
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

static curve_fit_t detect_lower_inner_curve(const std::vector<uint16_t>& input,
                                            const fit_result_t& fit) {
    // 新代码：Egor Izmaylov
    // 利用用户指出的“内圈下半部分应为水平线”作为工程约束，先在软件侧自动提取下半圆边界。
    std::vector<point_t> raw_points;
    std::vector<double> radii;
    const double pi = std::acos(-1.0);
    const int r_min = 480;
    const int r_max = std::min(930, static_cast<int>(fit.radius) - 12);
    for (int angle_deg = 15; angle_deg <= 165; ++angle_deg) {
        const double theta = (pi * angle_deg) / 180.0;
        const double ux = std::cos(theta);
        const double uy = std::sin(theta);
        double best_score = -1.0;
        int best_r = 0;
        for (int r = r_min; r <= r_max; r += 2) {
            const double x0 = fit.cx + ux * (r - 8);
            const double y0 = fit.cy + uy * (r - 8);
            const double x1 = fit.cx + ux * (r + 8);
            const double y1 = fit.cy + uy * (r + 8);
            if (x0 < 1.0 || y0 < 1.0 ||
                x1 < 1.0 || y1 < 1.0 ||
                x0 >= (kFisheyeImageWidth - 1) ||
                x1 >= (kFisheyeImageWidth - 1) ||
                y0 >= (kFisheyeImageHeight - 1) ||
                y1 >= (kFisheyeImageHeight - 1)) {
                continue;
            }
            const double score = std::fabs(static_cast<double>(sample_nearest(input, x1, y1)) -
                                           static_cast<double>(sample_nearest(input, x0, y0)));
            if (score > best_score) {
                best_score = score;
                best_r = r;
            }
        }
        if (best_score > 3500.0 && best_r > 0) {
            point_t p;
            p.x = fit.cx + ux * best_r;
            p.y = fit.cy + uy * best_r;
            raw_points.push_back(p);
            radii.push_back(best_r);
        }
    }

    const double median_radius = median_of(radii, fit.radius * 0.83);
    std::vector<point_t> kept;
    std::vector<double> kept_y;
    double max_delta = 0.0;
    for (size_t i = 0; i < raw_points.size(); ++i) {
        const double r = std::hypot(raw_points[i].x - fit.cx, raw_points[i].y - fit.cy);
        if (std::fabs(r - median_radius) <= 120.0) {
            kept.push_back(raw_points[i]);
            kept_y.push_back(raw_points[i].y);
            max_delta = std::max(max_delta, std::fabs(raw_points[i].y - fit.cy));
        }
    }

    curve_fit_t curve;
    curve.cx = fit.cx;
    curve.cy = fit.cy;
    curve.radius = median_radius;
    curve.target_y = median_of(kept_y, fit.cy + median_radius * 0.78);
    curve.max_delta = max_delta;
    curve.initial_points = static_cast<int>(raw_points.size());
    curve.kept_points = static_cast<int>(kept.size());
    return curve;
}

static curve_fit_t make_tangent_curve(const fit_result_t& fit, double radius) {
    // 新代码：Egor Izmaylov
    // 针对用户指出的“两个圈”问题，直接构造圆环下切线拉平模型，避免场景内部物体边缘误导自动检测。
    curve_fit_t curve;
    curve.cx = fit.cx;
    curve.cy = fit.cy;
    curve.radius = radius;
    curve.target_y = fit.cy + radius;
    curve.max_delta = radius;
    curve.initial_points = 0;
    curve.kept_points = 0;
    return curve;
}

static double lower_arc_y_parabolic(const curve_fit_t& curve, double x) {
    const double dx = x - curve.cx;
    if (std::fabs(dx) > curve.radius) {
        return curve.target_y;
    }
    // 新代码：Egor Izmaylov 使用抛物线近似下半圆，后续可直接转换为 HLS 整数二次项。
    return curve.cy + curve.radius - (dx * dx) / (2.0 * std::max(1.0, curve.radius));
}

static std::vector<uint16_t> curve_flatten_reference(const std::vector<uint16_t>& input,
                                                     const curve_fit_t& curve,
                                                     bool constrained,
                                                     curve_flatten_report_t& report) {
    std::vector<uint16_t> output(kRawFramePixels, 0);
    // 新代码：Egor Izmaylov 只在目标水平线附近做窄带拉平，避免把整片下半图像拉成伪影。
    // 与 HLS 核保持 256 行带宽一致，回到第一版方向拉动更明显的局部拉平参数。
    const double band = 256.0;
    uint64_t diff_pixels = 0;
    uint64_t clamp_pixels = 0;
    double sad = 0.0;
    double max_dy = 0.0;

    for (int y = 0; y < kFisheyeImageHeight; ++y) {
        for (int x = 0; x < kFisheyeImageWidth; ++x) {
            const double arc_y = lower_arc_y_parabolic(curve, x);
            const double dist_to_line = std::fabs(static_cast<double>(y) - curve.target_y);
            double weight = 0.0;
            if (y >= curve.cy && dist_to_line < band && std::fabs(x - curve.cx) <= curve.radius) {
                weight = 1.0 - dist_to_line / band;
            }
            double delta_y = (arc_y - curve.target_y) * weight;
            if (constrained && std::fabs(delta_y) > kFisheyeMaxVerticalShift) {
                delta_y = (delta_y > 0.0) ? kFisheyeMaxVerticalShift : -kFisheyeMaxVerticalShift;
                clamp_pixels++;
            }
            const double sy = y + delta_y;
            const uint16_t pixel = sample_bilinear(input, x, sy);
            output[y * kFisheyeImageWidth + x] = pixel;
            if (pixel != input[y * kFisheyeImageWidth + x]) {
                diff_pixels++;
            }
            max_dy = std::max(max_dy, std::fabs(delta_y));
            sad += std::fabs(static_cast<double>(pixel) - input[y * kFisheyeImageWidth + x]);
        }
    }

    report.inner_radius = curve.radius;
    report.target_y = curve.target_y;
    report.max_dy = max_dy;
    report.mean_abs_diff = sad / kRawFramePixels;
    report.clamp_ratio = static_cast<double>(clamp_pixels) / kRawFramePixels;
    report.diff_pixels = diff_pixels;
    report.stats = calc_stats(output);
    return output;
}

static void write_absdiff_pgm16(const std::string& path,
                                const std::vector<uint16_t>& a,
                                const std::vector<uint16_t>& b) {
    std::vector<uint16_t> diff(kRawFramePixels, 0);
    uint16_t max_diff = 1;
    for (int i = 0; i < kRawFramePixels; ++i) {
        const uint16_t d = static_cast<uint16_t>(std::abs(static_cast<int>(a[i]) - static_cast<int>(b[i])));
        diff[i] = d;
        max_diff = std::max(max_diff, d);
    }
    for (int i = 0; i < kRawFramePixels; ++i) {
        diff[i] = static_cast<uint16_t>((static_cast<uint32_t>(diff[i]) * 65535U) / max_diff);
    }
    write_pgm16(path, diff);
}

static void put_pixel(std::vector<unsigned char>& canvas, int width, int x, int y, unsigned char c) {
    const int idx = (y * width + x) * 3;
    canvas[idx + 0] = c;
    canvas[idx + 1] = c;
    canvas[idx + 2] = c;
}

static void blit_tile(std::vector<unsigned char>& canvas,
                      int canvas_width,
                      int tile_x,
                      int tile_y,
                      const std::vector<uint16_t>& image) {
    const image_stats_t stats = calc_stats(image);
    const uint32_t span = std::max<uint32_t>(1, static_cast<uint32_t>(stats.max_v) - stats.min_v);
    for (int y = 0; y < kPreviewTileSize; ++y) {
        const int sy = (y * kFisheyeImageHeight) / kPreviewTileSize;
        for (int x = 0; x < kPreviewTileSize; ++x) {
            const int sx = (x * kFisheyeImageWidth) / kPreviewTileSize;
            const uint16_t v = image[sy * kFisheyeImageWidth + sx];
            const unsigned char c = static_cast<unsigned char>(
                std::min<uint32_t>(255, ((static_cast<uint32_t>(v) - stats.min_v) * 255U) / span));
            put_pixel(canvas, canvas_width, tile_x + x, tile_y + y, c);
        }
    }
}

static void write_preview_ppm(const std::string& path,
                              const std::vector<std::vector<uint16_t> >& images) {
    const int cols = 3;
    const int rows = std::max(1, static_cast<int>((images.size() + cols - 1) / cols));
    const int width = cols * kPreviewTileSize;
    const int height = rows * kPreviewTileSize;
    std::vector<unsigned char> canvas(width * height * 3, 0);
    for (size_t i = 0; i < images.size() && i < static_cast<size_t>(cols * rows); ++i) {
        const int tx = (static_cast<int>(i) % cols) * kPreviewTileSize;
        const int ty = (static_cast<int>(i) / cols) * kPreviewTileSize;
        blit_tile(canvas, width, tx, ty, images[i]);
    }
    std::ofstream out(path.c_str(), std::ios::binary);
    out << "P6\n" << width << " " << height << "\n255\n";
    out.write(reinterpret_cast<const char*>(&canvas[0]), canvas.size());
}

static std::string json_escape(const std::string& s) {
    std::ostringstream os;
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '\\' || s[i] == '"') {
            os << '\\';
        }
        os << s[i];
    }
    return os.str();
}

static void write_reports(const std::string& out_dir,
                          const std::vector<std::string>& input_files,
                          bool big_endian,
                          const fit_result_t& fit,
                          const image_stats_t& input_stats,
                          const curve_fit_t& curve,
                          const std::vector<variant_report_t>& reports,
                          const std::vector<curve_flatten_report_t>& curve_reports) {
    const std::string json_path = out_dir + "/fit_report.json";
    std::ofstream json(json_path.c_str());
    json << std::fixed << std::setprecision(6);
    json << "{\n";
    json << "  \"author\": \"Egor Izmaylov\",\n";
    json << "  \"raw_endian\": \"" << (big_endian ? "big" : "little") << "\",\n";
    json << "  \"image_width\": " << kFisheyeImageWidth << ",\n";
    json << "  \"image_height\": " << kFisheyeImageHeight << ",\n";
    json << "  \"input_files\": [";
    for (size_t i = 0; i < input_files.size(); ++i) {
        json << (i ? ", " : "") << "\"" << json_escape(input_files[i]) << "\"";
    }
    json << "],\n";
    json << "  \"fit\": {\n";
    json << "    \"cx\": " << fit.cx << ",\n";
    json << "    \"cy\": " << fit.cy << ",\n";
    json << "    \"radius_px\": " << fit.radius << ",\n";
    json << "    \"rms_error_px\": " << fit.rms_error << ",\n";
    json << "    \"initial_points\": " << fit.initial_points << ",\n";
    json << "    \"kept_points\": " << fit.kept_points << "\n";
    json << "  },\n";
    json << "  \"lower_inner_curve\": {\n";
    json << "    \"cx\": " << curve.cx << ",\n";
    json << "    \"cy\": " << curve.cy << ",\n";
    json << "    \"inner_radius_px\": " << curve.radius << ",\n";
    json << "    \"target_y\": " << curve.target_y << ",\n";
    json << "    \"initial_points\": " << curve.initial_points << ",\n";
    json << "    \"kept_points\": " << curve.kept_points << "\n";
    json << "  },\n";
    json << "  \"input_stats\": {\"min\": " << input_stats.min_v
         << ", \"max\": " << input_stats.max_v
         << ", \"mean\": " << (static_cast<double>(input_stats.sum) / kRawFramePixels)
         << ", \"saturated\": " << input_stats.saturated << "},\n";
    json << "  \"variants\": [\n";
    for (size_t i = 0; i < reports.size(); ++i) {
        const variant_report_t& r = reports[i];
        json << "    {\"name\": \"" << r.name
             << "\", \"constrained\": " << (r.constrained ? "true" : "false")
             << ", \"max_dx\": " << r.max_dx
             << ", \"max_dy\": " << r.max_dy
             << ", \"mean_abs_diff\": " << r.mean_abs_diff
             << ", \"diff_pixels\": " << r.diff_pixels
             << ", \"clamp_ratio\": " << r.clamp_ratio
             << ", \"min\": " << r.stats.min_v
             << ", \"max\": " << r.stats.max_v
             << ", \"mean\": " << (static_cast<double>(r.stats.sum) / kRawFramePixels)
             << ", \"saturated\": " << r.stats.saturated << "}";
        json << (i + 1 == reports.size() ? "\n" : ",\n");
    }
    json << "  ],\n";
    json << "  \"curve_flatten_variants\": [\n";
    for (size_t i = 0; i < curve_reports.size(); ++i) {
        const curve_flatten_report_t& r = curve_reports[i];
        json << "    {\"name\": \"" << r.name
             << "\", \"constrained\": " << (r.constrained ? "true" : "false")
             << ", \"inner_radius\": " << r.inner_radius
             << ", \"target_y\": " << r.target_y
             << ", \"max_dy\": " << r.max_dy
             << ", \"mean_abs_diff\": " << r.mean_abs_diff
             << ", \"diff_pixels\": " << r.diff_pixels
             << ", \"clamp_ratio\": " << r.clamp_ratio
             << ", \"min\": " << r.stats.min_v
             << ", \"max\": " << r.stats.max_v
             << ", \"mean\": " << (static_cast<double>(r.stats.sum) / kRawFramePixels)
             << ", \"saturated\": " << r.stats.saturated << "}";
        json << (i + 1 == curve_reports.size() ? "\n" : ",\n");
    }
    json << "  ]\n";
    json << "}\n";

    const std::string md_path = out_dir + "/fit_report.md";
    std::ofstream md(md_path.c_str());
    md << "# Fisheye Reference Fit Report\n\n";
    md << "> 作者：Egor Izmaylov\n\n";
    md << "## 输入\n";
    md << "- raw endian: `" << (big_endian ? "big" : "little") << "`\n";
    md << "- image: `" << kFisheyeImageWidth << "x" << kFisheyeImageHeight << " raw16`\n";
    for (size_t i = 0; i < input_files.size(); ++i) {
        md << "- frame " << i << ": `" << input_files[i] << "`\n";
    }
    md << "\n## 拟合结果\n";
    md << "- cx: `" << fit.cx << "`\n";
    md << "- cy: `" << fit.cy << "`\n";
    md << "- radius_px: `" << fit.radius << "`\n";
    md << "- rms_error_px: `" << fit.rms_error << "`\n";
    md << "- points: `" << fit.kept_points << "/" << fit.initial_points << "`\n\n";
    md << "## 内圈下半边界拟合\n";
    md << "- inner_radius_px: `" << curve.radius << "`\n";
    md << "- target_y: `" << curve.target_y << "`\n";
    md << "- points: `" << curve.kept_points << "/" << curve.initial_points << "`\n\n";
    md << "## 参考图指标\n";
    md << "| variant | constrained | max_dx | max_dy | clamp_ratio | mean_abs_diff | diff_pixels | min | max | mean |\n";
    md << "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n";
    for (size_t i = 0; i < reports.size(); ++i) {
        const variant_report_t& r = reports[i];
        md << "| " << r.name
           << " | " << (r.constrained ? "yes" : "no")
           << " | " << r.max_dx
           << " | " << r.max_dy
           << " | " << r.clamp_ratio
           << " | " << r.mean_abs_diff
           << " | " << r.diff_pixels
           << " | " << r.stats.min_v
           << " | " << r.stats.max_v
           << " | " << (static_cast<double>(r.stats.sum) / kRawFramePixels)
           << " |\n";
    }
    md << "\n## 内圈拉平参考图指标\n";
    md << "| variant | constrained | inner_radius | target_y | max_dy | clamp_ratio | mean_abs_diff | diff_pixels | min | max | mean |\n";
    md << "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n";
    for (size_t i = 0; i < curve_reports.size(); ++i) {
        const curve_flatten_report_t& r = curve_reports[i];
        md << "| " << r.name
           << " | " << (r.constrained ? "yes" : "no")
           << " | " << r.inner_radius
           << " | " << r.target_y
           << " | " << r.max_dy
           << " | " << r.clamp_ratio
           << " | " << r.mean_abs_diff
           << " | " << r.diff_pixels
           << " | " << r.stats.min_v
           << " | " << r.stats.max_v
           << " | " << (static_cast<double>(r.stats.sum) / kRawFramePixels)
           << " |\n";
    }
    md << "\n## 结论提示\n";
    md << "- 若 full-frame 参考图效果仍弱，优先怀疑畸变表不是完整去畸变模型，或缺少真实 `fx/fy/cx/cy`。\n";
    md << "- 若 full-frame 明显优于 constrained，则当前 200 行缓存是主要限制。\n";
    md << "- `curve_flatten_full` 用于判断内圈下半边界能否被拉平；`curve_flatten_constrained` 用于判断 96 行窗口内的可上板效果。\n";
    md << "- `preview_contact.ppm` 的排列顺序为：input、infrared_forward_full、infrared_inverse_full、laser_forward_full、laser_inverse_full、infrared_forward_constrained、infrared_inverse_constrained、laser_forward_constrained、laser_inverse_constrained。\n";
}

int main(int argc, char** argv) {
    const bool big_endian = env_is_big_endian();
    const std::string out_dir = env_or_default("FISHEYE_REF_OUT_DIR", "fisheye_reference_fit");
    make_dir(out_dir);

    if (argc < 2) {
        std::cerr << "ERROR: no raw16 input files. Pass files through csim_design -argv." << std::endl;
        return 4;
    }

    std::vector<std::string> input_files;
    std::vector<std::vector<uint16_t> > frames;
    for (int i = 1; i < argc; ++i) {
        input_files.push_back(argv[i]);
        frames.push_back(read_raw16(argv[i], big_endian));
        std::cout << "INFO: loaded raw frame " << argv[i] << std::endl;
    }

    std::vector<uint32_t> mean_acc(kRawFramePixels, 0);
    for (size_t f = 0; f < frames.size(); ++f) {
        for (int i = 0; i < kRawFramePixels; ++i) {
            mean_acc[i] += frames[f][i];
        }
    }
    std::vector<uint16_t> mean_frame(kRawFramePixels, 0);
    for (int i = 0; i < kRawFramePixels; ++i) {
        mean_frame[i] = static_cast<uint16_t>((mean_acc[i] + frames.size() / 2) / frames.size());
    }

    const fit_result_t fit = robust_fit_circle(mean_frame);
    const std::vector<uint16_t>& reference_input = frames.back();
    const curve_fit_t curve = detect_lower_inner_curve(reference_input, fit);
    std::vector<variant_report_t> reports;
    std::vector<curve_flatten_report_t> curve_reports;
    std::vector<std::vector<uint16_t> > preview_images;
    preview_images.push_back(reference_input);

    struct variant_def_t {
        const char* name;
        const ap_uint<18>* lut;
        bool inverse;
        bool constrained;
    };
    const variant_def_t variants[] = {
        {"infrared_forward_full", kInfraredScaleQ16, false, false},
        {"infrared_inverse_full", kInfraredScaleQ16, true, false},
        {"laser_forward_full", kLaserScaleQ16, false, false},
        {"laser_inverse_full", kLaserScaleQ16, true, false},
        {"infrared_forward_constrained", kInfraredScaleQ16, false, true},
        {"infrared_inverse_constrained", kInfraredScaleQ16, true, true},
        {"laser_forward_constrained", kLaserScaleQ16, false, true},
        {"laser_inverse_constrained", kLaserScaleQ16, true, true}
    };

    write_pgm16(out_dir + "/input.pgm", reference_input);
    write_raw16_le(out_dir + "/input.raw", reference_input);

    for (size_t i = 0; i < sizeof(variants) / sizeof(variants[0]); ++i) {
        variant_report_t report;
        report.name = variants[i].name;
        report.constrained = variants[i].constrained;
        const std::vector<uint16_t> output = remap_reference(reference_input,
                                                            fit,
                                                            variants[i].lut,
                                                            variants[i].inverse,
                                                            variants[i].constrained,
                                                            report);
        reports.push_back(report);
        preview_images.push_back(output);
        write_pgm16(out_dir + "/" + report.name + ".pgm", output);
        write_raw16_le(out_dir + "/" + report.name + ".raw", output);
        write_absdiff_pgm16(out_dir + "/diff_" + report.name + ".pgm", reference_input, output);
        std::cout << "INFO: wrote " << report.name
                  << " max_dx=" << report.max_dx
                  << " max_dy=" << report.max_dy
                  << " clamp_ratio=" << report.clamp_ratio
                  << " mean_abs_diff=" << report.mean_abs_diff << std::endl;
    }

    struct curve_variant_def_t {
        const char* name;
        curve_fit_t curve;
        bool constrained;
    };
    std::vector<curve_variant_def_t> curve_variants;
    curve_variants.push_back({"curve_flatten_detected_full", curve, false});
    curve_variants.push_back({"curve_flatten_detected_constrained", curve, true});
    curve_variants.push_back({"curve_flatten_r820_tangent_full", make_tangent_curve(fit, 820.0), false});
    curve_variants.push_back({"curve_flatten_r820_tangent_constrained", make_tangent_curve(fit, 820.0), true});
    curve_variants.push_back({"curve_flatten_r880_tangent_full", make_tangent_curve(fit, 880.0), false});
    curve_variants.push_back({"curve_flatten_r880_tangent_constrained", make_tangent_curve(fit, 880.0), true});
    curve_variants.push_back({"curve_flatten_r939_tangent_full", make_tangent_curve(fit, 939.0), false});
    curve_variants.push_back({"curve_flatten_r939_tangent_constrained", make_tangent_curve(fit, 939.0), true});
    for (size_t i = 0; i < curve_variants.size(); ++i) {
        curve_flatten_report_t report;
        report.name = curve_variants[i].name;
        report.constrained = curve_variants[i].constrained;
        const std::vector<uint16_t> output = curve_flatten_reference(reference_input,
                                                                     curve_variants[i].curve,
                                                                     curve_variants[i].constrained,
                                                                     report);
        curve_reports.push_back(report);
        preview_images.push_back(output);
        write_pgm16(out_dir + "/" + report.name + ".pgm", output);
        write_raw16_le(out_dir + "/" + report.name + ".raw", output);
        write_absdiff_pgm16(out_dir + "/diff_" + report.name + ".pgm", reference_input, output);
        std::cout << "INFO: wrote " << report.name
                  << " inner_radius=" << report.inner_radius
                  << " target_y=" << report.target_y
                  << " max_dy=" << report.max_dy
                  << " clamp_ratio=" << report.clamp_ratio
                  << " mean_abs_diff=" << report.mean_abs_diff << std::endl;
    }

    write_preview_ppm(out_dir + "/preview_contact.ppm", preview_images);
    write_reports(out_dir, input_files, big_endian, fit, calc_stats(reference_input), curve, reports, curve_reports);

    std::cout << "INFO: fit cx=" << fit.cx
              << " cy=" << fit.cy
              << " radius=" << fit.radius
              << " rms=" << fit.rms_error
              << " points=" << fit.kept_points << "/" << fit.initial_points << std::endl;
    std::cout << "INFO: lower inner curve radius=" << curve.radius
              << " target_y=" << curve.target_y
              << " points=" << curve.kept_points << "/" << curve.initial_points << std::endl;
    std::cout << "INFO: reference fit outputs written to " << out_dir << std::endl;

    assert(fit.kept_points >= 32);
    assert(fit.radius >= kFitRadiusMin && fit.radius <= kFitRadiusMax);
    assert(curve.kept_points >= 32);
    return 0;
}
