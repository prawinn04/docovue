package com.docovue.docovue

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.net.Uri
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileInputStream

/** DocovuePlugin - Android implementation for on-device OCR using ML Kit */
class DocovuePlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  
  private lateinit var channel: MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null
  private var pendingResult: Result? = null
  
  // ML Kit Text Recognizer
  private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
  
  companion object {
    private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
    private const val CHANNEL_NAME = "docovue"
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "extractText" -> {
        extractTextFromImage(call, result)
      }
      "detectDocumentEdges" -> {
        detectDocumentEdges(call, result)
      }
      "verifyLiveness" -> {
        verifyLiveness(call, result)
      }
      "checkCameraPermission" -> {
        result.success(hasCameraPermission())
      }
      "requestCameraPermission" -> {
        requestCameraPermission(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun extractTextFromImage(call: MethodCall, result: Result) {
    val source = call.argument<String>("source") ?: "camera"
    val languages = call.argument<List<String>>("languages") ?: listOf("en")
    val imagePath = call.argument<String>("imagePath")

    // Check camera permission first
    if (!hasCameraPermission()) {
      result.error("CAMERA_PERMISSION_DENIED", "Camera permission is required", null)
      return
    }

    when (source) {
      "camera" -> {
        // In a real implementation, this would integrate with camera capture
        // For now, we'll return an error indicating this needs camera integration
        result.error("NOT_IMPLEMENTED", "Camera capture integration needed", null)
      }
      "gallery", "file" -> {
        if (imagePath == null) {
          result.error("INVALID_ARGUMENT", "Image path is required for gallery/file source", null)
          return
        }
        processImageFile(imagePath, languages, result)
      }
      else -> {
        result.error("INVALID_ARGUMENT", "Invalid source: $source", null)
      }
    }
  }

  private fun processImageFile(imagePath: String, languages: List<String>, result: Result) {
    try {
      val file = File(imagePath)
      if (!file.exists()) {
        result.error("FILE_NOT_FOUND", "Image file not found: $imagePath", null)
        return
      }

      // Load bitmap from file
      val bitmap = BitmapFactory.decodeFile(imagePath)
      if (bitmap == null) {
        result.error("INVALID_IMAGE", "Could not decode image file", null)
        return
      }

      // Create ML Kit InputImage
      val inputImage = InputImage.fromBitmap(bitmap, 0)

      // Process with ML Kit Text Recognition
      textRecognizer.process(inputImage)
        .addOnSuccessListener { visionText ->
          val textBlocks = mutableListOf<Map<String, Any?>>()
          
          // Extract all text blocks with their positions
          for (block in visionText.textBlocks) {
            for (line in block.lines) {
              for (element in line.elements) {
                val boundingBox = element.boundingBox
                if (boundingBox != null) {
                  val textBlockMap = mutableMapOf<String, Any?>()
                  textBlockMap["text"] = element.text
                  textBlockMap["confidence"] = (element.confidence ?: 0.8)
                  textBlockMap["x"] = boundingBox.left.toDouble()
                  textBlockMap["y"] = boundingBox.top.toDouble()
                  textBlockMap["width"] = (boundingBox.right - boundingBox.left).toDouble()
                  textBlockMap["height"] = (boundingBox.bottom - boundingBox.top).toDouble()
                  textBlockMap["lineIndex"] = null
                  textBlockMap["paragraphIndex"] = null
                  textBlockMap["language"] = null
                  
                  textBlocks.add(textBlockMap)
                }
              }
            }
          }

          // Also get the full text for debugging
          val fullText = visionText.text

          val response = mutableMapOf<String, Any?>()
          response["textBlocks"] = textBlocks
          response["fullText"] = fullText
          response["success"] = true
          
          result.success(response)
        }
        .addOnFailureListener { e ->
          result.error("OCR_PROCESSING_FAILED", "ML Kit text recognition failed: ${e.message}", null)
        }

    } catch (e: Exception) {
      result.error("PROCESSING_ERROR", "Error processing image: ${e.message}", null)
    }
  }

  private fun hasCameraPermission(): Boolean {
    val context = this.context ?: return false
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.CAMERA
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestCameraPermission(result: Result) {
    val activity = this.activity
    if (activity == null) {
      result.error("NO_ACTIVITY", "No activity available to request permission", null)
      return
    }

    if (hasCameraPermission()) {
      result.success(true)
      return
    }

    pendingResult = result
    ActivityCompat.requestPermissions(
      activity,
      arrayOf(Manifest.permission.CAMERA),
      CAMERA_PERMISSION_REQUEST_CODE
    )
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
      val result = pendingResult
      pendingResult = null
      
      if (result != null) {
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(granted)
      }
      return true
    }
    return false
  }

  /**
   * Detects document edges in an image to determine if it's properly positioned
   * within a target bounding box.
   */
  private fun detectDocumentEdges(call: MethodCall, result: Result) {
    try {
      val imagePath = call.argument<String>("imagePath")
      if (imagePath == null) {
        result.error("INVALID_ARGUMENT", "Image path is required", null)
        return
      }

      val file = File(imagePath)
      if (!file.exists()) {
        result.error("FILE_NOT_FOUND", "Image file not found", null)
        return
      }

      val bitmap = BitmapFactory.decodeFile(imagePath)
      if (bitmap == null) {
        result.error("INVALID_IMAGE", "Could not decode image", null)
        return
      }

      // Simple edge detection using brightness analysis
      val edges = detectEdges(bitmap)
      val detected = edges["detected"] as Boolean
      val coverage = edges["coverage"] as Double
      val centered = edges["centered"] as Boolean

      val response = mutableMapOf<String, Any?>(
        "detected" to detected,
        "coverage" to coverage,
        "centered" to centered,
        "edges" to edges["corners"]
      )

      result.success(response)
    } catch (e: Exception) {
      result.error("EDGE_DETECTION_FAILED", "Edge detection failed: ${e.message}", null)
    }
  }

  /**
   * Verifies if the captured image is from a physical original document
   * (anti-spoofing / liveness detection).
   */
  private fun verifyLiveness(call: MethodCall, result: Result) {
    try {
      val imagePath = call.argument<String>("imagePath")
      if (imagePath == null) {
        result.error("INVALID_ARGUMENT", "Image path is required", null)
        return
      }

      val file = File(imagePath)
      if (!file.exists()) {
        result.error("FILE_NOT_FOUND", "Image file not found", null)
        return
      }

      val bitmap = BitmapFactory.decodeFile(imagePath)
      if (bitmap == null) {
        result.error("INVALID_IMAGE", "Could not decode image", null)
        return
      }

      // Perform multiple liveness checks
      val blurScore = detectBlur(bitmap)
      val reflectionScore = detectReflection(bitmap)
      val textureScore = analyzeTexture(bitmap)

      // Aggregate scores (original documents should have low blur, good texture)
      // More lenient thresholds for real-world conditions
      // Physical documents in normal lighting should pass easily
      val isOriginal = blurScore < 80.0 && textureScore > 0.15
      val confidence = if (isOriginal) {
        // Calculate confidence based on multiple factors
        val blurConfidence = Math.min(100.0, blurScore) / 100.0
        val textureConfidence = Math.min(1.0, textureScore)
        val reflectionPenalty = Math.min(reflectionScore / 50.0, 0.3)
        
        Math.max(0.6, (1.0 - blurConfidence) * 0.4 + textureConfidence * 0.5 + (1.0 - reflectionPenalty) * 0.1)
      } else {
        // If failed checks, give detailed reason
        0.3
      }

      val reason = when {
        !isOriginal && blurScore >= 80.0 -> "Image too blurry - hold camera steady"
        !isOriginal && textureScore <= 0.15 -> "Low texture detected - possible screen display"
        reflectionScore > 30.0 -> "High reflection detected - avoid glare"
        isOriginal -> "Physical document verified"
        else -> "Document verification passed"
      }

      val response = mutableMapOf<String, Any?>(
        "isOriginal" to isOriginal,
        "confidence" to confidence,
        "blurScore" to blurScore,
        "textureScore" to textureScore,
        "reflectionScore" to reflectionScore,
        "reason" to reason
      )

      result.success(response)
    } catch (e: Exception) {
      result.error("LIVENESS_CHECK_FAILED", "Liveness verification failed: ${e.message}", null)
    }
  }

  /**
   * Detects document edges using improved brightness and contrast analysis.
   */
  private fun detectEdges(bitmap: Bitmap): Map<String, Any> {
    val width = bitmap.width
    val height = bitmap.height
    val centerX = width / 2
    val centerY = height / 2

    // Analyze center region (where document should be)
    val sampleWidth = width / 3
    val sampleHeight = height / 3
    val startX = centerX - sampleWidth / 2
    val startY = centerY - sampleHeight / 2
    val endX = centerX + sampleWidth / 2
    val endY = centerY + sampleHeight / 2

    var brightPixels = 0
    var darkPixels = 0
    var totalPixels = 0
    var avgBrightness = 0

    // Sample center region
    for (x in startX..endX step 3) {
      for (y in startY..endY step 3) {
        if (x in 0 until width && y in 0 until height) {
          val pixel = bitmap.getPixel(x, y)
          val brightness = getBrightness(pixel)
          avgBrightness += brightness
          
          if (brightness > 180) brightPixels++  // Very bright (paper)
          else if (brightness < 80) darkPixels++ // Very dark (text/background)
          totalPixels++
        }
      }
    }

    if (totalPixels == 0) {
      return mapOf(
        "detected" to false,
        "coverage" to 0.0,
        "centered" to false,
        "corners" to emptyList<Map<String, Int>>()
      )
    }

    avgBrightness /= totalPixels
    val brightRatio = brightPixels.toDouble() / totalPixels
    val darkRatio = darkPixels.toDouble() / totalPixels
    val contrast = brightRatio - darkRatio

    // Document should have:
    // 1. Good average brightness (paper is bright)
    // 2. Some contrast (text vs paper)
    // 3. Reasonable bright pixel ratio
    // OPTIMIZED: More lenient thresholds for better auto-detection
    val detected = avgBrightness > 90 &&  // Lowered from 100
                   brightRatio > 0.25 &&  // Lowered from 0.3
                   brightRatio < 0.95 &&  // Increased from 0.9
                   contrast > 0.08       // Lowered from 0.1
    
    val coverage = if (detected) {
      // Estimate coverage based on bright pixels (assumes paper is bright)
      Math.min(brightRatio * 1.5, 1.0)
    } else {
      brightRatio
    }
    
    val centered = detected && coverage > 0.6

    return mapOf(
      "detected" to detected,
      "coverage" to coverage,
      "centered" to centered,
      "avgBrightness" to avgBrightness,
      "brightRatio" to brightRatio,
      "contrast" to contrast,
      "corners" to listOf(
        mapOf("x" to (centerX - sampleWidth / 2), "y" to (centerY - sampleHeight / 2)),
        mapOf("x" to (centerX + sampleWidth / 2), "y" to (centerY - sampleHeight / 2)),
        mapOf("x" to (centerX - sampleWidth / 2), "y" to (centerY + sampleHeight / 2)),
        mapOf("x" to (centerX + sampleWidth / 2), "y" to (centerY + sampleHeight / 2))
      )
    )
  }

  /**
   * Detects blur in the image using Laplacian variance.
   */
  private fun detectBlur(bitmap: Bitmap): Double {
    val width = bitmap.width
    val height = bitmap.height
    var variance = 0.0
    var count = 0

    // Sample pixels for blur detection (simplified Laplacian)
    for (y in 1 until height - 1 step 5) {
      for (x in 1 until width - 1 step 5) {
        val center = getBrightness(bitmap.getPixel(x, y))
        val left = getBrightness(bitmap.getPixel(x - 1, y))
        val right = getBrightness(bitmap.getPixel(x + 1, y))
        val top = getBrightness(bitmap.getPixel(x, y - 1))
        val bottom = getBrightness(bitmap.getPixel(x, y + 1))

        val laplacian = Math.abs(4 * center - left - right - top - bottom)
        variance += laplacian * laplacian
        count++
      }
    }

    return if (count > 0) Math.sqrt(variance / count) else 100.0
  }

  /**
   * Detects screen reflections that might indicate a photo of a screen.
   */
  private fun detectReflection(bitmap: Bitmap): Double {
    val width = bitmap.width
    val height = bitmap.height
    var brightSpots = 0
    var totalSamples = 0

    // Look for overly bright regions that might indicate screen glare
    for (y in 0 until height step 10) {
      for (x in 0 until width step 10) {
        val brightness = getBrightness(bitmap.getPixel(x, y))
        if (brightness > 240) brightSpots++ // Very bright pixels
        totalSamples++
      }
    }

    return if (totalSamples > 0) (brightSpots.toDouble() / totalSamples) * 100 else 0.0
  }

  /**
   * Analyzes texture patterns (physical documents have more texture than screens).
   */
  private fun analyzeTexture(bitmap: Bitmap): Double {
    val width = bitmap.width
    val height = bitmap.height
    var textureVariance = 0.0
    var count = 0

    // Analyze local variance in small regions
    for (y in 10 until height - 10 step 15) {
      for (x in 10 until width - 10 step 15) {
        var localSum = 0
        var localSumSq = 0
        var localCount = 0

        for (dy in -5..5) {
          for (dx in -5..5) {
            val brightness = getBrightness(bitmap.getPixel(x + dx, y + dy))
            localSum += brightness
            localSumSq += brightness * brightness
            localCount++
          }
        }

        val mean = localSum.toDouble() / localCount
        val variance = (localSumSq.toDouble() / localCount) - (mean * mean)
        textureVariance += variance
        count++
      }
    }

    return if (count > 0) Math.sqrt(textureVariance / count) / 255.0 else 0.0
  }

  /**
   * Helper function to get brightness from a pixel.
   */
  private fun getBrightness(pixel: Int): Int {
    val r = (pixel shr 16) and 0xFF
    val g = (pixel shr 8) and 0xFF
    val b = pixel and 0xFF
    return (r + g + b) / 3
  }
}

/*
 * TODO: Complete Android Implementation
 * 
 * This is a basic skeleton for the Android plugin. To complete the implementation:
 * 
 * 1. Camera Integration:
 *    - Integrate with CameraX or Camera2 API for live camera preview
 *    - Implement auto-capture when document is detected and stable
 *    - Add flash/torch control
 * 
 * 2. Enhanced ML Kit Integration:
 *    - Add support for multiple languages
 *    - Implement confidence scoring improvements
 *    - Add document-specific optimizations (e.g., ID card vs text document modes)
 * 
 * 3. Image Processing:
 *    - Add image preprocessing (contrast, brightness, rotation correction)
 *    - Implement document edge detection and cropping
 *    - Add image quality validation
 * 
 * 4. Performance Optimizations:
 *    - Implement image resizing for faster processing
 *    - Add caching for repeated operations
 *    - Optimize memory usage for large images
 * 
 * 5. Error Handling:
 *    - Add comprehensive error codes and messages
 *    - Implement retry mechanisms for failed operations
 *    - Add logging for debugging (with privacy considerations)
 * 
 * 6. Security & Privacy:
 *    - Ensure no image data is cached or logged inappropriately
 *    - Implement secure temporary file handling
 *    - Add data masking for sensitive information in logs
 * 
 * Dependencies to add to android/build.gradle:
 * 
 * dependencies {
 *     implementation 'com.google.mlkit:text-recognition:16.0.0'
 *     implementation 'androidx.camera:camera-core:1.3.0'
 *     implementation 'androidx.camera:camera-camera2:1.3.0'
 *     implementation 'androidx.camera:camera-lifecycle:1.3.0'
 *     implementation 'androidx.camera:camera-view:1.3.0'
 * }
 */