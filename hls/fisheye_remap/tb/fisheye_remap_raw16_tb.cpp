// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 使用真实 2048x2048 raw16 相机帧验证 fisheye_remap HLS 输出效果。
// 数据流位置    : 软件侧模拟 200 行环形 BRAM，驱动 HLS 核输出旧 SRIO packet 协议。
// 维护边界      : 仅用于 HLS C 仿真和图像可视化，不改变板级硬件接口。
// ============================================================================
#include "fisheye_remap_reader_hls.h"
#include "distortion_lut.h"

#include <algorithm>
#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <fstream>
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

struct captured_frame_t {
    std::vector<uint16_t> pixels;
    uint64_t headers;
    uint64_t payloads;
    uint64_t tlasts;
    uint64_t protocol_errors;
    int completed_frames;

    captured_frame_t()
        : pixels(kRawFramePixels, 0),
          headers(0),
          payloads(0),
          tlasts(0),
          protocol_errors(0),
          completed_frames(0) {}
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

static int env_int_or_default(const char* name, int fallback) {
    const char* value = std::getenv(name);
    return (value && value[0]) ? std::atoi(value) : fallback;
}

static bool env_bool_or_default(const char* name, bool fallback) {
    const char* value = std::getenv(name);
    if (!value || !value[0]) {
        return fallback;
    }
    return std::atoi(value) != 0;
}

static std::string frame_path(const std::string& out_dir,
                              const std::string& prefix,
                              int frame_idx,
                              const std::string& ext) {
    std::ostringstream oss;
    oss << out_dir << "/" << prefix << "_frame_";
    oss.width(4);
    oss.fill('0');
    oss << frame_idx << ext;
    return oss.str();
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

static void write_raw16_le(const std::string& path, const std::vector<uint16_t>& pixels) {
    std::ofstream out(path.c_str(), std::ios::binary);
    for (size_t i = 0; i < pixels.size(); ++i) {
        const unsigned char lo = static_cast<unsigned char>(pixels[i] & 0xff);
        const unsigned char hi = static_cast<unsigned char>((pixels[i] >> 8) & 0xff);
        out.put(static_cast<char>(lo));
        out.put(static_cast<char>(hi));
    }
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

static void write_frame_pair(const std::string& out_dir,
                             const std::string& prefix,
                             int frame_idx,
                             const std::vector<uint16_t>& pixels) {
    write_pgm16(frame_path(out_dir, prefix, frame_idx, ".pgm"), pixels);
    write_raw16_le(frame_path(out_dir, prefix, frame_idx, ".raw"), pixels);
}

static void reset_reader() {
    // 新代码：Egor Izmaylov
    // 稳定上板版本中 HLS 只负责地址计算，发包节奏由 RTL 固定生成；这里用空拍清一次组合输出。
    ap_uint<1> out_valid = 0;
    line_slot_addr_t src_slot = 0;
    ap_uint<11> src_x = 0;
    ap_uint<7> packet_pixel_idx_out = 0;
    fisheye_remap_addr_hls(0, 0, 0, 0, 0, 0x80000000U,
                           out_valid, src_slot, src_x, packet_pixel_idx_out);
}

static uint16_t ring_read(const std::vector<uint16_t>& ring, bram_addr_t addr) {
    const uint32_t slot = static_cast<uint32_t>((addr >> 11) & 0xff);
    const uint32_t x = static_cast<uint32_t>(addr & 0x7ff);
    return ring[(slot % kFisheyeLineBufferDepth) * kFisheyeImageWidth + x];
}

static void accept_word(captured_frame_t& result,
                        uint64_t data,
                        bool last,
                        int& active_line,
                        int& active_packet,
                        int& payload_index) {
    const bool is_header = ((data >> 32) == 0x00602000ULL);
    if (is_header) {
        active_line = static_cast<int>((data >> 12) & 0xfff);
        active_packet = static_cast<int>((data >> 8) & 0xf);
        payload_index = 0;
        result.headers++;
        if (last || active_line >= kFisheyeImageHeight || active_packet >= kFisheyePacketsPerLine) {
            result.protocol_errors++;
        }
        return;
    }

    if (active_line < 0 || active_packet < 0 || payload_index >= kFisheyePayloadWordsPerPacket) {
        result.protocol_errors++;
        return;
    }

    const int base_x = active_packet * kFisheyePacketPixels + payload_index * kFisheyePixelsPerWord;
    for (int lane = 0; lane < kFisheyePixelsPerWord; ++lane) {
        const int x = base_x + lane;
        const uint16_t pixel = static_cast<uint16_t>((data >> (lane * 16)) & 0xffff);
        if (x < kFisheyeImageWidth) {
            result.pixels[active_line * kFisheyeImageWidth + x] = pixel;
        }
    }

    result.payloads++;
    if (last) {
        result.tlasts++;
        if (payload_index != (kFisheyePayloadWordsPerPacket - 1)) {
            result.protocol_errors++;
        }
    } else if (payload_index == (kFisheyePayloadWordsPerPacket - 1)) {
        result.protocol_errors++;
    }
    payload_index++;
}

static captured_frame_t simulate_mode(const std::vector<std::vector<uint16_t> >& frames,
                                      uint32_t ctrl,
                                      const std::string& out_dir,
                                      const std::string& mode_name,
                                      bool save_each_frame) {
    reset_reader();

    std::vector<uint16_t> ring(kFisheyeLineBufferDepth * kFisheyeImageWidth, 0);
    std::vector<uint16_t> line_table(kFisheyeLineBufferDepth, 0);
    captured_frame_t result;

    int active_line = -1;
    int active_packet = -1;
    int payload_index = 0;
    int emitted_lines = 0;

    const int total_input_lines = static_cast<int>(frames.size()) * kFisheyeImageHeight;
    const int total_lines_with_flush = total_input_lines + kFisheyeHalfLineBufferDepth;
    for (int global_line = 0; global_line < total_lines_with_flush; ++global_line) {
        const int slot = global_line % kFisheyeLineBufferDepth;
        const int frame_idx = (global_line < total_input_lines)
                                  ? (global_line / kFisheyeImageHeight)
                                  : 0;
        const int line = global_line % kFisheyeImageHeight;
        const std::vector<uint16_t>& src = frames[std::min(frame_idx, static_cast<int>(frames.size()) - 1)];
        std::copy(src.begin() + line * kFisheyeImageWidth,
                  src.begin() + (line + 1) * kFisheyeImageWidth,
                  ring.begin() + slot * kFisheyeImageWidth);
        line_table[slot] = static_cast<uint16_t>(line);

        const bool should_emit_line = (global_line >= kFisheyeHalfLineBufferDepth);
        if (!should_emit_line) {
            continue;
        }

        const int delayed_slot = (slot + kFisheyeHalfLineBufferDepth) % kFisheyeLineBufferDepth;
        const uint16_t out_line = line_table[delayed_slot];

        // 新代码：Egor Izmaylov
        // 软件侧复刻新的 RTL packetizer：每行 16 包，每包 1 header + 32 payload，HLS 只给出源行槽和源 x。
        for (int packet = 0; packet < kFisheyePacketsPerLine; ++packet) {
            const uint64_t header = (0x00602000ULL << 32)
                                  | (static_cast<uint64_t>(out_line) << 12)
                                  | (static_cast<uint64_t>(packet) << 8);
            accept_word(result, header, false, active_line, active_packet, payload_index);

            for (int payload = 0; payload < kFisheyePayloadWordsPerPacket; ++payload) {
                uint64_t data = 0;
                for (int lane = 0; lane < kFisheyePixelsPerWord; ++lane) {
                    const int out_x = packet * kFisheyePacketPixels +
                                      payload * kFisheyePixelsPerWord +
                                      lane;
                    ap_uint<1> out_valid = 0;
                    line_slot_addr_t src_slot = 0;
                    ap_uint<11> src_x = 0;
                    ap_uint<7> packet_pixel_idx_out = 0;
                    fisheye_remap_addr_hls(1,
                                           static_cast<ap_uint<11> >(out_x),
                                           static_cast<ap_uint<12> >(out_line),
                                           static_cast<line_slot_addr_t>(delayed_slot),
                                           static_cast<ap_uint<7> >(out_x & 0x7f),
                                           static_cast<ap_uint<32> >(ctrl),
                                           out_valid,
                                           src_slot,
                                           src_x,
                                           packet_pixel_idx_out);
                    if (!out_valid) {
                        result.protocol_errors++;
                    }
                    const uint32_t src_index = (src_slot.to_uint() % kFisheyeLineBufferDepth) *
                                               kFisheyeImageWidth + src_x.to_uint();
                    const uint16_t pixel = ring[src_index];
                    data |= static_cast<uint64_t>(pixel) << (lane * 16);
                }
                const bool last = (payload == (kFisheyePayloadWordsPerPacket - 1));
                accept_word(result, data, last, active_line, active_packet, payload_index);
            }
        }
        if (out_line == (kFisheyeImageHeight - 1)) {
            result.completed_frames++;
            if (save_each_frame) {
                const int frame_idx = result.completed_frames - 1;
                const std::vector<uint16_t> frame_snapshot(result.pixels);
                write_frame_pair(out_dir, mode_name, frame_idx, frame_snapshot);
            }
        }
        emitted_lines++;
    }

    if (!save_each_frame) {
        result.completed_frames = emitted_lines / kFisheyeImageHeight;
    }
    return result;
}

static uint64_t count_diff(const std::vector<uint16_t>& a, const std::vector<uint16_t>& b) {
    uint64_t diff = 0;
    for (size_t i = 0; i < a.size() && i < b.size(); ++i) {
        if (a[i] != b[i]) {
            diff++;
        }
    }
    return diff;
}

static void append_stats(std::ostream& os, const char* name, const captured_frame_t& r) {
    uint16_t min_v = std::numeric_limits<uint16_t>::max();
    uint16_t max_v = 0;
    uint64_t sum = 0;
    uint64_t saturated = 0;
    for (size_t i = 0; i < r.pixels.size(); ++i) {
        min_v = std::min(min_v, r.pixels[i]);
        max_v = std::max(max_v, r.pixels[i]);
        sum += r.pixels[i];
        saturated += (r.pixels[i] == 65535) ? 1 : 0;
    }
    os << name
       << " headers=" << r.headers
       << " payloads=" << r.payloads
       << " tlasts=" << r.tlasts
       << " completed_frames=" << r.completed_frames
       << " protocol_errors=" << r.protocol_errors
       << " min=" << min_v
       << " max=" << max_v
       << " mean=" << (sum / r.pixels.size())
       << " saturated=" << saturated
       << "\n";
}

int main(int argc, char** argv) {
    const bool big_endian = (env_or_default("FISHEYE_RAW_ENDIAN", "little") == "big");
    const int max_frames = std::max(1, env_int_or_default("FISHEYE_RAW_MAX_FRAMES", 3));
    const std::string out_dir = env_or_default("FISHEYE_RAW_OUT_DIR", "fisheye_raw_outputs");
    const bool save_each_frame = env_bool_or_default("FISHEYE_RAW_SAVE_EACH_FRAME", false);
    make_dir(out_dir);

    std::vector<std::string> paths;
    for (int i = 1; i < argc && static_cast<int>(paths.size()) < max_frames; ++i) {
        paths.push_back(argv[i]);
    }
    if (paths.empty()) {
        std::cerr << "ERROR: no raw16 input files. Pass files through csim_design -argv." << std::endl;
        return 4;
    }

    std::vector<std::vector<uint16_t> > frames;
    for (size_t i = 0; i < paths.size(); ++i) {
        frames.push_back(read_raw16(paths[i], big_endian));
        std::cout << "INFO: loaded raw frame " << paths[i] << std::endl;
        if (save_each_frame) {
            write_frame_pair(out_dir, "input", static_cast<int>(i), frames.back());
        }
    }

    captured_frame_t bypass = simulate_mode(frames, 0x00000000U, out_dir, "bypass", save_each_frame);
    captured_frame_t remap_no_adaptive = simulate_mode(frames, 0x00000011U, out_dir, "remap_no_adaptive", save_each_frame);
    captured_frame_t remap_infrared = simulate_mode(frames, 0x00000001U, out_dir, "remap_infrared", save_each_frame);

    write_pgm16(out_dir + "/input.pgm", frames.back());
    write_pgm16(out_dir + "/bypass.pgm", bypass.pixels);
    write_pgm16(out_dir + "/remap_no_adaptive.pgm", remap_no_adaptive.pixels);
    write_pgm16(out_dir + "/remap_infrared.pgm", remap_infrared.pixels);
    write_raw16_le(out_dir + "/bypass.raw", bypass.pixels);
    write_raw16_le(out_dir + "/remap_no_adaptive.raw", remap_no_adaptive.pixels);
    write_raw16_le(out_dir + "/remap_infrared.raw", remap_infrared.pixels);

    std::ofstream summary((out_dir + "/summary.txt").c_str());
    summary << "raw_endian=" << (big_endian ? "big" : "little") << "\n";
    summary << "frames=" << frames.size() << "\n";
    summary << "save_each_frame=" << (save_each_frame ? 1 : 0) << "\n";
    summary << "per_frame_output_count=" << (save_each_frame ? bypass.completed_frames : 0) << "\n";
    append_stats(summary, "bypass", bypass);
    append_stats(summary, "remap_no_adaptive", remap_no_adaptive);
    append_stats(summary, "remap_infrared", remap_infrared);
    summary << "diff_bypass_vs_no_adaptive=" << count_diff(bypass.pixels, remap_no_adaptive.pixels) << "\n";
    summary << "diff_bypass_vs_infrared=" << count_diff(bypass.pixels, remap_infrared.pixels) << "\n";
    summary.close();

    append_stats(std::cout, "bypass", bypass);
    append_stats(std::cout, "remap_no_adaptive", remap_no_adaptive);
    append_stats(std::cout, "remap_infrared", remap_infrared);
    std::cout << "INFO: raw16 outputs written to " << out_dir << std::endl;

    assert(bypass.protocol_errors == 0);
    assert(remap_no_adaptive.protocol_errors == 0);
    assert(remap_infrared.protocol_errors == 0);
    assert(bypass.completed_frames == static_cast<int>(frames.size()));
    assert(remap_no_adaptive.completed_frames == static_cast<int>(frames.size()));
    assert(remap_infrared.completed_frames == static_cast<int>(frames.size()));
    assert(count_diff(bypass.pixels, remap_no_adaptive.pixels) > 0);
    assert(count_diff(bypass.pixels, remap_infrared.pixels) > 0);
    return 0;
}
