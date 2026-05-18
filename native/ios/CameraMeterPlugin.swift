import AVFoundation
import Flutter
import UIKit

/// Real-metering plugin: an AVCaptureSession streams the camera's own
/// auto-exposure metadata (exposure duration, ISO, aperture) plus the
/// metered region's mean luminance so Dart can derive an absolute EV with
/// no calibration. Copied into the generated Runner target by CI.
public class CameraMeterPlugin: NSObject, FlutterPlugin,
  FlutterStreamHandler, AVCaptureVideoDataOutputSampleBufferDelegate {

  private var sink: FlutterEventSink?
  private let session = AVCaptureSession()
  private var device: AVCaptureDevice?
  private let queue = DispatchQueue(label: "minilight.cam")
  private var regionMode = 1
  private var pointNx: Double?
  private var pointNy: Double?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CameraMeterPlugin()
    let m = FlutterMethodChannel(
      name: "minilight/exposure",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: m)
    let e = FlutterEventChannel(
      name: "minilight/exposure_events",
      binaryMessenger: registrar.messenger())
    e.setStreamHandler(instance)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "start":
      if let a = call.arguments as? [String: Any],
        let r = a["regionMode"] as? Int { regionMode = r }
      start()
      result(nil)
    case "setRegion":
      if let a = call.arguments as? [String: Any],
        let r = a["regionMode"] as? Int { regionMode = r }
      result(nil)
    case "setPoint":
      let a = call.arguments as? [String: Any]
      pointNx = a?["nx"] as? Double
      pointNy = a?["ny"] as? Double
      result(nil)
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func start() {
    queue.async {
      guard self.device == nil else { return }
      self.session.beginConfiguration()
      self.session.sessionPreset = .low
      guard
        let dev = AVCaptureDevice.default(
          .builtInWideAngleCamera, for: .video, position: .back),
        let input = try? AVCaptureDeviceInput(device: dev)
      else { return }
      self.device = dev
      if self.session.canAddInput(input) { self.session.addInput(input) }
      let output = AVCaptureVideoDataOutput()
      output.alwaysDiscardsLateVideoFrames = true
      output.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
      ]
      output.setSampleBufferDelegate(self, queue: self.queue)
      if self.session.canAddOutput(output) { self.session.addOutput(output) }
      self.session.commitConfiguration()
      self.session.startRunning()
    }
  }

  private func stop() {
    queue.async {
      if self.session.isRunning { self.session.stopRunning() }
      for i in self.session.inputs { self.session.removeInput(i) }
      for o in self.session.outputs { self.session.removeOutput(o) }
      self.device = nil
    }
  }

  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer),
      let dev = device else { return }
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let w = CVPixelBufferGetWidthOfPlane(pb, 0)
    let h = CVPixelBufferGetHeightOfPlane(pb, 0)
    guard let base = CVPixelBufferGetBaseAddressOfPlane(pb, 0) else { return }
    let stride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
    let ptr = base.assumingMemoryBound(to: UInt8.self)

    var left = 0, top = 0, rw = w, rh = h
    if let px = pointNx, let py = pointNy {
      let s = max(2, Int(Double(min(w, h)) * 0.08))
      left = min(max(0, Int(px * Double(w)) - s / 2), w - s)
      top = min(max(0, Int(py * Double(h)) - s / 2), h - s)
      rw = s; rh = s
    } else if regionMode == 0 {
      let s = max(2, Int(Double(min(w, h)) * 0.08))
      left = (w - s) / 2; top = (h - s) / 2; rw = s; rh = s
    }

    var sum = 0.0, count = 0
    var y = top
    while y < top + rh {
      var x = left
      let row = y * stride
      while x < left + rw {
        sum += Double(ptr[row + x]); count += 1; x += 4
      }
      y += 4
    }
    let mean = count == 0 ? 0.0 : sum / Double(count) / 255.0
    let linear = pow(mean, 2.2)
    let expSeconds = CMTimeGetSeconds(dev.exposureDuration)
    let payload: [String: Any] = [
      "exposureNs": expSeconds * 1e9,
      "iso": Double(dev.iso),
      "apertureF": Double(dev.lensAperture),
      "midLuma": linear,
    ]
    DispatchQueue.main.async { self.sink?(payload) }
  }
}
