#ifndef RUNNER_OCR_CHANNEL_H_
#define RUNNER_OCR_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <map>
#include <memory>
#include <mutex>
#include <string>

// Method channel "seafarer/ocr": readText({path}) -> the text of an image or the first pages of a PDF, read with
// the OCR engine built into Windows (Windows.Media.Ocr, offline). The file never leaves the device.
// OCR runs on a worker thread; the result is handed back to the platform thread through a window message.
class OcrChannel {
 public:
  static constexpr UINT kDoneMessage = WM_APP + 0x51;

  OcrChannel(flutter::BinaryMessenger* messenger, HWND window);

  // Call from the window procedure. Returns true if |message| was a finished OCR job.
  bool HandleMessage(UINT message, WPARAM wparam);

 private:
  struct Job {
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
    bool ok = false;
    std::string text;  // the text, or the error message
  };

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  std::mutex mutex_;
  std::map<WPARAM, Job> jobs_;
  WPARAM next_id_ = 1;
};

#endif  // RUNNER_OCR_CHANNEL_H_
