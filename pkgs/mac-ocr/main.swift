import Cocoa
import CoreImage
import Vision

// let screenCapturePath = "/tmp/ocr.png"
let screenCapturePath = CommandLine.arguments[1]
let recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
let joiner = " "

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent)
}

// func paste(text: String) {
//     let pasteboard = NSPasteboard.general
//     pasteboard.declareTypes([.string], owner: nil)
//     pasteboard.clearContents()
//     pasteboard.setString(text, forType: .string)
//
// }

func recognizeTextHandler(request: VNRequest, error _: Error?) {
    guard let observations = request.results as? [VNRecognizedTextObservation] else {
        return
    }
    let recognizedStrings = observations.compactMap { observation in
        // Return the string of the top VNRecognizedText instance.
        observation.topCandidates(1).first?.string
    }

    // Process the recognized strings.
    let result = recognizedStrings.joined(separator: joiner)

    print(result)

    // paste(text: result)
}

func detectText(fileName: URL) {
    guard
        let ciImage = CIImage(contentsOf: fileName),
        let img = convertCIImageToCGImage(inputImage: ciImage)
    else {
        return
    }

    let requestHandler = VNImageRequestHandler(cgImage: img)

    // Create a new request to recognize text.
    let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
    request.recognitionLanguages = recognitionLanguages

    do {
        // Perform the text-recognition request.
        try requestHandler.perform([request])
    } catch {
        print("Unable to perform the requests: \(error).")
    }
}

func detectImage(fileName: URL) -> Bool {
    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)

    guard let ciImage = CIImage(contentsOf: fileName), let features = detector?.features(in: ciImage) else {
        return false
    }

    var isQRCode = false
    var result = ""
    for feature in features as! [CIQRCodeFeature] {
        if feature.type == "QRCode" {
            isQRCode = true
        }
        result += feature.messageString ?? ""
        result += "\n"
    }

    if isQRCode {
        print(result)
        // paste(text: result)
    }

    return isQRCode
}

func main() {
    // Only support the system above macOS 10.15
    guard #available(OSX 10.15, *) else {
        return print("Only support the system above macOS 10.15")
    }

    // Determine whether the picture contains a QR code, if it contain a QR code, Copy the QR code content to the clipboard
    guard detectImage(fileName: URL(fileURLWithPath: screenCapturePath)) else {
        // If do not include QR codes, identify text content and supplement to clipboard
        return detectText(fileName: URL(fileURLWithPath: screenCapturePath))
    }
}

main()
