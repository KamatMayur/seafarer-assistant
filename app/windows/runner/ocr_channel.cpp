#include "ocr_channel.h"

#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Data.Pdf.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Storage.h>

#include <algorithm>
#include <cwctype>
#include <thread>
#include <vector>

namespace {

using namespace winrt;
using namespace winrt::Windows::Graphics::Imaging;
using winrt::Windows::Media::Ocr::OcrEngine;
using winrt::Windows::Storage::StorageFile;
using winrt::Windows::Storage::Streams::IRandomAccessStream;
using winrt::Windows::Storage::Streams::InMemoryRandomAccessStream;

constexpr uint32_t kMaxPdfPages = 2;

SoftwareBitmap Decode(IRandomAccessStream const& stream) {
  auto decoder = BitmapDecoder::CreateAsync(stream).get();
  const uint32_t w = decoder.OrientedPixelWidth(), h = decoder.OrientedPixelHeight();
  const uint32_t limit = OcrEngine::MaxImageDimension();
  BitmapTransform transform;
  if (w > limit || h > limit) {
    const double scale = static_cast<double>(limit) / (std::max)(w, h);
    transform.ScaledWidth(static_cast<uint32_t>(w * scale));
    transform.ScaledHeight(static_cast<uint32_t>(h * scale));
    transform.InterpolationMode(BitmapInterpolationMode::Fant);
  }
  return decoder
      .GetSoftwareBitmapAsync(BitmapPixelFormat::Bgra8, BitmapAlphaMode::Premultiplied, transform,
                              ExifOrientationMode::RespectExifOrientation, ColorManagementMode::DoNotColorManage)
      .get();
}

OcrEngine CreateEngine() {
  OcrEngine engine = OcrEngine::TryCreateFromUserProfileLanguages();
  if (!engine) {
    winrt::Windows::Globalization::Language english(L"en-US");
    if (OcrEngine::IsLanguageSupported(english)) engine = OcrEngine::TryCreateFromLanguage(english);
  }
  if (!engine) {
    auto languages = OcrEngine::AvailableRecognizerLanguages();
    if (languages.Size() > 0) engine = OcrEngine::TryCreateFromLanguage(languages.GetAt(0));
  }
  return engine;
}

// Windows OCR returns text blocks column by column (all labels, then all values). Rebuild visual rows from the
// line positions so a label and its value end up on one line, separated by 4 spaces.
std::string Recognize(OcrEngine const& engine, SoftwareBitmap const& bitmap) {
  struct Line {
    float top, bottom, left;
    std::string text;
  };
  std::vector<Line> lines;
  for (auto const& line : engine.RecognizeAsync(bitmap).get().Lines()) {
    float top = 1e9f, bottom = 0, left = 1e9f;
    for (auto const& word : line.Words()) {
      auto r = word.BoundingRect();
      top = (std::min)(top, r.Y);
      bottom = (std::max)(bottom, r.Y + r.Height);
      left = (std::min)(left, r.X);
    }
    lines.push_back({top, bottom, left, winrt::to_string(line.Text())});
  }
  std::sort(lines.begin(), lines.end(), [](Line const& a, Line const& b) { return a.top < b.top; });

  std::vector<std::vector<Line>> rows;
  for (auto& line : lines) {
    const float center = (line.top + line.bottom) / 2;
    if (!rows.empty()) {
      auto const& first = rows.back().front();
      if (center > first.top && center < first.bottom) {
        rows.back().push_back(std::move(line));
        continue;
      }
    }
    rows.push_back({std::move(line)});
  }

  std::string out;
  for (auto& row : rows) {
    std::sort(row.begin(), row.end(), [](Line const& a, Line const& b) { return a.left < b.left; });
    for (size_t i = 0; i < row.size(); ++i) {
      if (i > 0) out += "    ";
      out += row[i].text;
    }
    out += '\n';
  }
  return out;
}

bool IsPdf(std::wstring path) {
  std::transform(path.begin(), path.end(), path.begin(), [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return path.size() >= 4 && path.compare(path.size() - 4, 4, L".pdf") == 0;
}

// Runs on a worker thread (WinRT's .get() is not allowed on the UI thread).
std::string ReadText(std::wstring const& path) {
  OcrEngine engine = CreateEngine();
  if (!engine) throw std::runtime_error("no OCR language is installed in Windows");
  StorageFile file = StorageFile::GetFileFromPathAsync(path).get();
  if (!IsPdf(path)) return Recognize(engine, Decode(file.OpenReadAsync().get()));

  auto pdf = winrt::Windows::Data::Pdf::PdfDocument::LoadFromFileAsync(file).get();
  std::string text;
  for (uint32_t i = 0; i < (std::min)(pdf.PageCount(), kMaxPdfPages); ++i) {
    auto page = pdf.GetPage(i);
    winrt::Windows::Data::Pdf::PdfPageRenderOptions options;
    options.DestinationWidth(static_cast<uint32_t>(page.Size().Width * 3));  // ~288 dpi
    InMemoryRandomAccessStream stream;
    page.RenderToStreamAsync(stream, options).get();
    stream.Seek(0);
    text += Recognize(engine, Decode(stream));
  }
  return text;
}

}  // namespace

OcrChannel::OcrChannel(flutter::BinaryMessenger* messenger, HWND window) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "seafarer/ocr", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](auto const& call, auto result) {
    if (call.method_name() != "readText") {
      result->NotImplemented();
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    const std::string* path = nullptr;
    if (args) {
      auto it = args->find(flutter::EncodableValue("path"));
      if (it != args->end()) path = std::get_if<std::string>(&it->second);
    }
    if (!path) {
      result->Error("bad_args", "path is required");
      return;
    }
    WPARAM id;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      id = next_id_++;
      jobs_[id].result = std::move(result);
    }
    std::wstring wide(winrt::to_hstring(*path));
    std::replace(wide.begin(), wide.end(), L'/', L'\\');  // StorageFile rejects forward slashes
    std::thread([this, id, wide]() {
      bool ok = false;
      std::string text;
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        text = ReadText(wide);
        ok = true;
      } catch (winrt::hresult_error const& e) {
        text = winrt::to_string(e.message());
      } catch (std::exception const& e) {
        text = e.what();
      }
      winrt::uninit_apartment();
      {
        std::lock_guard<std::mutex> lock(mutex_);
        jobs_[id].ok = ok;
        jobs_[id].text = std::move(text);
      }
      PostMessage(window_, kDoneMessage, id, 0);
    }).detach();
  });
}

bool OcrChannel::HandleMessage(UINT message, WPARAM wparam) {
  if (message != kDoneMessage) return false;
  Job job;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = jobs_.find(wparam);
    if (it == jobs_.end()) return true;
    job = std::move(it->second);
    jobs_.erase(it);
  }
  if (job.ok) {
    job.result->Success(flutter::EncodableValue(job.text));
  } else {
    job.result->Error("ocr_failed", job.text);
  }
  return true;
}
