package com.minilight.app

import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Real-metering plugin: runs a low-res Camera2 session and streams the
 * camera's own auto-exposure metadata plus the metered region's mean
 * luminance, so Dart can compute an absolute EV with no calibration.
 *
 * Copied verbatim into the generated android project by CI.
 */
class CameraMeterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null

    @Volatile private var regionMode = 1
    @Volatile private var pointNx: Double? = null
    @Volatile private var pointNy: Double? = null
    @Volatile private var lastExposureNs = 0L
    @Volatile private var lastIso = 100
    private var apertureF = 1.8f

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        methodChannel = MethodChannel(b.binaryMessenger, "minilight/exposure")
        methodChannel!!.setMethodCallHandler(this)
        eventChannel = EventChannel(b.binaryMessenger, "minilight/exposure_events")
        eventChannel!!.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        stop()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "start" -> {
                regionMode = call.argument<Int>("regionMode") ?: 1
                start(); result.success(null)
            }
            "setRegion" -> {
                regionMode = call.argument<Int>("regionMode") ?: 1
                result.success(null)
            }
            "setPoint" -> {
                pointNx = call.argument<Double>("nx")
                pointNy = call.argument<Double>("ny")
                result.success(null)
            }
            "stop" -> { stop(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    override fun onListen(args: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(args: Any?) { sink = null }

    private fun start() {
        if (device != null) return
        thread = HandlerThread("minilight-cam").also { it.start() }
        handler = Handler(thread!!.looper)
        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = mgr.cameraIdList.firstOrNull {
            mgr.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK
        } ?: mgr.cameraIdList.first()
        val chars = mgr.getCameraCharacteristics(id)
        chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
            ?.firstOrNull()?.let { apertureF = it }

        reader = ImageReader.newInstance(320, 240, ImageFormat.YUV_420_888, 2)
        reader!!.setOnImageAvailableListener({ r ->
            val img = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val luma = meanLuma(img)
                emit(luma)
            } finally {
                img.close()
            }
        }, handler)

        try {
            mgr.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(cam: CameraDevice) {
                    device = cam
                    val req = cam.createCaptureRequest(
                        CameraDevice.TEMPLATE_PREVIEW
                    ).apply {
                        addTarget(reader!!.surface)
                        set(
                            CaptureRequest.CONTROL_AE_MODE,
                            CaptureRequest.CONTROL_AE_MODE_ON
                        )
                    }
                    cam.createCaptureSession(
                        listOf(reader!!.surface),
                        object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(s: CameraCaptureSession) {
                                session = s
                                s.setRepeatingRequest(
                                    req.build(), captureCallback, handler
                                )
                            }
                            override fun onConfigureFailed(
                                s: CameraCaptureSession
                            ) {}
                        },
                        handler
                    )
                }
                override fun onDisconnected(cam: CameraDevice) { cam.close() }
                override fun onError(cam: CameraDevice, e: Int) { cam.close() }
            }, handler)
        } catch (e: SecurityException) {
            sink?.error("permission", "Camera permission denied", null)
        }
    }

    private val captureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            s: CameraCaptureSession,
            req: CaptureRequest,
            result: TotalCaptureResult
        ) {
            result.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let {
                lastExposureNs = it
            }
            result.get(CaptureResult.SENSOR_SENSITIVITY)?.let { lastIso = it }
            result.get(CaptureResult.LENS_APERTURE)?.let { apertureF = it }
        }
    }

    private fun meanLuma(img: android.media.Image): Double {
        val y = img.planes[0]
        val buf = y.buffer
        val rowStride = y.rowStride
        val w = img.width
        val h = img.height
        var left = 0; var top = 0; var rw = w; var rh = h
        val px = pointNx; val py = pointNy
        if (px != null && py != null) {
            val s = (minOf(w, h) * 0.08).toInt().coerceAtLeast(2)
            left = ((px * w).toInt() - s / 2).coerceIn(0, w - s)
            top = ((py * h).toInt() - s / 2).coerceIn(0, h - s)
            rw = s; rh = s
        } else if (regionMode == 0) {
            val s = (minOf(w, h) * 0.08).toInt().coerceAtLeast(2)
            left = (w - s) / 2; top = (h - s) / 2; rw = s; rh = s
        }
        var sum = 0.0; var count = 0
        var yy = top
        while (yy < top + rh) {
            var xx = left
            val base = yy * rowStride
            while (xx < left + rw) {
                sum += (buf.get(base + xx).toInt() and 0xFF)
                count++
                xx += 4
            }
            yy += 4
        }
        val mean8 = if (count == 0) 0.0 else sum / count / 255.0
        // De-gamma (approx sRGB) to a linear fraction.
        return Math.pow(mean8, 2.2)
    }

    private fun emit(linearLuma: Double) {
        val payload = HashMap<String, Any>()
        payload["exposureNs"] = lastExposureNs
        payload["iso"] = lastIso
        payload["apertureF"] = apertureF.toDouble()
        payload["midLuma"] = linearLuma
        Handler(context.mainLooper).post { sink?.success(payload) }
    }

    private fun stop() {
        try { session?.stopRepeating() } catch (_: Exception) {}
        session?.close(); session = null
        device?.close(); device = null
        reader?.close(); reader = null
        thread?.quitSafely(); thread = null; handler = null
    }
}
